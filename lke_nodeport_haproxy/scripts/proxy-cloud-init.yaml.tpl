#cloud-config
package_update: true
package_upgrade: true

hostname: ${hostname}
fqdn: ${hostname}.local
manage_etc_hosts: true
preserve_hostname: false
prefer_fqdn_over_hostname: true

packages:
  - haproxy
  - curl
  - jq
  - tcpdump
  - hatop
  - socat

write_files:
  - path: /etc/haproxy/haproxy.cfg
    permissions: "0644"
    owner: root:root
    content: |
      global
        log /dev/log local0
        log /dev/log local1 notice
        maxconn 200000
        stats socket /var/run/haproxy.sock mode 600 level admin
        daemon

      defaults
        log global
        mode http
        option httplog
        option dontlognull
        timeout connect 5s
        timeout client 30s
        timeout server 30s
        maxconn 100000

      frontend fe_nodeport
        bind *:80
        default_backend be_placeholder

      backend be_placeholder
        http-request return status 503 content-type text/plain string "HAProxy is up. Backends are not configured yet."

runcmd:
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - systemctl enable haproxy
  - systemctl restart haproxy
