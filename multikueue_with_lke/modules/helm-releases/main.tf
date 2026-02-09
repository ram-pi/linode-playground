# Install cloud firewall CRD
resource "helm_release" "cloud_firewall_crd" {
  name       = "cloud-firewall-crd"
  repository = "https://linode.github.io/cloud-firewall-controller"
  chart      = "cloud-firewall-crd"

  timeout       = 300
  wait          = true
  wait_for_jobs = true
}

# Install cloud firewall controller
resource "helm_release" "cloud_firewall" {
  name       = "cloud-firewall"
  repository = "https://linode.github.io/cloud-firewall-controller"
  chart      = "cloud-firewall-controller"

  timeout       = 300
  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.cloud_firewall_crd]
}

# Install Prometheus stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  namespace        = "monitoring"
  create_namespace = true

  timeout       = 600
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      grafana = {
        enabled = true
        service = {
          type = "ClusterIP"
        }
      }
      prometheus = {
        service = {
          type = "ClusterIP"
        }
      }
      alertmanager = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]
}

# Install NVIDIA GPU operator
# https://techdocs.akamai.com/cloud-computing/docs/gpus-on-lke#nvidia-gpu-operator
resource "helm_release" "nvidia_gpu_operator" {
  name       = "nvidia-gpu-operator"
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"

  namespace        = "gpu-operator"
  create_namespace = true

  timeout       = 600
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      driver = {
        enabled = false
      }
      toolkit = {
        enabled = false
      }
      dcgmExporter = {
        enabled = true
        serviceMonitor = {
          enabled = true
          additionalLabels = {
            "release" = "kube-prometheus-stack"
          }
        }
      }
    })
  ]
}
