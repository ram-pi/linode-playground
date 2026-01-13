#cloud-config
package_update: true
package_upgrade: true

hostname: ${hostname}
fqdn: ${hostname}.local
manage_etc_hosts: true
preserve_hostname: false
prefer_fqdn_over_hostname: true

packages:
  - jq
  - postgresql-client
  - net-tools
  - nc
  - tcpdump
  - podman
  - podman-docker # Optional: Installs the 'docker' command alias for podman

runcmd:
  # Disable SSH password authentication for security
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd

  # Install kubectl using snap (classic confinement is required for kubectl)
  - snap install kubectl --classic

  # (Optional) Alias kubectl to 'k' for efficiency
  - snap alias kubectl k
