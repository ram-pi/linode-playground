variable "region" {
  description = "Linode region that supports LKE Enterprise"
  type        = string
  default     = "gb-lon"
}

variable "k8s_version" {
  description = "LKE Enterprise Kubernetes version; query current values with linode-cli lke tiered-versions-list enterprise"
  type        = string
  default     = "v1.34.6+lke2"
}

variable "cluster_label" {
  description = "Label for the LKE Enterprise cluster"
  type        = string
  default     = "lke-strimzi-kraft"
}

variable "kraft_node_type" {
  description = "Linode instance type for the KRaft controller node pool (4 vCPU / 8 GB)"
  type        = string
  default     = "g6-standard-4"
}

variable "kraft_node_count" {
  description = "Number of KRaft controller nodes (must be an odd number for quorum)"
  type        = number
  default     = 3

  validation {
    condition     = var.kraft_node_count >= 3 && var.kraft_node_count % 2 == 1
    error_message = "kraft_node_count must be an odd number of at least 3 to form a stable KRaft quorum."
  }
}

variable "broker_node_type" {
  description = "Linode instance type for the Kafka broker node pool (8 vCPU / 16 GB)"
  type        = string
  default     = "g6-dedicated-8"
}

variable "broker_node_count" {
  description = "Number of Kafka broker nodes"
  type        = number
  default     = 4

  validation {
    condition     = var.broker_node_count >= 3
    error_message = "broker_node_count must be at least 3 so that the RF=3 topics have one replica per broker."
  }
}

variable "monitoring_node_type" {
  description = "Linode instance type for the monitoring node pool (Prometheus and Grafana)"
  type        = string
  default     = "g6-standard-2"
}

variable "system_node_type" {
  description = "Linode instance type for the untainted system node pool that hosts LKE add-ons (CoreDNS, Cilium operator, autoscalers)"
  type        = string
  default     = "g6-standard-2"
}

variable "system_node_count" {
  description = "Number of system nodes. Must be at least 3 because workload-coredns runs 3 replicas with required hostname anti-affinity."
  type        = number
  default     = 3

  validation {
    condition     = var.system_node_count >= 3
    error_message = "system_node_count must be at least 3. workload-coredns runs 3 replicas with required pod anti-affinity on kubernetes.io/hostname, so fewer nodes causes Pending DNS pods once the Kafka pools are tainted."
  }
}

variable "monitoring_node_count" {
  description = "Number of monitoring nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.monitoring_node_count >= 1
    error_message = "monitoring_node_count must be at least 1."
  }
}

variable "vpc_ipv4_cidr" {
  description = "IPv4 CIDR for the LKE Enterprise VPC subnet. LKE requires a /13 or /14 prefix length."
  type        = string
  default     = "10.60.0.0/14"

  validation {
    condition     = can(cidrnetmask(var.vpc_ipv4_cidr)) && tonumber(split("/", var.vpc_ipv4_cidr)[1]) <= 14 && tonumber(split("/", var.vpc_ipv4_cidr)[1]) >= 13
    error_message = "vpc_ipv4_cidr must be a valid CIDR with a prefix length of /13 or /14; LKE rejects other subnet sizes."
  }
}

variable "vpc_ipv6_prefix" {
  description = "IPv6 prefix length allocated to the VPC. A dual-stack VPC is required to assign a custom VPC to an LKE Enterprise cluster."
  type        = string
  default     = "/48"
}

variable "subnet_ipv6_prefix" {
  description = "IPv6 prefix length allocated to the VPC subnet"
  type        = string
  default     = "/52"
}

variable "control_plane_allowed_ipv4_cidrs" {
  description = "IPv4 CIDRs allowed to access the Kubernetes control plane"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "control_plane_allowed_ipv6_cidrs" {
  description = "IPv6 CIDRs allowed to access the Kubernetes control plane"
  type        = list(string)
  default     = ["::/0"]
}

variable "broker_nodeport_allowed_ipv4_cidrs" {
  description = "IPv4 CIDRs allowed to reach the Kafka NodePort listener. The listener advertises the node InternalIP, so only clients with a route to the VPC can use it; allowing public CIDRs here has no effect unless preferredNodePortAddressType is changed to ExternalIP."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "kafka_namespace" {
  description = "Kubernetes namespace for the Kafka cluster"
  type        = string
  default     = "kafka"
}

variable "kafka_version" {
  description = "Kafka version deployed by Strimzi"
  type        = string
  default     = "4.3.1"
}

variable "strimzi_version" {
  description = "Strimzi Kafka Operator version"
  type        = string
  default     = "1.2.0"
}

variable "controller_storage_size" {
  description = "Persistent volume size per KRaft controller (metadata log only)"
  type        = string
  default     = "20Gi"
}

variable "broker_storage_size" {
  description = "Persistent volume size per Kafka broker"
  type        = string
  default     = "100Gi"
}

variable "storage_class" {
  description = "StorageClass for Kafka persistent volumes"
  type        = string
  default     = "linode-block-storage-retain"
}

variable "tags" {
  description = "Tags applied to created Linode resources"
  type        = list(string)
  default     = ["lke-strimzi-kraft"]
}
