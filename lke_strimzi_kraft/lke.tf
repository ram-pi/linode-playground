resource "linode_lke_cluster" "kafka" {
  label       = var.cluster_label
  k8s_version = var.k8s_version
  region      = var.region
  tier        = "enterprise"
  apl_enabled = false
  vpc_id      = linode_vpc.main.id
  subnet_id   = linode_vpc_subnet.main.id
  stack_type  = "ipv4-ipv6"
  tags        = var.tags

  # Dedicated KRaft controller pool. Small instances; only the metadata log is stored.
  # Tainted so only Kafka controllers (and the perf client, which tolerates it)
  # can be scheduled here. Other workloads land on the untainted system pool.
  pool {
    type        = var.kraft_node_type
    count       = var.kraft_node_count
    firewall_id = linode_firewall.kafka_pool.id

    labels = {
      role = "kafka-kraft"
    }

    taint {
      key    = "dedicated"
      value  = "kafka-kraft"
      effect = "NoSchedule"
    }
  }

  # Dedicated Kafka broker pool. Memory/CPU heavy; stores topic data.
  # Tainted so only Kafka brokers can be scheduled here, preventing noisy
  # neighbours from stealing the CPU and memory Kafka depends on.
  pool {
    type        = var.broker_node_type
    count       = var.broker_node_count
    firewall_id = linode_firewall.kafka_pool.id

    labels = {
      role = "kafka-broker"
    }

    taint {
      key    = "dedicated"
      value  = "kafka-broker"
      effect = "NoSchedule"
    }
  }

  # Monitoring pool. Keeps Prometheus/Grafana off the nodes under test so that
  # scrape and TSDB activity never distorts the stress-test measurements.
  pool {
    type        = var.monitoring_node_type
    count       = var.monitoring_node_count
    firewall_id = linode_firewall.kafka_pool.id

    labels = {
      role = "monitoring"
    }
  }

  # System pool. Deliberately untainted: it is the home for LKE-managed add-ons
  # that cannot tolerate custom taints and that need distinct hostnames
  # (workload-coredns x3, cilium-operator x2, the autoscalers) plus Strimzi's
  # support components. Without it, tainting the Kafka pools leaves DNS Pending.
  pool {
    type        = var.system_node_type
    count       = var.system_node_count
    firewall_id = linode_firewall.kafka_pool.id

    labels = {
      role = "system"
    }
  }

  control_plane {
    high_availability = true

    acl {
      enabled = true

      addresses {
        ipv4 = var.control_plane_allowed_ipv4_cidrs
        ipv6 = var.control_plane_allowed_ipv6_cidrs
      }
    }
  }
}

resource "local_file" "kubeconfig" {
  content         = base64decode(linode_lke_cluster.kafka.kubeconfig)
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}
