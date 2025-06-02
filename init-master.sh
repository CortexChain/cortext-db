#!/bin/bash
set -e

# Configure PostgreSQL for replication and performance
echo "host replication admin 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host all admin 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
cat <<EOF >> "$PGDATA/postgresql.conf"
wal_level = replica
max_wal_senders = 5
wal_keep_size = 32
hot_standby = on
shared_buffers = 192MB
work_mem = 4MB
maintenance_work_mem = 32MB
effective_cache_size = 512MB
max_connections = 50
checkpoint_timeout = 10min
min_wal_size = 32MB
max_wal_size = 64MB
checkpoint_completion_target = 0.9
wal_compression = on
wal_writer_delay = 10ms
random_page_cost = 2.0
effective_io_concurrency = 100
log_min_messages = debug1
EOF