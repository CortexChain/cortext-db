# PostgreSQL Master-Slave Cluster với Nginx Load Balancer

Hệ thống PostgreSQL Master-Slave cluster với Nginx proxy để phân tải read/write operations.

## 📋 Tổng quan

- **PostgreSQL 16**: Master-Slave replication
- **Nginx**: Load balancer & proxy
- **Docker Compose**: Container orchestration
- **Database**: `contextdb`
- **User**: `admin` / Password: `12345a@A`

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Monitoring    │
│                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          │ :5434 (Write)        │ :8080 (Stats)
          │ :5435 (Read)         │
          │                      │
┌─────────▼──────────────────────▼───────┐
│            Nginx Proxy                 │
│     (Load Balancer & Monitoring)       │
└─────────┬─────────────────┬────────────┘
          │                 │
          │ :5432          │ :5432
          │                 │
┌─────────▼───────┐ ┌───────▼────────┐
│ PostgreSQL      │ │ PostgreSQL     │
│ Master          │ │ Slave          │
│ (Write)         │ │ (Read Only)    │
└─────────────────┘ └────────────────┘
```

## 🚀 Quick Start

### 1. Clone và Setup

```bash
# Clone repository
git clone <your-repo>
cd postgres-cluster

# Cấp quyền execute cho scripts
chmod +x init-master.sh init-slave.sh test-nginx-proxy.sh
```

### 2. Khởi động hệ thống

```bash
# Test Nginx config
docker run --rm -v $(pwd)/nginx-proxy.conf:/etc/nginx/nginx.conf:ro nginx:1.24 nginx -t

# Khởi động cluster
docker-compose up -d

# Kiểm tra status
docker-compose ps
```

### 3. Verify Setup

```bash
# Chạy test script
./test-nginx-proxy.sh

# Hoặc test manual
PGPASSWORD="12345a@A" psql -h localhost -p 5434 -U admin -d contextdb -c "SELECT 'Write OK';"
PGPASSWORD="12345a@A" psql -h localhost -p 5435 -U admin -d contextdb -c "SELECT 'Read OK';"
```

## 🔌 Endpoints

| Service | Endpoint | Mô tả |
|---------|----------|-------|
| **Write Operations** | `localhost:5434` | Ghi dữ liệu (Master) |
| **Read Operations** | `localhost:5435` | Đọc dữ liệu (Slave) |
| **Direct Master** | `localhost:5432` | Truy cập trực tiếp Master |
| **Nginx Stats** | `http://localhost:8080/status` | Monitoring Nginx |
| **Health Check** | `http://localhost:8080/health` | Health status |
| **Info Page** | `http://localhost:8080/` | Thông tin tổng quan |

## 📁 Cấu trúc project

```
postgres-cluster/
├── docker-compose.yml          # Container orchestration
├── nginx-proxy.conf            # Nginx load balancer config
├── init-master.sh             # Script khởi tạo Master
├── init-slave.sh              # Script khởi tạo Slave
├── test-nginx-proxy.sh        # Script test hệ thống
├── haproxy.cfg               # HAProxy config (backup)
└── README.md                 # Documentation này
```

## ⚙️ Configuration

### Database Connection

```bash
# Write operations (thông qua Nginx)
PGPASSWORD="12345a@A" psql -h localhost -p 5434 -U admin -d contextdb

# Read operations (thông qua Nginx)
PGPASSWORD="12345a@A" psql -h localhost -p 5435 -U admin -d contextdb

# Direct master connection
PGPASSWORD="12345a@A" psql -h localhost -p 5432 -U admin -d contextdb
```

### Application Connection Strings

```javascript
// Node.js example
const writePool = new Pool({
  host: 'localhost',
  port: 5434,
  database: 'contextdb',
  user: 'admin',
  password: '12345a@A'
});

const readPool = new Pool({
  host: 'localhost', 
  port: 5435,
  database: 'contextdb',
  user: 'admin',
  password: '12345a@A'
});
```

```python
# Python example
WRITE_DB = {
    'host': 'localhost',
    'port': 5434,
    'database': 'contextdb',
    'user': 'admin',
    'password': '12345a@A'
}

READ_DB = {
    'host': 'localhost',
    'port': 5435, 
    'database': 'contextdb',
    'user': 'admin',
    'password': '12345a@A'
}
```

### Environment Variables

```bash
# Database credentials
POSTGRES_USER=admin
POSTGRES_PASSWORD=12345a@A
POSTGRES_DB=contextdb

# Connection endpoints
DB_WRITE_HOST=localhost
DB_WRITE_PORT=5434
DB_READ_HOST=localhost
DB_READ_PORT=5435
```

## 🔧 Quản lý hệ thống

### Khởi động/Dừng services

```bash
# Khởi động tất cả
docker-compose up -d

# Khởi động từng service
docker-compose up -d postgres-master
docker-compose up -d postgres-slave
docker-compose up -d nginx-proxy

# Dừng hệ thống
docker-compose down

# Dừng và xóa volumes (⚠️ Mất dữ liệu)
docker-compose down -v
```

### Monitoring & Logs

```bash
# Xem logs
docker-compose logs -f postgres-master
docker-compose logs -f postgres-slave
docker-compose logs -f nginx-proxy

# Kiểm tra resource usage
docker stats postgres-master postgres-slave nginx-proxy

# Nginx status
curl http://localhost:8080/status

# Health check
curl http://localhost:8080/health
```

### Backup & Restore

```bash
# Backup database
docker exec postgres-master pg_dump -U admin contextdb > backup.sql

# Restore database
docker exec -i postgres-master psql -U admin contextdb < backup.sql

# Backup với Docker volume
docker run --rm \
  -v postgres-cluster_postgres-master-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/postgres-backup.tar.gz /data
```

## 🛠️ Troubleshooting

### Kiểm tra trạng thái replication

```sql
-- Trên Master: Kiểm tra replication status
SELECT * FROM pg_stat_replication;

-- Trên Slave: Kiểm tra lag
SELECT 
    CASE 
        WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() THEN 0
        ELSE EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())
    END AS lag_seconds;
```

### Các lỗi thường gặp

#### 1. Connection refused
```bash
# Kiểm tra containers đang chạy
docker-compose ps

# Kiểm tra network
docker network ls
docker network inspect postgres-cluster_pg-network
```

#### 2. Replication không hoạt động
```bash
# Restart slave
docker-compose restart postgres-slave

# Kiểm tra logs
docker-compose logs postgres-slave
```

#### 3. Nginx proxy lỗi
```bash
# Test config
docker run --rm -v $(pwd)/nginx-proxy.conf:/etc/nginx/nginx.conf:ro nginx:1.24 nginx -t

# Restart nginx
docker-compose restart nginx-proxy
```

### Performance Tuning

```bash
# Kiểm tra connection pool
docker exec postgres-master psql -U admin -d contextdb -c "
SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';
"

# Kiểm tra slow queries
docker exec postgres-master psql -U admin -d contextdb -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 10;
"
```

## 📊 Monitoring

### Nginx Metrics

```bash
# Basic stats
curl http://localhost:8080/status

# Custom metrics endpoint
curl http://localhost:8080/metrics
```

### Database Metrics

```sql
-- Connection stats
SELECT * FROM pg_stat_database WHERE datname = 'contextdb';

-- Table stats
SELECT * FROM pg_stat_user_tables;

-- Replication lag
SELECT * FROM pg_stat_replication;
```

## 🔒 Security Notes

- Đổi password mặc định trong production
- Sử dụng SSL/TLS cho connections
- Cấu hình firewall cho ports
- Regular backup và testing restore
- Monitor logs for suspicious activities

## 📈 Scaling

### Thêm Read Replicas

1. Tạo thêm slave containers trong docker-compose.yml
2. Update nginx upstream config
3. Test load balancing

### Horizontal Scaling

- Sử dụng PostgreSQL built-in partitioning
- Implement sharding strategy
- Consider using connection poolers (PgBouncer)

## 🆘 Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `docker-compose logs [service-name]`
2. Run test script: `./test-nginx-proxy.sh`
3. Verify network connectivity
4. Check resource usage: `docker stats`

---

**Created by**: Lucas Aleh
**Last Updated**: 3/6/2025  
**Version**
