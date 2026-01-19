#!/usr/bin/env python3
"""
Linode Prometheus Exporter

Exposes Linode resource metrics in Prometheus format.
"""

import os
import time
import signal
import sys
import threading
from prometheus_client import start_http_server, Gauge
from linode_api4 import LinodeClient


# Define Prometheus metrics with account_name label
linode_instances_total = Gauge('linode_instances_total', 'Total number of Linode instances', ['account_name'])
linode_buckets_total = Gauge('linode_buckets_total', 'Total number of Object Storage buckets', ['account_name'])
linode_vpcs_total = Gauge('linode_vpcs_total', 'Total number of VPCs', ['account_name'])
linode_lke_clusters_total = Gauge('linode_lke_clusters_total', 'Total number of LKE clusters', ['account_name'])
linode_lke_e_clusters_total = Gauge('linode_lke_e_clusters_total', 'Total number of LKE-e clusters', ['account_name'])
linode_tokens_total = Gauge('linode_tokens_total', 'Total number of API tokens', ['account_name'])
linode_firewalls_total = Gauge('linode_firewalls_total', 'Total number of Cloud Firewalls', ['account_name'])
linode_nodebalancers_total = Gauge('linode_nodebalancers_total', 'Total number of NodeBalancers', ['account_name'])
linode_nodebalancer_transfer_in_mb = Gauge('linode_nodebalancer_transfer_in_mb', 'NodeBalancer inbound transfer in MB', ['account_name', 'nodebalancer_id', 'nodebalancer_label'])
linode_nodebalancer_transfer_out_mb = Gauge('linode_nodebalancer_transfer_out_mb', 'NodeBalancer outbound transfer in MB', ['account_name', 'nodebalancer_id', 'nodebalancer_label'])
linode_nodebalancer_transfer_total_mb = Gauge('linode_nodebalancer_transfer_total_mb', 'NodeBalancer total transfer in MB', ['account_name', 'nodebalancer_id', 'nodebalancer_label'])
linode_nodebalancer_client_conn_throttle = Gauge('linode_nodebalancer_client_conn_throttle', 'NodeBalancer client connection throttle', ['account_name', 'nodebalancer_id', 'nodebalancer_label'])
linode_databases_total = Gauge('linode_databases_total', 'Total number of Managed Databases', ['account_name'])
linode_users_total = Gauge('linode_users_total', 'Total number of users on the account', ['account_name'])
linode_vlans_total = Gauge('linode_vlans_total', 'Total number of VLANs', ['account_name'])
linode_volumes_total = Gauge('linode_volumes_total', 'Total number of Block Storage volumes', ['account_name'])
linode_volumes_capacity_gb = Gauge('linode_volumes_capacity_gb', 'Total provisioned Block Storage capacity in GB', ['account_name'])


class LinodeExporter:
    """Linode Prometheus Exporter"""

    def __init__(self, api_token):
        """Initialize the exporter with Linode API client"""
        self.client = LinodeClient(api_token)

    def collect_metrics(self):
        """Collect all Linode metrics"""
        try:
            # Get account information
            account = self.client.account()
            account_name = account.company if account.company else account.email.split('@')[0]
            print(f"Account: {account_name}")
            print()

            # Count Linode instances
            instances = self.client.linode.instances()
            linode_instances_total.labels(account_name=account_name).set(len(instances))
            print(f"Linode instances: {len(instances)}")

            # Count Object Storage buckets
            buckets = self.client.object_storage.buckets()
            linode_buckets_total.labels(account_name=account_name).set(len(buckets))
            print(f"Object Storage buckets: {len(buckets)}")

            # Count VPCs
            vpcs = self.client.vpcs()
            linode_vpcs_total.labels(account_name=account_name).set(len(vpcs))
            print(f"VPCs: {len(vpcs)}")

            # Count LKE clusters and separate LKE-e clusters
            lke_clusters = self.client.lke.clusters()
            lke_standard_count = 0
            lke_e_count = 0

            for cluster in lke_clusters:
                # LKE-e clusters have tier = enterprise
                cluster_tier = getattr(cluster, 'tier', 'standard')
                if cluster_tier == 'enterprise':
                    lke_e_count += 1
                else:
                    lke_standard_count += 1

            linode_lke_clusters_total.labels(account_name=account_name).set(lke_standard_count)
            linode_lke_e_clusters_total.labels(account_name=account_name).set(lke_e_count)
            print(f"LKE clusters: {lke_standard_count}")
            print(f"LKE-e clusters: {lke_e_count}")

            # Count API tokens
            tokens = self.client.profile.tokens()
            linode_tokens_total.labels(account_name=account_name).set(len(tokens))
            print(f"API tokens: {len(tokens)}")

            # Count Cloud Firewalls
            firewalls = self.client.networking.firewalls()
            linode_firewalls_total.labels(account_name=account_name).set(len(firewalls))
            print(f"Cloud Firewalls: {len(firewalls)}")

            # Count NodeBalancers and collect traffic metrics
            nodebalancers = self.client.nodebalancers()
            linode_nodebalancers_total.labels(account_name=account_name).set(len(nodebalancers))
            print(f"NodeBalancers: {len(nodebalancers)}")

            # Collect detailed NodeBalancer metrics
            for nb in nodebalancers:
                nb_id = str(nb.id)
                nb_label = nb.label

                # Set transfer metrics (values are in MB from API)
                transfer_in = getattr(nb.transfer, 'in', 0) if nb.transfer else 0
                transfer_out = getattr(nb.transfer, 'out', 0) if nb.transfer else 0
                transfer_total = getattr(nb.transfer, 'total', 0) if nb.transfer else 0

                linode_nodebalancer_transfer_in_mb.labels(
                    account_name=account_name,
                    nodebalancer_id=nb_id,
                    nodebalancer_label=nb_label
                ).set(transfer_in)

                linode_nodebalancer_transfer_out_mb.labels(
                    account_name=account_name,
                    nodebalancer_id=nb_id,
                    nodebalancer_label=nb_label
                ).set(transfer_out)

                linode_nodebalancer_transfer_total_mb.labels(
                    account_name=account_name,
                    nodebalancer_id=nb_id,
                    nodebalancer_label=nb_label
                ).set(transfer_total)

                # Set throttle metric
                linode_nodebalancer_client_conn_throttle.labels(
                    account_name=account_name,
                    nodebalancer_id=nb_id,
                    nodebalancer_label=nb_label
                ).set(nb.client_conn_throttle)

                print(f"  - {nb_label} (ID: {nb_id}): in={transfer_in:.2f}MB, out={transfer_out:.2f}MB, total={transfer_total:.2f}MB, throttle={nb.client_conn_throttle}")

            # Count Managed Databases
            databases = self.client.database.instances()
            linode_databases_total.labels(account_name=account_name).set(len(databases))
            print(f"Managed Databases: {len(databases)}")

            # Count Users
            users = self.client.account.users()
            linode_users_total.labels(account_name=account_name).set(len(users))
            print(f"Users: {len(users)}")

            # Count VLANs
            vlans = self.client.networking.vlans()
            linode_vlans_total.labels(account_name=account_name).set(len(vlans))
            print(f"VLANs: {len(vlans)}")

            # Count Volumes and calculate total capacity
            volumes = self.client.volumes()
            total_capacity_gb = sum(volume.size for volume in volumes)
            linode_volumes_total.labels(account_name=account_name).set(len(volumes))
            linode_volumes_capacity_gb.labels(account_name=account_name).set(total_capacity_gb)
            print(f"Volumes: {len(volumes)}")
            print(f"Total volume capacity: {total_capacity_gb} GB")

            print("Metrics updated successfully")

        except Exception as e:
            print(f"Error collecting metrics: {e}")


def main():
    """Main function"""
    # Get API token from environment
    api_token = os.getenv('LINODE_TOKEN')
    if not api_token:
        print("Error: LINODE_TOKEN environment variable is not set")
        exit(1)

    # Get port from environment or use default
    port = int(os.getenv('EXPORTER_PORT', 9100))

    # Get scrape interval from environment or use default (60 seconds)
    scrape_interval = int(os.getenv('SCRAPE_INTERVAL', 60))

    print(f"Starting Linode Prometheus Exporter on port {port}")
    print(f"Scrape interval: {scrape_interval} seconds")
    print("-" * 50)

    # Start Prometheus HTTP server
    start_http_server(port)

    # Initialize exporter
    exporter = LinodeExporter(api_token)

    # Setup signal handler for graceful shutdown
    shutdown_event = threading.Event()

    def signal_handler(signum, frame):
        print("\nShutdown signal received, stopping exporter...")
        shutdown_event.set()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Collect metrics in a loop
    try:
        while not shutdown_event.is_set():
            exporter.collect_metrics()
            print(f"Waiting {scrape_interval} seconds until next scrape...")
            print("-" * 50)
            # Use wait instead of sleep to allow interruption
            shutdown_event.wait(scrape_interval)
    except KeyboardInterrupt:
        pass
    finally:
        print("Exporter stopped")
        sys.exit(0)


if __name__ == '__main__':
    main()
