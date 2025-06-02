#!/bin/bash
set -e

# Enable debug logging
echo "Starting slave initialization..."

# Wait for master to be ready
echo "Checking if master is ready..."
until pg_isready -h localhost -p 5432 -U admin; do
  echo "Waiting for admin..."
  sleep 1
done

# Clear existing data directory
echo "Clearing existing data directory..."
rm -rf /var/lib/postgresql/data/*

# Perform base backup from master
echo "Running pg_basebackup..."
PGPASSWORD=12345a@A pg_basebackup -h localhost -D /var/lib/postgresql/data -U admin -P

# Fix ownership of data directory
echo "Fixing data directory ownership..."
chown -R postgres:postgres /var/lib/postgresql/data
chmod -R 700 /var/lib/postgresql/data

# Configure standby mode
echo "Configuring standby mode..."
touch /var/lib/postgresql/data/standby.signal
chown postgres:postgres /var/lib/postgresql/data/standby.signal
chmod 600 /var/lib/postgresql/data/standby.signal

# Configure recovery settings in postgresql.conf
echo "Configuring postgresql.conf for standby..."
cat <<EOF >> "$PGDATA/postgresql.conf"
hot_standby = on
shared_buffers = 256MB
work_mem = 4MB
maintenance_work_mem = 64MB
effective_cache_size = 768MB
max_connections = 100
random_page_cost = 4.0
effective_io_concurrency = 2
hot_standby_feedback = on
min_wal_size = 80MB
max_wal_size = 1GB
primary_conninfo = 'host=localhost port=5432 user=admin password=postgres application_name=admin'
log_min_messages = on
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_min_error_statement = debug1
EOF

# Verify data directory
echo "Verifying data directory..."
ls -l /var/lib/postgresql/data/

# Ensure configuration is complete before proceeding
echo "Syncing filesystem..."
sync

# Check if PostgreSQL can start
echo "Attempting to start PostgreSQL in standby mode..."
su - postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/data/logfile start -w -t 30" || {
  echo "Failed to start PostgreSQL server."
  cat /var/lib/postgresql/data/log/*.log
  exit 1
}

# Verify server status
if [ -f "/var/lib/postgresql/data/postmaster.pid" ]; then
  echo "PostgreSQL slave started successfully."
else
  echo "PostgreSQL slave failed to start."
  cat /var/lib/postgresql/data/log/*.log
  exit 1
fi

echo "Slave initialization complete."