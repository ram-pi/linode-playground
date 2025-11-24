locals {
  kubeconfig_string = base64decode(linode_lke_cluster.main.kubeconfig)
  kubeconfig        = yamldecode(local.kubeconfig_string)
}

output "lke_kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "loadbalancer_service_conf" {
  value = <<-EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: podinfo
    annotations:
      service.beta.kubernetes.io/linode-loadbalancer-default-protocol: "http"
      service.beta.kubernetes.io/linode-loadbalancer-check-type: "http"
      service.beta.kubernetes.io/linode-loadbalancer-check-path: "/healthz"
      service.beta.kubernetes.io/linode-loadbalancer-check-interval: "5"
      service.beta.kubernetes.io/linode-loadbalancer-check-timeout: "3"
      service.beta.kubernetes.io/linode-loadbalancer-check-attempts: "2"
      service.beta.kubernetes.io/linode-loadbalancer-check-passive: "true"
      service.beta.kubernetes.io/linode-loadbalancer-firewall-acl: |
        {
          "allowList": {
            "ipv4": ["${local.my_ip_cidr}", "10.0.0.0/8"]
          }
        }
  spec:
    type: LoadBalancer
    selector:
      app: podinfo
    ports:
    - port: 9898
      targetPort: 9898
      protocol: TCP
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: echo-ip
    annotations:
      service.beta.kubernetes.io/linode-loadbalancer-default-protocol: "http"
      service.beta.kubernetes.io/linode-loadbalancer-check-type: "http"
      service.beta.kubernetes.io/linode-loadbalancer-check-path: "/"
      service.beta.kubernetes.io/linode-loadbalancer-check-interval: "5"
      service.beta.kubernetes.io/linode-loadbalancer-check-timeout: "3"
      service.beta.kubernetes.io/linode-loadbalancer-check-attempts: "2"
      service.beta.kubernetes.io/linode-loadbalancer-check-passive: "true"
      service.beta.kubernetes.io/linode-loadbalancer-firewall-acl: |
        {
          "allowList": {
            "ipv4": ["${local.my_ip_cidr}", "10.0.0.0/8"]
          }
        }
  spec:
    type: LoadBalancer
    selector:
      app: echo-ip
    ports:
    - port: 8080
      targetPort: 80
      protocol: TCP
  EOF
}
