apiVersion: v1
kind: Secret
metadata:
  name: juicefs-secret
  namespace: model-cache-benchmark
  labels:
    juicefs.com/validate-secret: "true"
type: Opaque
stringData:
  name: "model-cache-benchmark"
  metaurl: "redis://juicefs-redis.model-cache-benchmark.svc.cluster.local:6379/1"
  storage: "s3"
  bucket: "${JUICEFS_BUCKET_URL}"
  access-key: "${JUICEFS_ACCESS_KEY}"
  secret-key: "${JUICEFS_SECRET_KEY}"
  envs: '{TZ: UTC, ACCESS_KEY: "${JUICEFS_ACCESS_KEY}", SECRET_KEY: "${JUICEFS_SECRET_KEY}", AWS_ACCESS_KEY_ID: "${JUICEFS_ACCESS_KEY}", AWS_SECRET_ACCESS_KEY: "${JUICEFS_SECRET_KEY}", AWS_REGION: us-east-1, AWS_DEFAULT_REGION: us-east-1}'
  format-options: "trash-days=0,access-key=${JUICEFS_ACCESS_KEY},secret-key=${JUICEFS_SECRET_KEY}"
