# Create a random password for the VM root user
# Note: This is optional if using SSH keys for authentication
# Create a Linode instance (VM) within the specified VPC subnet
resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "linode_instance" "public" {
  label  = "public"
  image  = var.vm_image
  region = var.vpc_region
  type   = var.vm_size

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]
  root_pass = random_password.vm_password.result

  # Configure NAT gateway and disable SSH password authentication
  metadata {
    user_data = base64encode(file("scripts/nat_gateway_user_data.yaml"))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.public.id
    ipv4 {
      # vpc = "10.10.1.100"
      nat_1_1 = "any"
    }
  }

  # VLAN interface with fixed IP for routing
  interface {
    purpose      = "vlan"
    label        = "nat-vlan"
    ipam_address = "192.168.100.1/24"
  }

  tags = ["demo", "ssh-access"]
}

resource "linode_instance" "private" {
  label  = "private"
  image  = var.vm_image
  region = var.vpc_region
  type   = var.vm_size

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]
  root_pass = random_password.vm_password.result

  # Configure routing through NAT gateway and disable SSH password auth
  metadata {
    user_data = base64encode(file("scripts/nat_routing_user_data.yaml"))
  }

  # VLAN interface with fixed IP for routing
  interface {
    purpose      = "vlan"
    label        = "nat-vlan"
    ipam_address = "192.168.100.2/24"
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.private.id
    ipv4 {}
  }

  tags = ["demo", "ssh-internal-access"]
}
