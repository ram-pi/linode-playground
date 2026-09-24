#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

: "${LINODE_TOKEN:?Export LINODE_TOKEN with LKE and VPC permissions.}"

for command_name in tofu linode-cli jq kubectl helm; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

export TF_VAR_k8s_version="${TF_VAR_k8s_version:-$(linode-cli lke tiered-versions-list enterprise --json | jq -r '.[].id' | sort -V | tail -n 1)}"
printf 'Using LKE Enterprise version %s\n' "${TF_VAR_k8s_version}"

tofu init -reconfigure
tofu plan -out=tfplan
tofu apply tfplan
rm -f tfplan

export KUBECONFIG="${PROJECT_DIR}/kubeconfig"

NAMESPACE="$(tofu output -raw kafka_namespace)"
STRIMZI_VERSION="$(tofu output -raw strimzi_version)"

echo "Waiting for worker nodes..."
kubectl wait --for=condition=Ready nodes --all --timeout=20m

echo "Applying Strimzi ${STRIMZI_VERSION} CRDs..."
kubectl apply -f "https://github.com/strimzi/strimzi-kafka-operator/releases/download/${STRIMZI_VERSION}/strimzi-crds-${STRIMZI_VERSION}.yaml"
kubectl wait --for=condition=established --timeout=180s \
  crd/kafkas.kafka.strimzi.io \
  crd/kafkanodepools.kafka.strimzi.io \
  crd/kafkatopics.kafka.strimzi.io \
  crd/kafkausers.kafka.strimzi.io

echo "Installing the Strimzi Cluster Operator ${STRIMZI_VERSION}..."
# --skip-crds: the CRDs were applied above with kubectl. Helm 4 uses server-side
# apply for new releases, which conflicts with kubectl's client-side ownership of
# .spec.versions on the CRDs. Helm never upgrades CRDs from crds/ anyway.
helm upgrade --install strimzi-cluster-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version "${STRIMZI_VERSION}" \
  --namespace "${NAMESPACE}" --create-namespace \
  --skip-crds \
  --set watchAnyNamespace=true \
  --set nodeSelector.role=system \
  --wait --timeout 10m

kubectl -n "${NAMESPACE}" rollout status deployment/strimzi-cluster-operator --timeout=5m

echo "Creating Kafka node pools..."
# The PriorityClass must exist before the Kafka pods that reference it, otherwise
# the pods are rejected by the Priority admission controller.
kubectl apply -f configs/01-kafka-priorityclass.yaml
kubectl apply -f configs/10-nodepool-kraft.yaml
kubectl apply -f configs/11-nodepool-broker.yaml

echo "Creating the Kafka cluster..."
kubectl apply -f configs/20-kafka.yaml

echo "Waiting for Kafka to become Ready (this can take several minutes as PVCs provision)..."
kubectl -n "${NAMESPACE}" wait --for=condition=Ready kafka/kafka --timeout=20m

echo "Creating the demo topic and user..."
kubectl apply -f configs/30-kafkatopic.yaml
kubectl apply -f configs/40-kafkauser.yaml

kubectl -n "${NAMESPACE}" wait --for=condition=Ready kafkatopic/demo-orders --timeout=5m
kubectl -n "${NAMESPACE}" wait --for=condition=Ready kafkauser/demo-user --timeout=5m

./scripts/smoke-test.sh

# The monitoring stack is optional but enabled by default. Skipping it is useful
# for a fast iteration loop; the stress test warns when Prometheus is absent.
if [[ "${SKIP_MONITORING:-false}" != "true" ]]; then
  echo
  echo "Installing monitoring (kube-prometheus-stack + Strimzi dashboards)..."
  ./scripts/install-monitoring.sh
fi

cat > .runtime.env <<EOF
export KUBECONFIG="${PROJECT_DIR}/kubeconfig"
export KAFKA_NAMESPACE="${NAMESPACE}"
EOF

echo
echo "Kafka is ready. Run: source .runtime.env"
echo "Internal bootstrap: $(tofu output -raw internal_bootstrap)"
echo "External bootstrap: <node-internal-ip>:$(tofu output -raw bootstrap_node_port)"
echo
echo "Stress test:        ./scripts/stress-test.sh        (or PHASE=1 ./scripts/stress-test.sh)"
echo "Monitoring only:    ./scripts/install-monitoring.sh"
