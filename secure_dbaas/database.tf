resource "linode_database_postgresql_v2" "main" {
  label     = "db-postgresql"
  engine_id = "postgresql/17"
  region    = local.region
  type      = "g6-standard-4"

  cluster_size = 3 # HA Setup with 1 Primary and 2 Replicas

  updates = {
    frequency   = "weekly"
    day_of_week = 7
    duration    = 4
    hour_of_day = 4
  }

  private_network = {
    public_access = true
    vpc_id        = linode_vpc.main.id
    subnet_id     = linode_vpc_subnet.subnet-1.id
  }

  allow_list = [
    # local.private_ips_range,
    linode_vpc_subnet.subnet-2.ipv4,
    local.my_ip_cidr
    # "0.0.0.0/0",
    # "::/0"
  ]

  # settings
  engine_config_pg_stat_monitor_enable = true
}
