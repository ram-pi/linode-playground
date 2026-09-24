locals {
  # NodePorts are pinned so firewall rules and client configuration are deterministic.
  # KafkaNodePool annotations pin broker node IDs to [0-3] and controllers to [100-102].
  bootstrap_node_port = 32100
  broker_node_ports   = [32101, 32102, 32103, 32104]
  broker_node_ids     = [0, 1, 2, 3]
  controller_node_ids = [100, 101, 102]
  kafka_cluster_name  = "kafka"
  internal_bootstrap  = "${local.kafka_cluster_name}-kafka-bootstrap.${var.kafka_namespace}.svc.cluster.local:9092"

  # Contiguous NodePort range covering the bootstrap service and all brokers.
  nodeport_range = "${local.bootstrap_node_port}-${local.broker_node_ports[length(local.broker_node_ports) - 1]}"
}
