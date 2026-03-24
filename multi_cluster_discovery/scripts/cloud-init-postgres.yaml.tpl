#cloud-config
package_update: true
package_upgrade: false

packages:
  - postgresql
  - postgresql-client

write_files:
  - path: /usr/local/bin/bootstrap-postgres.sh
    owner: root:root
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      LOG_FILE="/var/log/postgres-bootstrap.log"
      exec > >(tee -a "$LOG_FILE") 2>&1

      echo "[bootstrap] Starting PostgreSQL bootstrap"

      PG_VERSION="$(ls /etc/postgresql | sort -V | tail -n1)"
      PG_CONF="/etc/postgresql/$${PG_VERSION}/main/postgresql.conf"
      PG_HBA="/etc/postgresql/$${PG_VERSION}/main/pg_hba.conf"

      install -d -m 0700 -o postgres -g postgres /var/lib/postgresql

      printf '%s' '${postgres_server_key_b64}' | base64 -d > /var/lib/postgresql/postgresql-server.key
      printf '%s' '${postgres_server_cert_b64}' | base64 -d > /var/lib/postgresql/postgresql-server.crt
      printf '%s' '${postgres_ca_cert_b64}' | base64 -d > /var/lib/postgresql/postgresql-ca.crt

      chown postgres:postgres /var/lib/postgresql/postgresql-server.key /var/lib/postgresql/postgresql-server.crt /var/lib/postgresql/postgresql-ca.crt
      chmod 0600 /var/lib/postgresql/postgresql-server.key
      chmod 0644 /var/lib/postgresql/postgresql-server.crt /var/lib/postgresql/postgresql-ca.crt

      cp "$PG_CONF" "$PG_CONF.bak"

      sed -i "s/^#\?listen_addresses\s*=.*/listen_addresses = '*'/" "$PG_CONF"
      if grep -q '^#\?ssl\s*=' "$PG_CONF"; then
        sed -i "s/^#\?ssl\s*=.*/ssl = on/" "$PG_CONF"
      else
        echo "ssl = on" >> "$PG_CONF"
      fi

      if grep -q '^#\?ssl_cert_file\s*=' "$PG_CONF"; then
        sed -i "s|^#\?ssl_cert_file\s*=.*|ssl_cert_file = '/var/lib/postgresql/postgresql-server.crt'|" "$PG_CONF"
      else
        echo "ssl_cert_file = '/var/lib/postgresql/postgresql-server.crt'" >> "$PG_CONF"
      fi

      if grep -q '^#\?ssl_key_file\s*=' "$PG_CONF"; then
        sed -i "s|^#\?ssl_key_file\s*=.*|ssl_key_file = '/var/lib/postgresql/postgresql-server.key'|" "$PG_CONF"
      else
        echo "ssl_key_file = '/var/lib/postgresql/postgresql-server.key'" >> "$PG_CONF"
      fi

      if grep -q '^#\?ssl_ca_file\s*=' "$PG_CONF"; then
        sed -i "s|^#\?ssl_ca_file\s*=.*|ssl_ca_file = '/var/lib/postgresql/postgresql-ca.crt'|" "$PG_CONF"
      else
        echo "ssl_ca_file = '/var/lib/postgresql/postgresql-ca.crt'" >> "$PG_CONF"
      fi

      if grep -q '^#\?port\s*=' "$PG_CONF"; then
        sed -i "s/^#\?port\s*=.*/port = ${postgres_port}/" "$PG_CONF"
      else
        echo "port = ${postgres_port}" >> "$PG_CONF"
      fi

      if ! grep -q "hostssl all all 0.0.0.0/0 scram-sha-256" "$PG_HBA"; then
        echo "hostssl all all 0.0.0.0/0 scram-sha-256" >> "$PG_HBA"
      fi

      systemctl enable postgresql
      systemctl restart postgresql

      for _ in $(seq 1 20); do
        if systemctl is-active --quiet postgresql; then
          break
        fi
        sleep 2
      done

      if ! systemctl is-active --quiet postgresql; then
        echo "[bootstrap] PostgreSQL failed to start"
        journalctl -u postgresql --no-pager -n 50 || true
        exit 1
      fi

      sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname = '${postgres_user}'" | grep -q 1 || sudo -u postgres psql -c "CREATE ROLE ${postgres_user} WITH LOGIN PASSWORD '${postgres_password}';"
      sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '${postgres_db_name}'" | grep -q 1 || sudo -u postgres createdb -O "${postgres_user}" "${postgres_db_name}"
      sudo -u postgres psql -d "${postgres_db_name}" -c "CREATE TABLE IF NOT EXISTS demo_messages (id serial PRIMARY KEY, message text NOT NULL);"
      sudo -u postgres psql -d "${postgres_db_name}" -c "SELECT 1 FROM demo_messages WHERE message = 'hello from postgres vm over skupper'" | grep -q 1 || sudo -u postgres psql -d "${postgres_db_name}" -c "INSERT INTO demo_messages(message) VALUES ('hello from postgres vm over skupper');"

      echo "[bootstrap] PostgreSQL SSL setup complete"
      echo "PostgreSQL SSL setup complete" > /root/postgresql-setup.status

runcmd:
  - [bash, -lc, "/usr/local/bin/bootstrap-postgres.sh"]
