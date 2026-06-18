apiVersion: v1
kind: ConfigMap
metadata:
  name: model-config
  namespace: model-cache-benchmark
data:
  LINODE_BUCKET: "${LINODE_BUCKET}"
  LINODE_ENDPOINT: "${LINODE_ENDPOINT}"
  MODEL_OBJECT_KEY: "${MODEL_OBJECT_KEY}"
  MODEL_PATH: "/models/model.gguf"
  CACHE_PATH: "/var/lib/model-cache-benchmark/model.gguf"
