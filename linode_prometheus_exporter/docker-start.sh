#!/bin/bash

set -e

echo "========================================="
echo "Starting Linode Monitoring Stack"
echo "========================================="
echo ""

# Check if LINODE_TOKEN is set
if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "Error: docker-compose is not installed"
    echo "Please install Docker Compose first"
    exit 1
fi

echo "Starting services with docker-compose..."
echo ""

# Use docker compose or docker-compose depending on what's available
if docker compose version &> /dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi

echo ""
echo "========================================="
echo "Monitoring Stack Started!"
echo "========================================="
echo ""
echo "Services:"
echo "  - Linode Exporter: http://localhost:9100/metrics"
echo "  - Prometheus:      http://localhost:9090"
echo "  - Grafana:         http://localhost:3000"
echo ""
echo "Grafana credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop the stack:"
echo "  docker-compose down -v"
echo ""
echo "========================================="
