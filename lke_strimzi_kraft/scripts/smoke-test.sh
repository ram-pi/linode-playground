#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

export KUBECONFIG="${KUBECONFIG:-${PROJECT_DIR}/kubeconfig}"

NS="$(tofu output -raw kafka_namespace)"
INTERNAL_BOOTSTRAP="$(tofu output -raw internal_bootstrap)"
BOOTSTRAP_NODEPORT="$(tofu output -raw bootstrap_node_port)"
KAFKA_VERSION="$(tofu output -raw kafka_version)"
STRIMZI_VERSION="$(tofu output -raw strimzi_version)"
KAFKA_IMAGE="quay.io/strimzi/kafka:${STRIMZI_VERSION}-kafka-${KAFKA_VERSION}"

fail() { printf '\nFAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

echo "=== 1. Kafka cluster, pool isolation, and pod placement ==="
kubectl -n "${NS}" wait --for=condition=Ready kafka/kafka --timeout=5m

BROKER_PODS="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name=broker' --no-headers | wc -l | tr -d ' ')"
KRAFT_PODS="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name=kraft' --no-headers | wc -l | tr -d ' ')"
[[ "${BROKER_PODS}" -eq 4 ]] || fail "expected 4 broker pods, found ${BROKER_PODS}"
[[ "${KRAFT_PODS}" -eq 3 ]] || fail "expected 3 controller pods, found ${KRAFT_PODS}"

NODE_COUNT="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name in (broker,kraft)' \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l | tr -d ' ')"
[[ "${NODE_COUNT}" -eq 7 ]] || fail "expected one Kafka pod per node, but pods span only ${NODE_COUNT} nodes"

BROKER_NODES="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name=broker' \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l | tr -d ' ')"
[[ "${BROKER_NODES}" -eq 4 ]] || fail "brokers are not spread one-per-node"
pass "3 controllers + 4 brokers, each on a dedicated node (no colocation)"

echo
echo "=== 1b. Kafka pools are tainted and reserved ==="
for role in kafka-broker kafka-kraft; do
  TAINTS="$(kubectl get nodes -l role="${role}" -o json 2>/dev/null \
    | python3 -c "import json,sys; print(sum(len(n['spec'].get('taints') or []) for n in json.load(sys.stdin)['items']))")"
  [[ "${TAINTS}" -gt 0 ]] || fail "${role} nodes are not tainted; noisy neighbours can schedule there"
done
pass "broker and kraft nodes carry dedicated NoSchedule taints"

# Kafka pods must tolerate the taint, otherwise a reschedule would leave them Pending.
ISOLATION_POD="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name=broker' -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "${NS}" get pod "${ISOLATION_POD}" -o json 2>/dev/null \
  | grep -q '"key": *"dedicated"' \
  || fail "broker pod does not tolerate the dedicated taint"
pass "Kafka pods tolerate the dedicated taint"

echo
echo "=== 2. Java runtime version ==="
BROKER_POD="$(kubectl -n "${NS}" get pods -l 'strimzi.io/pool-name=broker' -o jsonpath='{.items[0].metadata.name}')"
JAVA_VERSION="$(kubectl -n "${NS}" exec "${BROKER_POD}" -c kafka -- java -version 2>&1 | head -n1)"
echo "  ${JAVA_VERSION}"
echo "${JAVA_VERSION}" | grep -q '21' || fail "Kafka is not running on Java 21: ${JAVA_VERSION}"
pass "Kafka runs on Java 21"

echo
echo "=== 3. Persistent volumes ==="
for label in kraft broker; do
  COUNT=0
  for pvc in $(kubectl -n "${NS}" get pvc -l "strimzi.io/pool-name=${label}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    PHASE="$(kubectl -n "${NS}" get pvc "${pvc}" -o jsonpath='{.status.phase}')"
    CLASS="$(kubectl -n "${NS}" get pvc "${pvc}" -o jsonpath='{.spec.storageClassName}')"
    [[ "${PHASE}" == "Bound" ]] || fail "PVC ${pvc} is ${PHASE}, expected Bound"
    [[ "${CLASS}" == "linode-block-storage-retain" ]] || fail "PVC ${pvc} uses ${CLASS}"
    COUNT=$((COUNT + 1))
  done
  EXPECTED=$([[ "${label}" == "broker" ]] && echo 4 || echo 3)
  [[ "${COUNT}" -eq "${EXPECTED}" ]] || fail "expected ${EXPECTED} ${label} PVCs, found ${COUNT}"
  pass "${label}: ${COUNT} PVCs Bound on linode-block-storage-retain"
done

echo
echo "=== 4. Internal listener produce/consume ==="
INTERNAL_TOKEN="internal-$(date +%s)-$$"
# shellcheck disable=SC2016 # ${BOOTSTRAP}/${TOKEN} are passed with --env and must expand inside the pod.
kubectl -n "${NS}" run kafka-internal-test --rm -i --restart=Never \
  --image="${KAFKA_IMAGE}" \
  --env="BOOTSTRAP=${INTERNAL_BOOTSTRAP}" \
  --env="TOKEN=${INTERNAL_TOKEN}" \
  --command -- bash -c '
    set -e
    echo "${TOKEN}" | /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server "${BOOTSTRAP}" --topic demo-orders
    /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server "${BOOTSTRAP}" --topic demo-orders \
      --from-beginning --timeout-ms 45000 > /tmp/out.txt 2>/dev/null || true
    grep -q "${TOKEN}" /tmp/out.txt
  ' || fail "internal listener produce/consume failed"
pass "internal listener produce/consume works"

echo
echo "=== 5. External NodePort listener produce/consume (SCRAM-SHA-512) ==="
# Confirm Strimzi advertised the node InternalIPs, not public addresses.
ADVERTISED="$(kubectl -n "${NS}" get kafka kafka -o jsonpath='{.status.listeners[?(@.name=="external")].addresses[*].host}')"
echo "  advertised hosts: ${ADVERTISED}"
for host in ${ADVERTISED}; do
  case "${host}" in
    # IPv4 private ranges (RFC1918 + CGNAT).
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[0-2][0-9].*) ;;
    # IPv6 unique local / link-local VPC addresses.
    fc*|fd*|fe80:*) ;;
    *) fail "external listener advertised a non-private host: ${host}" ;;
  esac
done

SCRAM_PASSWORD="$(kubectl -n "${NS}" get secret demo-user -o jsonpath='{.data.password}' | base64 -d)"
BOOTSTRAP_HOST="$(echo "${ADVERTISED}" | awk '{print $1}')"
# IPv6 literals must be wrapped in brackets for the bootstrap address.
case "${BOOTSTRAP_HOST}" in
  *:*) BOOTSTRAP_SERVER="[${BOOTSTRAP_HOST}]:${BOOTSTRAP_NODEPORT}" ;;
  *)   BOOTSTRAP_SERVER="${BOOTSTRAP_HOST}:${BOOTSTRAP_NODEPORT}" ;;
esac
echo "  bootstrap server: ${BOOTSTRAP_SERVER}"
EXTERNAL_TOKEN="external-$(date +%s)-$$"

# Run the client with hostNetwork so its source address is the node's VPC address,
# which is the same path a real VPC client takes through the Cloud Firewall. The
# dual-stack node reaches its own IPv6 address locally.
# shellcheck disable=SC2016 # ${SCRAM_PASSWORD}/${BOOTSTRAP}/${TOKEN} are passed with --env.
kubectl -n "${NS}" run kafka-external-test --rm -i --restart=Never \
  --image="${KAFKA_IMAGE}" \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --env="SCRAM_PASSWORD=${SCRAM_PASSWORD}" \
  --env="BOOTSTRAP=${BOOTSTRAP_SERVER}" \
  --env="TOKEN=${EXTERNAL_TOKEN}" \
  --command -- bash -c '
    set -e
    cat > /tmp/client.properties <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="demo-user" password="${SCRAM_PASSWORD}";
EOF
    /opt/kafka/bin/kafka-broker-api-versions.sh \
      --bootstrap-server "${BOOTSTRAP}" --command-config /tmp/client.properties >/dev/null
    echo "${TOKEN}" | /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server "${BOOTSTRAP}" \
      --producer.config /tmp/client.properties --topic demo-orders
    /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server "${BOOTSTRAP}" \
      --consumer.config /tmp/client.properties --topic demo-orders \
      --from-beginning --timeout-ms 45000 > /tmp/out.txt 2>/dev/null || true
    grep -q "${TOKEN}" /tmp/out.txt
  ' || fail "external NodePort listener produce/consume failed"
pass "external NodePort listener works with SCRAM-SHA-512 over the VPC"

echo
echo "=== 6. Replication settings and Cruise Control ==="
REPLICAS="$(kubectl -n "${NS}" get kafkatopic demo-orders -o jsonpath='{.spec.replicas}')"
[[ "${REPLICAS}" == "3" ]] || fail "demo-orders replication factor is ${REPLICAS}, expected 3"
MIN_ISR="$(kubectl -n "${NS}" get kafka kafka -o jsonpath='{.spec.kafka.config.min\.insync\.replicas}')"
[[ "${MIN_ISR}" == "2" ]] || fail "min.insync.replicas is ${MIN_ISR}, expected 2"
kubectl -n "${NS}" get pods -l 'strimzi.io/name=kafka-cruise-control' --no-headers | grep -q Running \
  || fail "Cruise Control pod is not running"
pass "RF=3, min.insync.replicas=2, Cruise Control running"

echo
echo "All smoke tests passed."
