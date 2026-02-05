locals {
  public_ip       = tolist(linode_instance.bastion.ipv4[*])[0]
  scraping_target = "${local.public_ip}:9835/metrics"
}

# # SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${local.public_ip}"
  description = "SSH command to connect to the VM"
}

output "prometheus_scrape_config" {
  value = <<EOT
  - job_name: "nvidia"
    static_configs:
      - targets: ["${local.public_ip}:9835"]
  - job_name: "nim"
    scrape_interval: 10s
    static_configs:
      - targets: ["${local.public_ip}:8000"]
EOT
}

output "scraping_target" {
  value = local.scraping_target
}
