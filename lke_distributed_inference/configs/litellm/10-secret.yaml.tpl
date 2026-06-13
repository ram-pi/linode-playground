apiVersion: v1
kind: Secret
metadata:
  name: litellm-secrets
  namespace: litellm-gateway
type: Opaque
stringData:
  LITELLM_MASTER_KEY: "${LITELLM_MASTER_KEY}"
  INFERENCE_API_KEY: "${INFERENCE_API_KEY}"
  DATABASE_URL: "postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-postgres.litellm-gateway.svc.cluster.local:5432/litellm"
