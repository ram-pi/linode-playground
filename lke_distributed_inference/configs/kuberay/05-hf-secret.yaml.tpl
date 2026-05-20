apiVersion: v1
kind: Secret
metadata:
  name: hf-token
  namespace: llm-inference
type: Opaque
stringData:
  HF_TOKEN: "${HF_TOKEN}"
