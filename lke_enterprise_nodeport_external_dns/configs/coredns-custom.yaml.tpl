apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
  labels:
    app.kubernetes.io/name: coredns
    app.kubernetes.io/instance: workload
    k8s-app: coredns
data:
  # Matched by the `import custom/*.server` line in the workload-coredns
  # Corefile. A dedicated server block for the .internal zone keeps the
  # `kubernetes` plugin (cluster.local) authoritative for service names and
  # forwards only the .internal zone to Linode's authoritative nameservers.
  internal.server: |
    ${DNS_ZONE}:53 {
        errors
        cache 30
        forward . ${LINODE_NS_IPS} {
            max_concurrent 1000
        }
    }
