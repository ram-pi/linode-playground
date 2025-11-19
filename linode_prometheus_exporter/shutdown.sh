#!/bin/bash

echo "========================================="
echo "Stopping Linode Prometheus Exporter"
echo "========================================="
echo ""

# Deactivate virtual environment if active
if [ -n "$VIRTUAL_ENV" ]; then
    deactivate
    echo "✓ Virtual environment deactivated"
fi

echo ""
echo "To remove the virtual environment, run:"
echo "  rm -rf venv"
echo ""
echo "========================================="
echo "Exporter stopped"
echo "========================================="
