from linode_api4 import LinodeClient, Instance, Firewall
from linode_api4.errors import ApiError
import os

# Create a Linode API client
client = LinodeClient(os.getenv("LINODE_TOKEN"))

linodes: list[Instance] = client.linode.instances()
firewall_rules: list[Firewall] = client.networking.firewalls()

# Pre-filter firewalls that have tags
tagged_firewalls = [fw for fw in firewall_rules if fw.tags]

for current_linode in linodes:
    print(f"\nLinode ID: {current_linode.id} | Tags: {current_linode.tags}")

    if not current_linode.tags:
        print("  Skipping: No tags on this Linode")
        continue

    # Get existing firewalls once
    existing_firewalls = current_linode.firewalls()
    existing_fw_ids = {fw.id for fw in existing_firewalls}

    # Find matching firewall
    matching_firewall = None
    for rule in tagged_firewalls:
        if any(tag in current_linode.tags for tag in rule.tags):
            matching_firewall = rule
            break

    if not matching_firewall:
        print("  No matching firewall found for this Linode's tags")
        continue

    # Check if already attached
    if matching_firewall.id in existing_fw_ids:
        print(f"  ✓ Firewall {matching_firewall.id} already attached")
        continue

    print(f"  Applying Firewall ID: {matching_firewall.id} with Tags: {matching_firewall.tags}")

    # Remove all existing firewalls from this Linode first
    for existing_fw in existing_firewalls:
        print(f"    Removing existing Firewall ID: {existing_fw.id}")
        try:
            for device in existing_fw.devices:
                if device.entity.id == current_linode.id:
                    device.delete()
                    print(f"      ✓ Removed from Firewall {existing_fw.id}")
                    break
        except ApiError as e:
            print(f"      ✗ Error removing firewall: {e}")

    # Attach the new firewall
    try:
        matching_firewall.device_create(id=current_linode.id, type="linode")
        print(f"    ✓ Successfully attached firewall {matching_firewall.id}")
    except ApiError as e:
        print(f"    ✗ Error attaching firewall: {e}")
