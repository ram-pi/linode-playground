output "cluster_id" {
  description = "LKE Enterprise cluster ID"
  value       = linode_lke_cluster.kafka.id
}

output "cluster_label" {
  description = "LKE Enterprise cluster label"
  value       = linode_lke_cluster.kafka.label
}

output "k8s_version" {
  description = "Kubernetes version deployed to the cluster"
  value       = linode_lke_cluster.kafka.k8s_version
}

output "vpc_id" {
  description = "VPC ID"
  value       = linode_vpc.main.id
}

output "vpc_ipv4_cidr" {
  description = "VPC subnet IPv4 CIDR"
  value       = linode_vpc_subnet.main.ipv4
}

output "vpc_ipv6_range" {
  description = "IPv6 range allocated to the VPC"
  value       = linode_vpc.main.ipv6[0].allocated_range
}

output "subnet_ipv6_range" {
  description = "IPv6 range allocated to the VPC subnet"
  value       = linode_vpc_subnet.main.ipv6[0].allocated_range
}

output "stack_type" {
  description = "Networking stack type of the LKE cluster"
  value       = linode_lke_cluster.kafka.stack_type
}

output "kraft_pool_summary" {
  description = "KRaft controller pool size and instance type"
  value       = "${var.kraft_node_count} x ${var.kraft_node_type}"
}

output "broker_pool_summary" {
  description = "Kafka broker pool size and instance type"
  value       = "${var.broker_node_count} x ${var.broker_node_type}"
}

output "system_pool_summary" {
  description = "System pool size and instance type"
  value       = "${var.system_node_count} x ${var.system_node_type}"
}

output "monitoring_pool_summary" {
  description = "Monitoring pool size and instance type"
  value       = "${var.monitoring_node_count} x ${var.monitoring_node_type}"
}

output "internal_bootstrap" {
  description = "Internal listener bootstrap address (in-cluster clients)"
  value       = local.internal_bootstrap
}

output "kafka_namespace" {
  description = "Kubernetes namespace for the Kafka cluster"
  value       = var.kafka_namespace
}

output "strimzi_version" {
  description = "Strimzi Kafka Operator version"
  value       = var.strimzi_version
}

output "kafka_version" {
  description = "Kafka version"
  value       = var.kafka_version
}

output "bootstrap_node_port" {
  description = "NodePort of the external bootstrap service"
  value       = local.bootstrap_node_port
}

output "broker_node_ports" {
  description = "NodePorts assigned to each Kafka broker"
  value       = local.broker_node_ports
}

output "broker_node_ids" {
  description = "Pinned Kafka node IDs for the broker pool"
  value       = local.broker_node_ids
}
