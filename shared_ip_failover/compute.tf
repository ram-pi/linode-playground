# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa.pub"
  file_permission = "0644"
}

# Generate a random password for root user
resource "random_password" "root_password" {
  length  = 16
  special = true
}

### Linode Instances - host_01 ###
resource "linode_instance" "host_01" {
  label  = "host_01"
  region = local.region
  type   = local.instance_type

  # metadata {
  #   user_data = base64encode(file("./scripts/cloud-init.yaml"))
  # }

  # https://techdocs.akamai.com/cloud-computing/docs/managing-ip-addresses-on-a-compute-instance
  # Enable private IP addressing
  # 192.168.128.0/17 range
  private_ip = false

  tags = local.tags

  firewall_id = linode_firewall.allow-my-ip-and-internal.id
}

# Disable network helper to install lelastic or FRR later
resource "linode_instance_config" "host_01" {
  linode_id = linode_instance.host_01.id
  label     = "host_01-config"

  helpers {
    network = false
  }

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.host_01_boot.id
  }

  # Public networking on eth0
  interface {
    purpose = "public"
  }

  # this will not actually work until netplan is configured to use the vlan interface
  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_01"]
  }

  booted = true
}

# Bootable Disk for host_01
resource "linode_instance_disk" "host_01_boot" {
  label     = "host_01-boot"
  linode_id = linode_instance.host_01.id
  size      = linode_instance.host_01.specs.0.disk

  image = local.image

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  # root password
  root_pass = random_password.root_password.result
}

### Linode Instances - host_02 ###
resource "linode_instance" "host_02" {
  label  = "host_02"
  region = local.region
  type   = local.instance_type

  # metadata {
  #   user_data = base64encode(file("./scripts/cloud-init.yaml"))
  # }

  # https://techdocs.akamai.com/cloud-computing/docs/managing-ip-addresses-on-a-compute-instance
  # Enable private IP addressing
  # 192.168.128.0/17 range
  private_ip = false

  tags = local.tags

  firewall_id = linode_firewall.allow-my-ip-and-internal.id
}

# Disable network helper to install lelastic or FRR later
resource "linode_instance_config" "host_02" {
  linode_id = linode_instance.host_02.id
  label     = "host_02-config"

  helpers {
    network = false
  }

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.host_02_boot.id
  }

  # Public networking on eth0
  interface {
    purpose = "public"
  }

  # this will not actually work until netplan is configured to use the vlan interface
  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_02"]
  }

  booted = true
}

# Bootable Disk for host_02
resource "linode_instance_disk" "host_02_boot" {
  label     = "host_02-boot"
  linode_id = linode_instance.host_02.id
  size      = linode_instance.host_02.specs.0.disk

  image = local.image

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  # root password
  root_pass = random_password.root_password.result
}

### Linode Instances - host_03 - backend service - nginx ###
resource "linode_instance" "host_03" {
  label  = "host_03"
  region = local.region
  type   = local.instance_type
  image  = local.image

  metadata {
    user_data = base64encode(file("./scripts/cloud-init.yaml"))
  }

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  # root password
  root_pass = random_password.root_password.result

  # Public networking on eth0
  interface {
    purpose = "public"
  }


  # https://techdocs.akamai.com/cloud-computing/docs/managing-ip-addresses-on-a-compute-instance
  # Enable private IP addressing
  # 192.168.128.0/17 range
  # private_ip = true
  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_03"]
  }

  tags = local.tags

  firewall_id = linode_firewall.allow-my-ip-and-internal.id
}

### Linode Instances - host_04 - backend service - nginx ###
resource "linode_instance" "host_04" {
  label  = "host_04"
  region = local.region
  type   = local.instance_type
  image  = local.image

  metadata {
    user_data = base64encode(file("./scripts/cloud-init.yaml"))
  }

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  # root password
  root_pass = random_password.root_password.result

  # Public networking on eth0
  interface {
    purpose = "public"
  }

  # https://techdocs.akamai.com/cloud-computing/docs/managing-ip-addresses-on-a-compute-instance
  # Enable private IP addressing
  # 192.168.128.0/17 range
  # private_ip = true
  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_04"]
  }

  tags = local.tags

  firewall_id = linode_firewall.allow-my-ip-and-internal.id
}
