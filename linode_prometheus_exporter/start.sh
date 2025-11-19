#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Linode Prometheus Exporter"
echo "========================================="
echo ""

# Check if LINODE_TOKEN is set
if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    echo "Please install Python 3 first"
    exit 1
fi

# Step 1: Setup virtual environment
echo "Step 1: Setting up virtual environment..."
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate virtual environment
source venv/bin/activate
echo "✓ Virtual environment activated"
echo ""

# Step 2: Install dependencies
echo "Step 2: Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
echo "✓ Dependencies installed"
echo ""

# Set default port and scrape interval if not set
export EXPORTER_PORT=${EXPORTER_PORT:-9100}
export SCRAPE_INTERVAL=${SCRAPE_INTERVAL:-60}

# Step 3: Start the exporter
echo "Step 3: Starting exporter..."
echo "Port: $EXPORTER_PORT"
echo "Scrape interval: $SCRAPE_INTERVAL seconds"
echo ""
echo "Metrics will be available at: http://localhost:$EXPORTER_PORT/metrics"
echo ""
echo "Press Ctrl+C to stop the exporter"
echo "========================================="
echo ""

python3 exporter.py
