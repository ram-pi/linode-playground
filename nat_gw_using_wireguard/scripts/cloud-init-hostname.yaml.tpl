#cloud-config
hostname: ${hostname}
manage_etc_hosts: true

runcmd:
  - timedatectl set-timezone UTC || true
