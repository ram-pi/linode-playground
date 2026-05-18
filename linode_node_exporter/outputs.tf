output "exporter_public_ip" {
  description = "Public IP for exporter VM"
  value       = tolist(linode_instance.exporter.ipv4)[0]
}

output "monitoring_public_ip" {
  description = "Public IP for monitoring VM"
  value       = tolist(linode_instance.monitoring.ipv4)[0]
}

output "exporter_vpc_ip" {
  description = "Exporter VPC IP"
  value       = var.exporter_vpc_ip
}

output "monitoring_vpc_ip" {
  description = "Monitoring VPC IP"
  value       = var.monitoring_vpc_ip
}

output "ssh_exporter" {
  description = "SSH command for exporter VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.exporter.ipv4)[0]}"
}

output "ssh_monitoring" {
  description = "SSH command for monitoring VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.monitoring.ipv4)[0]}"
}

output "grafana_url" {
  description = "Grafana UI URL"
  value       = "http://${tolist(linode_instance.monitoring.ipv4)[0]}:3000"
}

output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://${tolist(linode_instance.monitoring.ipv4)[0]}:9090"
}
