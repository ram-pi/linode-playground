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
  placement:
    clusterAffinity:
      clusterNames:
        - ${KARMADA_CLUSTER_FRA}
        - ${KARMADA_CLUSTER_SEA}
