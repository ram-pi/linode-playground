#!/bin/bash

set -e  # Exit on error

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "rclone not found, installing..."

    # Download and install rclone
    curl https://rclone.org/install.sh | sudo bash

    # Verify installation
    if ! command -v rclone &> /dev/null; then
        echo "Error: Failed to install rclone"
        exit 1
    fi

    echo "✓ rclone installed successfully"
else
    echo "✓ rclone is already installed ($(rclone version | head -n1))"
fi

# Check required environment variables
if [ -z "$SOURCE_DIR" ]; then
    echo "Error: SOURCE_DIR environment variable is not set"
    echo "Please export the source directory to backup:"
    echo "  export SOURCE_DIR='/mnt/volume_data'"
    exit 1
fi

if [ -z "$LINODE_ACCESS_KEY" ]; then
    echo "Error: LINODE_ACCESS_KEY environment variable is not set"
    echo "Please export your Linode Object Storage access key:"
    echo "  export LINODE_ACCESS_KEY='your-access-key-here'"
    exit 1
fi

if [ -z "$LINODE_SECRET_KEY" ]; then
    echo "Error: LINODE_SECRET_KEY environment variable is not set"
    echo "Please export your Linode Object Storage secret key:"
    echo "  export LINODE_SECRET_KEY='your-secret-key-here'"
    exit 1
fi

if [ -z "$S3_ENDPOINT" ]; then
    echo "Error: S3_ENDPOINT environment variable is not set"
    echo "Please export your Linode Object Storage endpoint:"
    echo "  export S3_ENDPOINT='us-east-1.linodeobjects.com'"
    exit 1
fi

if [ -z "$BACKUP_LABEL" ]; then
    echo "Error: BACKUP_LABEL environment variable is not set"
    echo "Please export the backup label/bucket name:"
    echo "  export BACKUP_LABEL='my-backups'"
    exit 1
fi

# Configuration
DEST_BUCKET="linode_s3:${BACKUP_LABEL}/$(date +%Y-%m-%d)"
RCLONE_RC_PORT=5572
RCLONE_WEB_GUI_PORT=5573
RCLONE_CONFIG_FILE="/tmp/rclone.conf"

# Create rclone configuration file
echo "Creating rclone configuration..."
cat > $RCLONE_CONFIG_FILE << EOF
[linode_s3]
type = s3
provider = Linode
access_key_id = $LINODE_ACCESS_KEY
secret_access_key = $LINODE_SECRET_KEY
endpoint = $S3_ENDPOINT
acl = private
EOF

echo "✓ Configuration file created at $RCLONE_CONFIG_FILE"

# Start rclone with remote control and web UI enabled (no auth for testing)
echo "Starting rclone with metrics and web UI..."

# Build the command
# --bwlimit=0.2M to limit bandwidth usage to 200KB/s
RCLONE_CMD="rclone sync $SOURCE_DIR $DEST_BUCKET \
    --config=$RCLONE_CONFIG_FILE \
    --transfers=16 \
    --bwlimit=0.2M \
    --log-file=/var/log/rclone-backup.log \
    --log-level=DEBUG \
    --rc \
    --rc-addr=0.0.0.0:$RCLONE_RC_PORT \
    --rc-web-gui \
    --rc-web-gui-no-open-browser \
    --rc-enable-metrics \
    --rc-serve \
    --rc-no-auth"

# Print the command
echo "Running: $RCLONE_CMD"
echo "Logs available at /var/log/rclone-backup.log"
echo "--> tail -100f /var/log/rclone-backup.log to monitor progress"
echo ""

# Execute the command
eval $RCLONE_CMD

EXIT_CODE=$?

# Clean up configuration file
rm -f $RCLONE_CONFIG_FILE
echo "✓ Configuration file cleaned up"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Backup completed successfully"
    echo "  Web UI: http://localhost:$RCLONE_RC_PORT"
    echo "  Metrics: http://localhost:$RCLONE_RC_PORT/metrics"
else
    echo "✗ Backup failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi
