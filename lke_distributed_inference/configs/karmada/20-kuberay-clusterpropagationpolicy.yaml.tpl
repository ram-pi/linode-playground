apiVersion: policy.karmada.io/v1alpha1
kind: ClusterPropagationPolicy
metadata:
  name: kuberay-operator-all-clusters
spec:
  resourceSelectors:
    - apiVersion: "*"
      kind: "*"
      labelSelector:
        matchLabels:
          app.kubernetes.io/part-of: kuberay
  placement:
    clusterAffinity:
      clusterNames:
        - ${KARMADA_CLUSTER_FRA}
        - ${KARMADA_CLUSTER_SEA}
