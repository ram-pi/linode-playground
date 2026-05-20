apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: llm-inference-policy
  namespace: llm-inference
spec:
  resourceSelectors:
    - apiVersion: v1
      kind: Secret
      name: hf-token
    - apiVersion: ray.io/v1
      kind: RayService
      name: llm-serve
    - apiVersion: v1
      kind: ConfigMap
      name: llm-api-gateway-nginx
    - apiVersion: apps/v1
      kind: Deployment
      name: llm-api-gateway
    - apiVersion: v1
      kind: Service
      name: llm-api-gateway
  placement:
    clusterAffinity:
      clusterNames:
        - ${KARMADA_CLUSTER_FRA_1}
        - ${KARMADA_CLUSTER_FRA_2}
