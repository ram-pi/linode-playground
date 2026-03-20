#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
verify_proxy_and_wireguard.sh

Run end-to-end checks for the nat_gw_using_wireguard example.

This script verifies:
- Squid is active on the public VM
- The private VM can reach HTTP and HTTPS destinations through the forward proxy
- WireGuard is active on both VMs
- The private VM egress public IP matches the NAT gateway public IP

Usage:
  ./scripts/verify_proxy_and_wireguard.sh [options]

Options:
  --key-path <path>   SSH private key path (default: /tmp/id_rsa_nat_gw_wg)
  --module-dir <dir>  Example directory containing tofu state (default: current directory)
  -h, --help          Show this help
EOF
}

KEY_PATH="/tmp/id_rsa_nat_gw_wg"
MODULE_DIR="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key-path) KEY_PATH="$2"; shift 2 ;;
    --module-dir) MODULE_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ ! -f "$KEY_PATH" ]]; then
  echo "[ERROR] SSH key not found: $KEY_PATH"
  exit 1
fi

if [[ ! -d "$MODULE_DIR" ]]; then
  echo "[ERROR] Module directory not found: $MODULE_DIR"
  exit 1
fi

if ! command -v tofu >/dev/null 2>&1; then
  echo "[ERROR] tofu is required but not installed."
  exit 1
fi

cd "$MODULE_DIR"

NAT_PUBLIC_IP="$(tofu output -raw nat_gateway_public_ip)"
NAT_VPC_IP="$(tofu output -raw nat_gateway_vpc_ip)"
PRIVATE_VPC_IP="$(tofu output -raw private_vm_vpc_ip)"
PROXY_URL="http://${NAT_VPC_IP}:8080"

SSH_OPTS=(
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

JUMP_OPTS=(
  -i "$KEY_PATH"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ProxyCommand=ssh\ -i\ "$KEY_PATH"\ -o\ IdentitiesOnly=yes\ -o\ StrictHostKeyChecking=no\ -o\ UserKnownHostsFile=/dev/null\ -W\ %h:%p\ root@"$NAT_PUBLIC_IP"
)

run_nat() {
  ssh "${SSH_OPTS[@]}" root@"$NAT_PUBLIC_IP" "$@"
}

run_private() {
  ssh "${JUMP_OPTS[@]}" root@"$PRIVATE_VPC_IP" "$@"
}

check() {
  local label="$1"
  shift
  echo "[CHECK] $label"
  "$@"
  echo "[OK] $label"
  echo ""
}

check "Squid service is active on NAT gateway" \
  run_nat "systemctl is-active --quiet squid"

check "WireGuard service is active on NAT gateway" \
  run_nat "systemctl is-active --quiet wg-quick@wg0"

check "HTTP proxy works from private VM" \
  run_private "curl --proxy ${PROXY_URL} -fsSI http://example.com >/dev/null"

check "HTTPS proxy CONNECT works from private VM" \
  run_private "curl --proxy ${PROXY_URL} -fsSI https://deb.debian.org >/dev/null"

check "WireGuard service is active on private VM" \
  run_private "systemctl is-active --quiet wg-quick@wg0"

check "WireGuard handshake is present on private VM" \
  run_private "wg show wg0 latest-handshakes | awk 'NR == 1 { found = 1 } { if (\$2 == 0) exit 1 } END { exit(found ? 0 : 1) }'"

PRIVATE_EGRESS_IP="$(run_private "curl -4fsS https://ipv4.icanhazip.com | tr -d '[:space:]'")"

if [[ "$PRIVATE_EGRESS_IP" != "$NAT_PUBLIC_IP" ]]; then
  echo "[ERROR] Private VM egress IP mismatch. Expected $NAT_PUBLIC_IP, got $PRIVATE_EGRESS_IP"
  exit 1
fi

echo "[OK] Private VM egress IP matches NAT gateway public IP: $PRIVATE_EGRESS_IP"
echo ""
echo "[SUCCESS] Proxy bootstrap and WireGuard verification passed."
