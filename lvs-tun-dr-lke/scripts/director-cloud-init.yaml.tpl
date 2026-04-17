#cloud-config
package_update: true
package_upgrade: true

hostname: ${hostname}
fqdn: ${hostname}.local
manage_etc_hosts: true
preserve_hostname: false
prefer_fqdn_over_hostname: true

packages:
  - frr
  - ipvsadm
  - arping
  - jq
  - curl
  - tcpdump
  - hatop

write_files:
  - path: /etc/sysctl.d/99-lvs-dr.conf
    permissions: "0644"
    owner: root:root
    content: |
      net.ipv4.ip_forward=1
      net.ipv4.vs.conntrack=1

  - path: /etc/frr/daemons
    permissions: "0644"
    owner: root:root
    content: |
      bgpd=yes
      ospfd=no
      ospf6d=no
      ripd=no
      ripngd=no
      isisd=no
      pimd=no
      pim6d=no
      ldpd=no
      nhrpd=no
      eigrpd=no
      babeld=no
      sharpd=no
      pbrd=no
      pathd=no
      bfdd=no
      fabricd=no
      vrrpd=no
      zebra=yes

  - path: /etc/frr/frr.conf
    permissions: "0640"
    owner: frr:frr
    content: |
      frr version 8.4.4
      frr defaults traditional
      hostname ${hostname}
      service integrated-vtysh-config
      no ipv6 forwarding
      ! baseline config only
      !
      line vty

runcmd:
  - sysctl --system
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - systemctl enable frr
  - systemctl restart frr
