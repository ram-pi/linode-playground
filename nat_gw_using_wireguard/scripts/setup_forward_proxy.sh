#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
setup_forward_proxy.sh

Install and configure Squid as a forward proxy on Debian/Ubuntu.

Usage:
  sudo ./setup_forward_proxy.sh [options]

Options:
  --listen-ip <ip>      IP address to bind Squid on (required)
  --allow-cidr <cidr>   Client CIDR allowed to use the proxy (required)
  --port <port>         Proxy port (default: 8080)
  --no-ufw              Do not modify UFW even if present
  -h, --help            Show this help
EOF
}

LISTEN_IP=""
ALLOW_CIDR=""
PORT="8080"
USE_UFW="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --listen-ip) LISTEN_IP="$2"; shift 2 ;;
    --allow-cidr) ALLOW_CIDR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --no-ufw) USE_UFW="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Run as root (sudo)."
  exit 1
fi

if [[ -z "${LISTEN_IP}" || -z "${ALLOW_CIDR}" ]]; then
  echo "[ERROR] --listen-ip and --allow-cidr are required."
  usage
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *"debian"* ]]; then
  echo "[ERROR] This script supports Debian/Ubuntu only. Found: ${PRETTY_NAME:-unknown}"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y squid curl

cat >/etc/squid/squid.conf <<EOF
http_port ${LISTEN_IP}:${PORT}

acl allowed_clients src ${ALLOW_CIDR}
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow allowed_clients
http_access deny all

cache deny all
forwarded_for delete
via off
EOF

if [[ "${USE_UFW}" == "true" ]] && command -v ufw >/dev/null 2>&1; then
  ufw allow from "${ALLOW_CIDR}" to any port "${PORT}" proto tcp || true
fi

systemctl enable squid >/dev/null
systemctl restart squid

echo "[SUCCESS] Forward proxy configured."
echo "  Listen: ${LISTEN_IP}:${PORT}"
echo "  Allowed CIDR: ${ALLOW_CIDR}"
echo ""
echo "Validation commands:"
echo "  systemctl status squid --no-pager"
echo "  ss -ltnp | grep ${PORT}"
echo "  curl --proxy http://${LISTEN_IP}:${PORT} http://example.com"
