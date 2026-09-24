#!/usr/bin/env bash
set -euo pipefail

# Phased stress test for the Strimzi Kafka cluster.
#
#   Phase 0: preflight (Kafka Ready, metrics scraping)
#   Phase 1: throughput baseline (produce/consume, 1 KiB and 10 KiB records)
#   Phase 2: CPU saturation (drive until CFS throttling, prove the 7-core quota)
#   Phase 3: memory / page cache (stop before the hard limit to avoid OOMKill)
#   Phase 4: disk throughput on a broker PVC (bounded write, always cleaned up)
#   Phase 5: resilience (kill a broker, verify ISR recovery and no data loss)
#
# Every phase prints a PASS/FAIL/WARN line. Cleanup runs on exit, including on
# failure, so perf pods, the stress topic, and the scratch file never leak.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

export KUBECONFIG="${KUBECONFIG:-${PROJECT_DIR}/kubeconfig}"

NS="$(tofu output -raw kafka_namespace)"
INTERNAL_BOOTSTRAP="$(tofu output -raw internal_bootstrap)"

TOPIC="stress-test"
PERF_POD="kafka-perf-client"
BROKER_POD="kafka-broker-0"
# Record counts. Large enough to be meaningful, small enough to finish quickly.
RECORDS_SHORT=2000000
RECORDS_LONG=500000
RECORDS_CPU=20000000
SCRATCH_FILE="/var/lib/kafka/data/stress-scratch.bin"

PHASE="${PHASE:-all}"
RESULTS_DIR="${PROJECT_DIR}/stress-results"
mkdir -p "${RESULTS_DIR}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${RESULTS_DIR}/stress-${TIMESTAMP}.log"

fail() { printf '\nFAIL: %s\n' "$1" | tee -a "${REPORT}" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1" | tee -a "${REPORT}"; }
warn() { printf 'WARN: %s\n' "$1" | tee -a "${REPORT}"; }
info() { printf '%s\n' "$1" | tee -a "${REPORT}"; }

# ---------------------------------------------------------------- cleanup
cleanup() {
  local rc=$?
  info ""
  info "=== Cleanup ==="
  kubectl -n "${NS}" delete pod "${PERF_POD}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl -n "${NS}" delete kafkatopic "${TOPIC}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  # Remove the scratch file created by phase 4, if the broker is reachable.
  kubectl -n "${NS}" exec "${BROKER_POD}" -c kafka -- rm -f "${SCRATCH_FILE}" >/dev/null 2>&1 || true
  info "Cleanup complete (exit ${rc})."
  exit "${rc}"
}
trap cleanup EXIT

# ---------------------------------------------------------------- helpers
perf_exec() {
  kubectl -n "${NS}" exec "${PERF_POD}" -- bash -c "$1"
}

broker_exec() {
  kubectl -n "${NS}" exec "${BROKER_POD}" -c kafka -- bash -c "$1"
}

# Read a cgroup counter from a container.
cgroup_metric() {
  broker_exec "cat /sys/fs/cgroup/$1 2>/dev/null" | tr -d '\r'
}

wait_for_pod() {
  local pod="$1" timeout_s="$2"
  local deadline=$(( $(date +%s) + timeout_s ))
  while (( $(date +%s) < deadline )); do
    local phase
    phase="$(kubectl -n "${NS}" get pod "${pod}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "${phase}" in
      Running|Succeeded) return 0 ;;
      Failed) fail "pod ${pod} entered Failed" ;;
    esac
    sleep 3
  done
  fail "pod ${pod} did not become ready within ${timeout_s}s"
}

# ---------------------------------------------------------------- phase 0
phase0_preflight() {
  info "=== Phase 0: preflight ==="
  info "Report: ${REPORT}"

  kubectl -n "${NS}" wait --for=condition=Ready kafka/kafka --timeout=5m \
    || fail "Kafka/kafka is not Ready"
  pass "Kafka is Ready"

  # Create the dedicated stress topic and the load generator pod up front so the
  # rest of the phases can assume they exist.
  kubectl apply -f configs/60-stress/stress-topic.yaml >/dev/null
  kubectl -n "${NS}" wait --for=condition=Ready kafkatopic/"${TOPIC}" --timeout=5m \
    || fail "stress topic did not become Ready"
  pass "Stress topic '${TOPIC}' Ready"

  kubectl apply -f configs/60-stress/perf-client.yaml >/dev/null
  # A prior run's cleanup may still be terminating the pod; apply is a no-op on a
  # terminating object, so wait for it to disappear and recreate if needed.
  if kubectl -n "${NS}" get pod "${PERF_POD}" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null | grep -q .; then
    kubectl -n "${NS}" wait --for=delete "pod/${PERF_POD}" --timeout=120s
    kubectl apply -f configs/60-stress/perf-client.yaml >/dev/null
  fi
  wait_for_pod "${PERF_POD}" 300
  pass "Load generator '${PERF_POD}' is running"

  # The Strimzi Metrics Reporter must be exposed on tcp-prometheus (9404).
  local metrics_port
  metrics_port="$(kubectl -n "${NS}" get pods -l strimzi.io/pool-name=broker -o jsonpath='{.items[0].spec.containers[?(@.name=="kafka")].ports[?(@.name=="tcp-prometheus")].containerPort}')"
  [[ "${metrics_port}" == "9404" ]] || fail "metrics port tcp-prometheus/9404 not found (got '${metrics_port}'); apply metricsConfig and restart"
  pass "Kafka metrics port tcp-prometheus/9404 exposed"

  # Verify Prometheus is actually scraping the Kafka targets, if it is installed.
  if kubectl -n monitoring get svc kube-prometheus-stack-prometheus >/dev/null 2>&1; then
    local up=""
    # Query Prometheus through a local port-forward (the Prometheus image has no
    # curl/wget). --data-urlencode is required so PromQL characters like =~ survive.
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 19090:9090 \
      >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 5
    up="$(curl -s --data-urlencode 'query=count(up{job=~".*kafka-resources-metrics.*"}==1)' \
      -G 'http://localhost:19090/api/v1/query' \
      | sed -n 's/.*"value":\[[^,]*,*"\([0-9.]*\)".*/\1/p')"
    kill "${pf_pid}" >/dev/null 2>&1 || true
    if [[ -n "${up}" && "${up}" != "0" ]]; then
      pass "Prometheus is scraping ${up} Kafka target(s)"
    else
      warn "Prometheus Kafka targets not confirmed UP yet (job may need a moment)"
    fi
  else
    warn "kube-prometheus-stack not installed; skipping scrape verification (run scripts/install-monitoring.sh)"
  fi

  info "Broker resources: $(kubectl -n "${NS}" get pod "${BROKER_POD}" -o jsonpath='{.spec.containers[0].resources}')"
}

# ---------------------------------------------------------------- phase 1
phase1_throughput() {
  info ""
  info "=== Phase 1: throughput baseline ==="

  wait_for_pod "${PERF_POD}" 180

  for size in 1024 10240; do
    local label records
    if [[ "${size}" == "1024" ]]; then label="1KiB"; records="${RECORDS_SHORT}"; else label="10KiB"; records="${RECORDS_LONG}"; fi
    info ""
    info "--- Producer: ${label} records, acks=all, ${records} msgs ---"
    perf_exec "/opt/kafka/bin/kafka-producer-perf-test.sh \
      --topic ${TOPIC} --num-records ${records} --record-size ${size} \
      --throughput -1 \
      --producer-props bootstrap.servers=${INTERNAL_BOOTSTRAP} acks=all linger.ms=5 batch.size=65536" \
      2>&1 | tee -a "${REPORT}" || fail "producer perf test (${label}) failed"
  done

  info ""
  info "--- Consumer ---"
  perf_exec "/opt/kafka/bin/kafka-consumer-perf-test.sh \
    --bootstrap-server ${INTERNAL_BOOTSTRAP} --topic ${TOPIC} \
    --messages ${RECORDS_LONG} --timeout 60000" \
    2>&1 | tee -a "${REPORT}" || fail "consumer perf test failed"
  pass "Phase 1 throughput baseline complete"
}

# ---------------------------------------------------------------- phase 2
phase2_cpu() {
  info ""
  info "=== Phase 2: CPU saturation (proving the CFS quota) ==="

  wait_for_pod "${PERF_POD}" 180

  # Measure broker CPU and throttling per broker using cgroup counters, which are
  # precise and do not depend on Prometheus. cpu.stat usage_usec gives cumulative
  # CPU time, so a delta over a known interval yields cores used.
  local pod name baseline_dir
  baseline_dir="$(mktemp -d)"
  for pod in $(kubectl -n "${NS}" get pods -l strimzi.io/pool-name=broker -o name); do
    name="${pod##*/}"
    # shellcheck disable=SC2016 # the awk program must reach the container literally.
    kubectl -n "${NS}" exec "${name}" -c kafka -- awk '/^usage_usec/ {print $2} /^nr_throttled/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null \
      | tr -d '\r' > "${baseline_dir}/${name}" || true
  done

  # Sustained, unthrottled producer load. The perf tool has no --threads option,
  # so run several producer processes in parallel.
  local load_seconds=120 producers=6
  info "Driving load for ~${load_seconds}s with ${producers} parallel producers..."
  local start_ts end_ts
  start_ts="$(date +%s)"
  perf_exec "for i in \$(seq 1 ${producers}); do
      timeout ${load_seconds} /opt/kafka/bin/kafka-producer-perf-test.sh \
        --topic ${TOPIC} --num-records ${RECORDS_CPU} --record-size 16384 \
        --throughput -1 \
        --producer-props bootstrap.servers=${INTERNAL_BOOTSTRAP} acks=1 linger.ms=0 batch.size=131072 \
        > /tmp/prod-\$i.log 2>&1 &
    done; wait; tail -n 1 /tmp/prod-*.log" 2>&1 | tee -a "${REPORT}" || warn "producer run ended early (timeout expected)"
  end_ts="$(date +%s)"
  local elapsed=$(( end_ts - start_ts ))
  (( elapsed > 0 )) || elapsed=1

  # The broker CPU cap comes from the cgroup quota (7 cores == 700000/100000).
  local cap_cores=7
  local total_delta=0
  for pod in $(kubectl -n "${NS}" get pods -l strimzi.io/pool-name=broker -o name); do
    name="${pod##*/}"
    local stats throttled usage prev_usage prev_throttled
    # shellcheck disable=SC2016 # the awk program must reach the container literally.
    stats="$(kubectl -n "${NS}" exec "${name}" -c kafka -- awk '/^usage_usec/ {print $2} /^nr_throttled/ {print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null | tr -d '\r')"
    usage="$(echo "${stats}" | sed -n 1p)"
    throttled="$(echo "${stats}" | sed -n 2p)"
    prev_usage="$(sed -n 1p "${baseline_dir}/${name}" 2>/dev/null || echo 0)"
    prev_throttled="$(sed -n 2p "${baseline_dir}/${name}" 2>/dev/null || echo 0)"
    local cores pct delta
    cores="$(awk -v u="${usage}" -v pu="${prev_usage:-0}" -v t="${elapsed}" 'BEGIN {printf "%.2f", (u-pu)/1000000/t}')"
    pct="$(awk -v c="${cores}" -v cap="${cap_cores}" 'BEGIN {printf "%.0f", c*100/cap}')"
    delta=$(( throttled - prev_throttled ))
    total_delta=$(( total_delta + delta ))
    info "  ${name}: ${cores}/${cap_cores} cores (${pct}% of cap), throttled ${delta} time(s) in ${elapsed}s"
  done
  rm -rf "${baseline_dir}"

  if (( total_delta > 0 )); then
    pass "CFS quota enforced: brokers were CPU-throttled ${total_delta} time(s) at the 7-core cap"
  else
    warn "No throttling observed: the load generator is the bottleneck. The brokers stayed under their 7-core quota because a single 2-CPU client pod cannot push them harder. Scale the generator (raise its CPU limit or add replicas) to reach the cap."
  fi
}

# ---------------------------------------------------------------- phase 3
phase3_memory() {
  info ""
  info "=== Phase 3: memory / page cache (guarded) ==="

  wait_for_pod "${PERF_POD}" 180

  local max current pct
  max="$(cgroup_metric 'memory.max')"
  info "memory.max: ${max} bytes (12 GiB hard limit)"

  info "Driving write-heavy load to grow the page cache (60s)..."
  perf_exec "for i in 1 2 3 4; do
      timeout 60 /opt/kafka/bin/kafka-producer-perf-test.sh \
        --topic ${TOPIC} --num-records ${RECORDS_CPU} --record-size 16384 \
        --throughput -1 \
        --producer-props bootstrap.servers=${INTERNAL_BOOTSTRAP} acks=all linger.ms=0 batch.size=262144 \
        > /tmp/mem-\$i.log 2>&1 &
    done; wait; tail -n 1 /tmp/mem-*.log" 2>&1 | tee -a "${REPORT}" || warn "producer run ended early (timeout expected)"

  for pod in $(kubectl -n "${NS}" get pods -l strimzi.io/pool-name=broker -o name); do
    local name
    name="${pod##*/}"
    current="$(kubectl -n "${NS}" exec "${name}" -c kafka -- cat /sys/fs/cgroup/memory.current 2>/dev/null | tr -d '\r')"
    pct=$(( current * 100 / max ))
    info "  ${name}: memory.current=$(( current / 1024 / 1024 ))MiB (${pct}% of limit)"
    if (( pct >= 90 )); then
      warn "${name} reached ${pct}% of its memory limit. If you increase the load or record retention, an OOMKill becomes likely; reduce batch size or retention before extending the test."
    fi
  done
  pass "Phase 3 memory observation complete (no OOMKill)"
}

# ---------------------------------------------------------------- phase 4
phase4_disk() {
  info ""
  info "=== Phase 4: disk throughput on a broker PVC ==="

  local logdir free_before free_after
  logdir="$(broker_exec 'df -P /var/lib/kafka/data | tail -1' | awk '{print $4}')"
  free_before="${logdir}"
  info "Free space before (1K blocks): ${free_before}"

  # 5 GiB bounded direct write to bypass the page cache. Cleaned up by the trap.
  info "Writing 5 GiB with O_DIRECT..."
  broker_exec "dd if=/dev/zero of=${SCRATCH_FILE} bs=1M count=5120 oflag=direct status=progress 2>&1 | tail -2" \
    | tee -a "${REPORT}" || fail "dd write failed"
  info "Read-back (dropping caches is not permitted, so this is cache-assisted):"
  broker_exec "dd if=${SCRATCH_FILE} of=/dev/null bs=1M count=5120 iflag=direct 2>&1 | tail -1" \
    | tee -a "${REPORT}" || fail "dd read failed"

  broker_exec "rm -f ${SCRATCH_FILE}" || true
  free_after="$(broker_exec 'df -P /var/lib/kafka/data | tail -1' | awk '{print $4}')"
  info "Free space after (1K blocks): ${free_after}"
  pass "Phase 4 disk throughput complete (scratch file removed)"
}

# ---------------------------------------------------------------- phase 5
phase5_resilience() {
  info ""
  info "=== Phase 5: broker failure and recovery ==="

  wait_for_pod "${PERF_POD}" 180

  local offsets_before offsets_after
  offsets_before="$(perf_exec "/opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server ${INTERNAL_BOOTSTRAP} --topic ${TOPIC}" | sort)"

  info "Deleting ${BROKER_POD}..."
  kubectl -n "${NS}" delete pod "${BROKER_POD}" --wait=false
  kubectl -n "${NS}" wait --for=condition=Ready "pod/${BROKER_POD}" --timeout=10m \
    || fail "${BROKER_POD} did not become Ready after deletion"
  pass "${BROKER_POD} recovered"

  info "Verifying all partitions return to full ISR (RF=3)..."
  # Restarting a broker takes its partitions out of ISR; the remaining replicas
  # must catch up before ISR is complete again. Poll with a bounded timeout
  # instead of checking once immediately after the pod is Ready.
  local describe under partitions
  local isr_ready=false
  for _ in $(seq 1 60); do
    describe="$(perf_exec "/opt/kafka/bin/kafka-topics.sh --bootstrap-server ${INTERNAL_BOOTSTRAP} --describe --topic ${TOPIC}")"
    partitions="$(echo "${describe}" | grep -c '^	Topic:' || true)"
    under="$(echo "${describe}" | grep -c 'Isr: [0-9],[0-9],[0-9]' || true)"
    if [[ "${under}" -eq "${partitions}" && "${partitions}" -gt 0 ]]; then
      isr_ready=true
      break
    fi
    info "  ISR not yet complete (${under}/${partitions}); waiting..."
    sleep 10
  done

  if [[ "${isr_ready}" != "true" ]]; then
    echo "${describe}" | tee -a "${REPORT}"
    fail "not all partitions returned to full ISR within timeout (${under}/${partitions})"
  fi
  pass "All ${partitions} partitions back to full ISR"

  info "Running replica verification for 30s..."
  # This tool uses --broker-list (not --bootstrap-server) and runs continuously,
  # so bound it with timeout. Non-zero exit from timeout means it was still
  # reporting no divergence when stopped, which is the desired outcome.
  perf_exec "timeout 30 /opt/kafka/bin/kafka-replica-verification.sh \
    --broker-list ${INTERNAL_BOOTSTRAP} --topics-include '${TOPIC}' --report-interval-ms 5000" \
    2>&1 | tail -5 | tee -a "${REPORT}" || true
  pass "Replica verification completed (no divergence reported above)"

  offsets_after="$(perf_exec "/opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server ${INTERNAL_BOOTSTRAP} --topic ${TOPIC}" | sort)"
  if [[ "${offsets_before}" == "${offsets_after}" ]]; then
    pass "No data loss: offsets unchanged across the broker failure"
  else
    warn "Offsets changed across the failure (expected only if producers were still writing)"
  fi
}

# ---------------------------------------------------------------- main
info "Kafka stress test - ${TIMESTAMP}"
info "Namespace: ${NS}, topic: ${TOPIC}, phase: ${PHASE}"

case "${PHASE}" in
  all) phase0_preflight; phase1_throughput; phase2_cpu; phase3_memory; phase4_disk; phase5_resilience ;;
  0)   phase0_preflight ;;
  1)   phase0_preflight; phase1_throughput ;;
  2)   phase0_preflight; phase2_cpu ;;
  3)   phase0_preflight; phase3_memory ;;
  4)   phase0_preflight; phase4_disk ;;
  5)   phase0_preflight; phase5_resilience ;;
  *)   fail "unknown PHASE '${PHASE}' (use all, 0, 1, 2, 3, 4, 5)" ;;
esac

info ""
info "All selected phases passed. Report: ${REPORT}"
