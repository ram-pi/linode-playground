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
