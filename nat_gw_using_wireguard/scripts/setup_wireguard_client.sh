#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
setup_wireguard_client.sh

Install WireGuard on Debian/Ubuntu and bring up a client tunnel from an existing config file.

Usage:
  sudo ./setup_wireguard_client.sh --config /root/wg0.conf [--wg-if wg0] [--apt-proxy http://10.50.0.10:8080]

Options:
  --config <path>      Path to WireGuard client config (required)
  --wg-if <name>       Interface name (default: wg0)
  --apt-proxy <url>    HTTP proxy URL for apt/bootstrap on private-only hosts
  --disable-ufw-rule   Do not add UFW rule for outbound UDP/51820
  -h, --help           Show this help
EOF
}

configure_proxy() {
  if [[ -z "${APT_PROXY}" ]]; then
    return
  fi

  cat >/etc/apt/apt.conf.d/99bootstrap-proxy <<EOF
Acquire::http::Proxy "${APT_PROXY}";
Acquire::https::Proxy "${APT_PROXY}";
EOF

  export http_proxy="${APT_PROXY}"
  export https_proxy="${APT_PROXY}"
  export HTTP_PROXY="${APT_PROXY}"
  export HTTPS_PROXY="${APT_PROXY}"
}

CONFIG_PATH=""
WG_IF="wg0"
APT_PROXY=""
USE_UFW="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_PATH="$2"; shift 2 ;;
    --wg-if) WG_IF="$2"; shift 2 ;;
    --apt-proxy) APT_PROXY="$2"; shift 2 ;;
    --disable-ufw-rule) USE_UFW="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] Run as root (sudo)."
  exit 1
fi

if [[ -z "${CONFIG_PATH}" ]]; then
  echo "[ERROR] --config is required."
  usage
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "[ERROR] Config file not found: ${CONFIG_PATH}"
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *"debian"* ]]; then
  echo "[ERROR] This script supports Debian/Ubuntu only. Found: ${PRETTY_NAME:-unknown}"
  exit 1
fi

if ! command -v wg >/dev/null 2>&1; then
  if [[ -z "${APT_PROXY}" ]]; then
    echo "[ERROR] WireGuard is not installed and no --apt-proxy was provided."
    echo "[ERROR] On private-only VPC hosts, pass --apt-proxy http://<gateway-vpc-ip>:8080"
    exit 1
  fi

  configure_proxy
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y wireguard wireguard-tools iproute2 curl
fi

install -d -m 700 /etc/wireguard
install -m 600 "${CONFIG_PATH}" "/etc/wireguard/${WG_IF}.conf"

if [[ "${USE_UFW}" == "true" ]] && command -v ufw >/dev/null 2>&1; then
  ufw allow out 51820/udp || true
fi

systemctl enable "wg-quick@${WG_IF}" >/dev/null
systemctl restart "wg-quick@${WG_IF}"

echo "[SUCCESS] WireGuard client configured on ${WG_IF}."
echo "Validation commands:"
echo "  wg show ${WG_IF}"
echo "  ip route"
echo "  curl -4 ifconfig.me"
