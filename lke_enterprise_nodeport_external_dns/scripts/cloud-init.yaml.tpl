#cloud-config
hostname: lke-nodeport-client
package_update: true
packages:
  - curl
  - dnsutils
ssh_pwauth: false

# Zone-scoped resolver drop-in. Linode Network Helper only regenerates
# /etc/systemd/network/05-eth0.network on each boot, so a systemd-resolved
# drop-in is not overwritten by it and survives reboots.
write_files:
  - path: /etc/systemd/resolved.conf.d/linode-internal.conf
    owner: root:root
    permissions: "0644"
    content: |
      [Resolve]
      DNS=${nameservers}
      Domains=~${dns_zone}

runcmd:
  - systemctl restart systemd-resolved
