resource "linode_lke_cluster" "main" {
  for_each = local.deployments

  label       = each.value.cluster_label
  k8s_version = var.k8s_version
  region      = var.region
  tier        = "enterprise"
  apl_enabled = false
  vpc_id      = linode_vpc.main.id
  subnet_id   = linode_vpc_subnet.main[each.key].id
  stack_type  = "ipv4-ipv6"
  tags        = var.tags

  pool {
    type        = var.node_type
    count       = var.node_count
    firewall_id = linode_firewall.lke_pool.id

    labels = {
      role = "hello-worker"
    }
  }

  control_plane {
    high_availability = true

    acl {
      enabled = true

      addresses {
        ipv4 = var.control_plane_allowed_ipv4_cidrs
      }
    }
  }
}
