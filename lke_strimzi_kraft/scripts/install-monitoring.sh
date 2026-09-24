#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

export KUBECONFIG="${KUBECONFIG:-${PROJECT_DIR}/kubeconfig}"

MONITORING_NS="monitoring"
KPS_VERSION="91.5.0" # app v0.94.0
MONITORING_CONFIGS="configs/50-monitoring"

for command_name in kubectl helm; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

echo "=== 1. Installing kube-prometheus-stack ${KPS_VERSION} ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version "${KPS_VERSION}" \
  --namespace "${MONITORING_NS}" --create-namespace \
  --values "${MONITORING_CONFIGS}/kube-prometheus-stack-values.yaml" \
  --wait --timeout 15m

# The Strimzi PodMonitors/PrometheusRules use monitoring.coreos.com kinds, so the
# CRDs from kube-prometheus-stack must exist before they are applied.
echo "=== 2. Waiting for monitoring.coreos.com CRDs ==="
kubectl wait --for=condition=established --timeout=180s \
  crd/podmonitors.monitoring.coreos.com \
  crd/servicemonitors.monitoring.coreos.com \
  crd/prometheusrules.monitoring.coreos.com

echo "=== 3. Applying Strimzi scrape configs, rules, and CR metrics ==="
kubectl apply -f "${MONITORING_CONFIGS}/cruise-control-metrics.yaml"
kubectl apply -f "${MONITORING_CONFIGS}/pod-monitor-kafka.yaml"
kubectl apply -f "${MONITORING_CONFIGS}/pod-monitors-operators.yaml"
kubectl apply -f "${MONITORING_CONFIGS}/prometheus-kafka-rules.yaml"
kubectl apply -f "${MONITORING_CONFIGS}/ksm-strimzi-config.yaml"
kubectl apply -f "${MONITORING_CONFIGS}/ksm-strimzi.yaml"

echo "=== 4. Loading Strimzi Grafana dashboards ==="
# The Grafana sidecar discovers ConfigMaps labeled grafana_dashboard=1.
for dashboard in "${MONITORING_CONFIGS}"/dashboards/*.json; do
  name="$(basename "${dashboard}" .json)"
  kubectl create configmap "${name}" \
    --namespace "${MONITORING_NS}" \
    --from-file="${name}.json=${dashboard}" \
    --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml \
    | kubectl apply -f -
done

kubectl -n "${MONITORING_NS}" rollout status deployment/kube-prometheus-stack-grafana --timeout=5m

echo
echo "=== Monitoring installed ==="
echo "Prometheus:  http://localhost:9090  (kubectl -n ${MONITORING_NS} port-forward svc/kube-prometheus-stack-prometheus 9090:9090)"
echo "Grafana:     http://localhost:3000  (kubectl -n ${MONITORING_NS} port-forward svc/kube-prometheus-stack-grafana 3000:80)"
echo "Grafana user: admin / prom-operator"
echo "Dashboards:  Strimzi Kafka, Kafka KRaft, Kafka Exporter, Cruise Control"
echo
echo "Verify targets: Prometheus -> Status -> Targets (kafka-resources-metrics should be UP)"
