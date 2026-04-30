apiVersion: v1
kind: Secret
metadata:
  name: gcs-sa-key
type: Opaque
data:
  key.json: ${GCS_SA_KEY_B64}
