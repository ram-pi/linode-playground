#!/bin/bash

set -e

echo "========================================="
echo "Starting Linode Node Exporter Demo"
echo "========================================="
echo ""

if [ -z "$LINODE_TOKEN" ]; then
  echo "Error: LINODE_TOKEN environment variable is not set"
  echo "Please export your Linode API token:"
  echo "  export LINODE_TOKEN='your-token-here'"
  exit 1
fi

if command -v tofu >/dev/null 2>&1; then
  TF_BIN="tofu"
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN="terraform"
else
  echo "Error: neither 'tofu' nor 'terraform' is installed"
  exit 1
fi

echo "Using $TF_BIN"
echo ""

echo "Step 1: Initializing..."
"$TF_BIN" init
echo ""

echo "Step 2: Planning..."
"$TF_BIN" plan
echo ""

echo "Step 3: Applying..."
"$TF_BIN" apply -auto-approve
echo ""

echo "========================================="
echo "Deployment completed successfully"
echo "========================================="
echo ""

echo "SSH exporter VM:"
"$TF_BIN" output -raw ssh_exporter
echo ""

echo "SSH monitoring VM:"
"$TF_BIN" output -raw ssh_monitoring
echo ""

echo "Grafana URL:"
"$TF_BIN" output -raw grafana_url
echo ""

echo "Grafana login:"
echo "  user: admin"
echo "  pass: admin (Grafana will ask to change on first login)"
echo ""

echo "Prometheus URL:"
"$TF_BIN" output -raw prometheus_url
echo ""

echo "SSH key path: /tmp/id_rsa"
echo ""
echo "Waiting 90 seconds for cloud-init to finish..."
for i in {90..1}; do
  printf "\rTime remaining: %02d seconds" "$i"
  sleep 1
done
echo ""
echo ""

echo "Tip: verify cloud-init status after SSH:"
echo "  cloud-init status --wait"
echo ""
echo "Useful log commands:"
echo "  Exporter VM:   journalctl -u alloy -u node_exporter -f --no-pager"
echo "  Monitoring VM: journalctl -u prometheus -u loki -u grafana-server -f --no-pager"
echo "  Cloud-init:    tail -f /var/log/cloud-init-output.log"
