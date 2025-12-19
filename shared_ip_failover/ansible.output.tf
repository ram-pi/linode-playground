# Ansible inventory
output "ansible_inventory" {
  value       = <<-EOF
    all:
      vars:
        ansible_user: root
        ansible_ssh_private_key_file: ${local_file.private_key.filename}
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

      children:
        haproxy_servers:
          hosts:
            host_01:
              ansible_host: ${local.host_01_public_ip}
              vlan_ip: ${split("/", local.vlan_address_map["host_01"])[0]}
            host_02:
              ansible_host: ${local.host_02_public_ip}
              vlan_ip: ${split("/", local.vlan_address_map["host_02"])[0]}

        nginx_backends:
          hosts:
            host_03:
              ansible_host: ${local.host_03_public_ip}
              vlan_ip: ${split("/", local.vlan_address_map["host_03"])[0]}
            host_04:
              ansible_host: ${local.host_04_public_ip}
              vlan_ip: ${split("/", local.vlan_address_map["host_04"])[0]}
  EOF
  description = "Ansible inventory file content"
}

# Command to run Ansible playbook
output "ansible_playbook_command" {
  value       = "cd ansible && ansible-playbook -i inventory.yml playbook.yml"
  description = "Command to run the Ansible playbook"
}
