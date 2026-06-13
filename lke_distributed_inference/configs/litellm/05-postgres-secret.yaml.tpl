apiVersion: v1
kind: Secret
metadata:
  name: litellm-postgres
  namespace: litellm-gateway
type: Opaque
stringData:
  POSTGRES_DB: litellm
  POSTGRES_USER: litellm
  POSTGRES_PASSWORD: "${LITELLM_POSTGRES_PASSWORD}"
