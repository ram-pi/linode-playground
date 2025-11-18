from linode_api4 import LinodeClient, Instance, Firewall
from linode_api4.errors import ApiError
import os

# Create a Linode API client
client = LinodeClient(os.getenv("LINODE_TOKEN"))

linodes: list[Instance] = client.linode.instances()
# firewall_rules = client.linode.firewalls()
firewall_rules: list[Firewall] = client.networking.firewalls()


for current_linode in linodes:
    print(f"Linode ID: {current_linode.id}")
    print(f"Tags: {current_linode.tags}")

    for rule in firewall_rules:
        print(f"Firewall ID: {rule.id} with Tags: {rule.tags}")
        if (
            rule.tags and
            any(tag in current_linode.tags for tag in rule.tags) and
            rule.id not in [fw.id for fw in current_linode.firewalls()]
        ):
            print(f"  Applying Firewall ID: {rule.id} with Tags: {rule.tags}")

            # Remove all existing firewalls from this Linode first
            existing_firewalls = current_linode.firewalls()
            for existing_fw in existing_firewalls:
                print(f"    Removing existing Firewall ID: {existing_fw.id}")
                try:
                    # Get devices for this firewall and remove this linode
                    for device in existing_fw.devices:
                        if device.entity.id == current_linode.id:
                            device.delete()
                            print(f"      ✓ Removed Linode {current_linode.id} from Firewall {existing_fw.id}")
                except ApiError as e:
                    print(f"      ✗ Error removing firewall: {e}")

            # Attach the Linode instance to the new firewall
            try:
                rule.device_create(id=current_linode.id, type="linode")
                print(f"    ✓ Successfully attached firewall {rule.id} to Linode {current_linode.id}")
            except ApiError as e:
                print(f"    ✗ Error attaching firewall: {e}")
                continue
