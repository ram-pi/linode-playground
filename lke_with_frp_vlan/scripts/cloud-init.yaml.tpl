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
  - net-tools
  - tcpdump
  - curl
  - wget

runcmd:
  # Disable SSH password authentication
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd

  # Download and install frps
  - mkdir -p /opt/frp /etc/frp
  - wget -q "https://github.com/fatedier/frp/releases/download/v${frp_version}/frp_${frp_version}_linux_amd64.tar.gz" -O /tmp/frp.tar.gz
  - tar -xzf /tmp/frp.tar.gz -C /tmp
  - cp "/tmp/frp_${frp_version}_linux_amd64/frps" /usr/local/bin/frps
  - chmod +x /usr/local/bin/frps
  - rm -rf /tmp/frp.tar.gz "/tmp/frp_${frp_version}_linux_amd64"

  # Write frps configuration
  - |
    cat > /etc/frp/frps.toml <<'EOF'
    bindPort = ${frp_bind_port}

    auth.method = "token"
    auth.token  = "${frp_token}"

    # Web dashboard (publicly reachable, restricted by Linode firewall whitelist)
    webServer.addr     = "0.0.0.0"
    webServer.port     = 7500
    webServer.user     = "admin"
    webServer.password = "${frp_token}"

    log.to    = "/var/log/frps.log"
    log.level = "info"
    EOF

  # Create systemd service for frps
  - |
    cat > /etc/systemd/system/frps.service <<'EOF'
    [Unit]
    Description=frp Server (frps)
    After=network.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
    Restart=on-failure
    RestartSec=5s
    LimitNOFILE=1048576

    [Install]
    WantedBy=multi-user.target
    EOF

  - systemctl daemon-reload
  - systemctl enable frps
  - systemctl start frps
