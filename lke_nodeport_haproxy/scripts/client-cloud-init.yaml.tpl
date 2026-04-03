#cloud-config
package_update: true
package_upgrade: true

hostname: ${hostname}
fqdn: ${hostname}.local
manage_etc_hosts: true
preserve_hostname: false
prefer_fqdn_over_hostname: true

packages:
  - curl
  - jq
  - wget
  - ca-certificates
  - wrk

runcmd:
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
