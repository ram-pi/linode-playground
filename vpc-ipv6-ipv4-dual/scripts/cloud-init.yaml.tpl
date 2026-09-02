#cloud-config
hostname: ${hostname}
manage_etc_hosts: true
package_update: true
packages:
  - iputils-ping
