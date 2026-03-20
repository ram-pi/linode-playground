#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
setup_wireguard_nat_gateway.sh

Install and configure a WireGuard server that also acts as an IPv4 NAT gateway.
Designed for Debian/Ubuntu.

Usage:
  sudo ./setup_wireguard_nat_gateway.sh [options]

Options:
  --wg-if <name>               WireGuard interface name (default: wg0)
  --wg-subnet <cidr>           WireGuard subnet CIDR (default: 10.88.0.0/24)
  --server-address <cidr>      Server WG address in CIDR (default: 10.88.0.1/24)
  --peer-address <cidr>        Peer WG interface address (default: 10.88.0.2/24)
  --peer-allowed-ip <cidr>     Peer routed IP/CIDR on server side (default: 10.88.0.2/32)
  --listen-port <port>         WireGuard UDP listen port (default: 51820)
  --public-if <iface>          Public egress interface (auto-detected if omitted)
  --endpoint <ip-or-dns>       Public endpoint for clients (auto-detected if omitted)
  --dns <csv>                  DNS servers for client profile (default: 1.1.1.1,8.8.8.8)
  --client-allowed-ips <csv>   AllowedIPs in client profile (default: 0.0.0.0/0)
  --peer-name <name>           Client profile name (default: client1)
  --output-dir <dir>           Output directory for client profile (default: /root)
  --no-ufw                     Do not modify UFW even if present
  -h, --help                   Show this help
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run as root (sudo)."
    exit 1
  fi
}

ensure_supported_os() {
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *"debian"* ]]; then
    echo "[ERROR] This script supports Debian/Ubuntu only. Found: ${PRETTY_NAME:-unknown}"
    exit 1
  fi
}

detect_public_interface() {
  local detected
  detected="$(ip route show default 0.0.0.0/0 | awk '/default/ {print $5; exit}')"
  [[ -n "${detected}" ]] || { echo "[ERROR] Could not auto-detect public interface. Use --public-if."; exit 1; }
  echo "${detected}"
}

detect_public_endpoint() {
  local iface="$1"
  local endpoint

  endpoint="$(curl -4fsS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ -z "${endpoint}" ]]; then
    endpoint="$(ip -4 -o addr show dev "${iface}" scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
  fi

  [[ -n "${endpoint}" ]] || { echo "[ERROR] Could not auto-detect endpoint. Use --endpoint."; exit 1; }
  echo "${endpoint}"
}

install_packages() {
  # Check if wireguard is already installed (from cloud-init)
  if command -v wg >/dev/null 2>&1; then
    return
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y wireguard wireguard-tools iptables iproute2 curl
}

enable_ip_forwarding() {
  cat >/etc/sysctl.d/99-wireguard-nat-gateway.conf <<EOF
net.ipv4.ip_forward = 1
EOF
  sysctl --system >/dev/null
}

configure_ufw() {
  if [[ "${USE_UFW}" == "false" ]]; then
    return
  fi

  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${LISTEN_PORT}/udp" || true
  fi
}

write_server_config() {
  local private_key="$1"
  local peer_public_key="$2"

  cat >"${WG_DIR}/${WG_IF}.conf" <<EOF
[Interface]
Address = ${WG_SERVER_ADDRESS}
ListenPort = ${LISTEN_PORT}
PrivateKey = ${private_key}
SaveConfig = false
PostUp = iptables -C FORWARD -i %i -j ACCEPT || iptables -A FORWARD -i %i -j ACCEPT; iptables -C FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || iptables -A FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -C POSTROUTING -s ${WG_SUBNET} -o ${PUBLIC_IF} -j MASQUERADE || iptables -t nat -A POSTROUTING -s ${WG_SUBNET} -o ${PUBLIC_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s ${WG_SUBNET} -o ${PUBLIC_IF} -j MASQUERADE

[Peer]
PublicKey = ${peer_public_key}
AllowedIPs = ${PEER_ALLOWED_IP}
PersistentKeepalive = 25
EOF

  chmod 600 "${WG_DIR}/${WG_IF}.conf"
}

write_client_config() {
  local peer_private_key="$1"
  local server_public_key="$2"
  local output_file="${OUTPUT_DIR}/${WG_IF}-${PEER_NAME}.conf"

  cat >"${output_file}" <<EOF
[Interface]
PrivateKey = ${peer_private_key}
Address = ${PEER_ADDRESS}
DNS = ${DNS_SERVERS}

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${ENDPOINT}:${LISTEN_PORT}
AllowedIPs = ${CLIENT_ALLOWED_IPS}
PersistentKeepalive = 25
EOF

  chmod 600 "${output_file}"
  echo "${output_file}"
}

WG_IF="wg0"
WG_SUBNET="10.88.0.0/24"
WG_SERVER_ADDRESS="10.88.0.1/24"
PEER_ADDRESS="10.88.0.2/24"
PEER_ALLOWED_IP="10.88.0.2/32"
LISTEN_PORT="51820"
PUBLIC_IF=""
ENDPOINT=""
DNS_SERVERS="1.1.1.1,8.8.8.8"
CLIENT_ALLOWED_IPS="0.0.0.0/0"
PEER_NAME="client1"
OUTPUT_DIR="/root"
USE_UFW="true"
WG_DIR="/etc/wireguard"
PEERS_DIR="${WG_DIR}/peers"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wg-if) WG_IF="$2"; shift 2 ;;
    --wg-subnet) WG_SUBNET="$2"; shift 2 ;;
    --server-address) WG_SERVER_ADDRESS="$2"; shift 2 ;;
    --peer-address) PEER_ADDRESS="$2"; shift 2 ;;
    --peer-allowed-ip) PEER_ALLOWED_IP="$2"; shift 2 ;;
    --listen-port) LISTEN_PORT="$2"; shift 2 ;;
    --public-if) PUBLIC_IF="$2"; shift 2 ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --dns) DNS_SERVERS="$2"; shift 2 ;;
    --client-allowed-ips) CLIENT_ALLOWED_IPS="$2"; shift 2 ;;
    --peer-name) PEER_NAME="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --no-ufw) USE_UFW="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1"; usage; exit 1 ;;
  esac
done

require_root
ensure_supported_os

[[ -n "${PUBLIC_IF}" ]] || PUBLIC_IF="$(detect_public_interface)"
[[ -n "${ENDPOINT}" ]] || ENDPOINT="$(detect_public_endpoint "${PUBLIC_IF}")"

mkdir -p "${WG_DIR}" "${PEERS_DIR}" "${OUTPUT_DIR}"
chmod 700 "${WG_DIR}" "${PEERS_DIR}"

install_packages
enable_ip_forwarding
configure_ufw

umask 077

SERVER_PRIVATE_KEY_FILE="${WG_DIR}/server-private.key"
SERVER_PUBLIC_KEY_FILE="${WG_DIR}/server-public.key"
PEER_PRIVATE_KEY_FILE="${PEERS_DIR}/${PEER_NAME}-private.key"
PEER_PUBLIC_KEY_FILE="${PEERS_DIR}/${PEER_NAME}-public.key"

if [[ ! -s "${SERVER_PRIVATE_KEY_FILE}" || ! -s "${SERVER_PUBLIC_KEY_FILE}" ]]; then
  wg genkey | tee "${SERVER_PRIVATE_KEY_FILE}" | wg pubkey > "${SERVER_PUBLIC_KEY_FILE}"
fi

if [[ ! -s "${PEER_PRIVATE_KEY_FILE}" || ! -s "${PEER_PUBLIC_KEY_FILE}" ]]; then
  wg genkey | tee "${PEER_PRIVATE_KEY_FILE}" | wg pubkey > "${PEER_PUBLIC_KEY_FILE}"
fi

SERVER_PRIVATE_KEY="$(cat "${SERVER_PRIVATE_KEY_FILE}")"
SERVER_PUBLIC_KEY="$(cat "${SERVER_PUBLIC_KEY_FILE}")"
PEER_PRIVATE_KEY="$(cat "${PEER_PRIVATE_KEY_FILE}")"
PEER_PUBLIC_KEY="$(cat "${PEER_PUBLIC_KEY_FILE}")"

write_server_config "${SERVER_PRIVATE_KEY}" "${PEER_PUBLIC_KEY}"
CLIENT_PROFILE="$(write_client_config "${PEER_PRIVATE_KEY}" "${SERVER_PUBLIC_KEY}")"

systemctl enable "wg-quick@${WG_IF}" >/dev/null
systemctl restart "wg-quick@${WG_IF}"

echo "[SUCCESS] WireGuard NAT gateway configured."
echo "  Public interface: ${PUBLIC_IF}"
echo "  Endpoint: ${ENDPOINT}:${LISTEN_PORT}"
echo "  Client profile: ${CLIENT_PROFILE}"
