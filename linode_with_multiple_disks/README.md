# Linode with Multiple Disks

Demonstrates how to provision a Linode instance with multiple encrypted Block Storage volumes and configure automated backups to Object Storage using rclone.

## Architecture

!![diagram](drawio.svg)

This project creates:
- **Bastion host** (Ubuntu 24.04, g6-nanode-1) with multi-network configuration
- **2 encrypted Block Storage volumes** (20GB + 10GB) attached to the instance
- **Object Storage bucket** for volume backups with 30-day lifecycle policy
- **Instance backups** enabled with configurable schedule

## Features

- **Encrypted volumes**: Both volumes use Linode's encryption-at-rest
- **Automated backup script**: Syncs volume data to Object Storage with rclone
- **Environment-based configuration**: All backup parameters via environment variables
- **Rclone Web UI**: Built-in monitoring and metrics during backup operations
- **Lifecycle management**: Auto-deletion of backups older than 30 days

## Quick Start

```bash
# Provision infrastructure
./start.sh

# The script will output:
# - Instance IP address
# - SSH command
# - Object Storage credentials
# - Backup script usage

# SSH into the instance
ssh -i /tmp/id_rsa root@<instance-ip>
```

## Backup Script

The `scripts/backup.sh` script syncs volume data to Object Storage with full observability:

### Required Environment Variables

```bash
export SOURCE_DIR='/mnt/volume_data'                    # Directory to backup
export LINODE_ACCESS_KEY='your-access-key'              # Object Storage access key
export LINODE_SECRET_KEY='your-secret-key'              # Object Storage secret key
export S3_ENDPOINT='us-east-1.linodeobjects.com'        # Object Storage endpoint
export BACKUP_LABEL='my-backups'                        # Bucket name/label
```

### Features

- **Auto-install**: Checks for rclone and installs if missing
- **Configuration file**: Generates temporary rclone config at `/tmp/rclone.conf`
- **Web UI**: Access at `http://<instance-ip>:5572` during backup
- **Metrics endpoint**: `http://<instance-ip>:5572/metrics`
- **No authentication**: Web UI runs without auth for testing (use `--rc-user/--rc-pass` in production)
- **Bandwidth limiting**: 200KB/s for testing purposes
- **Parallel transfers**: 16 concurrent transfers for better performance
- **Logging**: Detailed logs saved to `/var/log/rclone-backup.log`

### Usage Example

```bash
# Set environment variables
export SOURCE_DIR='/mnt/volume-1'
export LINODE_ACCESS_KEY='ABC123...'
export LINODE_SECRET_KEY='xyz789...'
export S3_ENDPOINT='fr-par-1.linodeobjects.com'
export BACKUP_LABEL='volume-backups'

# Run backup
./scripts/backup.sh

# Monitor progress via web UI
curl http://localhost:5572/
```

## Object Storage Lifecycle

The bucket includes a lifecycle rule that automatically deletes backups older than 30 days:

```hcl
lifecycle_rule {
  id      = "delete-old-backups"
  enabled = true
  expiration {
    days = 30
  }
}
```

## Cleanup

```bash
# Destroy all resources
./shutdown.sh
```

**Note:** This will delete the instance, volumes, and Object Storage bucket (including all backups).

## Gotchas

- **Volume mounting**: Volumes appear as `/dev/sdc` and `/dev/sdd` - you need to format and mount them manually
- **Backup timing**: Consider running backups during off-peak hours or using cron
- **Bandwidth limits**: Adjust `--bwlimit` in backup script based on your network capacity
- **Web UI security**: The backup script runs rclone RC without authentication - use `--rc-user` and `--rc-pass` for production
- **Credentials**: Never commit Object Storage credentials to version control

## Resources

- [Linode Block Storage](https://www.linode.com/docs/products/storage/block-storage/)
- [Linode Object Storage](https://www.linode.com/docs/products/storage/object-storage/)
- [rclone Documentation](https://rclone.org/docs/)
- [rclone RC API](https://rclone.org/rc/)
