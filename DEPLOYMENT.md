# ONDC Shopping System Deployment Guide

This guide covers deploying the complete ONDC shopping system with MCP server and vector database.

## 🏗️ Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐
│   MCP Server    │────▶│  Vector Search  │
│  (ONDC Tools)   │     │    (Qdrant)     │
└────────┬────────┘     └─────────────────┘
         │                       ▲
         │                       │
         ▼                       │
┌─────────────────┐     ┌────────┴────────┐
│  Himira Backend │     │   ETL Pipeline  │
│      API        │────▶│  (Scheduled)    │
└─────────────────┘     └─────────────────┘
```

## 🚀 Quick Deployment

### 1. Clone Both Repositories

```bash
# Create project directory
mkdir ondc-shopping-system && cd ondc-shopping-system

# Clone repositories
git clone git@github.com:Jagannath-Padhy/himira-vector-db.git
git clone git@github.com:Jagannath-Padhy/himira-mcp.git
```

### 2. Set Up Environment Variables

```bash
# Vector DB configuration
cp himira-vector-db/.env.example himira-vector-db/.env
# Edit himira-vector-db/.env with your credentials

# MCP Server configuration  
cp himira-mcp/.env.example himira-mcp/.env
# Edit himira-mcp/.env with your credentials
```

### 3. Deploy with Docker Compose

```bash
# From the parent directory containing both projects
docker-compose -f docker-compose.unified.yml up -d

# Check service status
docker-compose -f docker-compose.unified.yml ps

# View logs
docker-compose -f docker-compose.unified.yml logs -f
```

### 4. Initialize Vector Database

```bash
# Run initial data ingestion
docker exec himira-etl python -m etl.pipeline --mode full

# Verify data loaded
curl http://localhost:6333/collections/ondc_products
```

## 📦 Individual Service Deployment

### Vector Database Only

```bash
cd himira-vector-db
docker-compose -f docker/docker-compose.yml up -d
```

### MCP Server Only

```bash
cd himira-mcp
docker-compose up -d
```

## 🔧 Configuration Details

### Required Environment Variables

#### Vector Database (.env)
```
HIMIRA_BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
HIMIRA_API_KEY=your-api-key
GEMINI_API_KEY=your-gemini-key
```

#### MCP Server (.env)
```
BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
WIL_API_KEY=your-api-key
VECTOR_SEARCH_ENABLED=true
QDRANT_HOST=localhost
QDRANT_PORT=6333
GEMINI_API_KEY=your-gemini-key
```

## 🔍 Monitoring & Maintenance

### Health Checks

```bash
# Check Qdrant health
curl http://localhost:6333/health

# Check vector collection
curl http://localhost:6333/collections/ondc_products

# View ETL logs
docker logs himira-etl -f
```

### Access Dashboards

- **Qdrant Dashboard**: http://localhost:6333/dashboard

### Manual ETL Runs

```bash
# Full catalog sync
docker exec himira-etl python -m etl.pipeline --mode full

# Incremental update
docker exec himira-etl python -m etl.pipeline --mode incremental
```

## 🎮 MCP Integration

### Configure Desktop Client

1. Update `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ondc-shopping": {
      "command": "docker",
      "args": ["exec", "-i", "ondc-mcp-server", "python", "run_mcp_server.py"],
      "env": {
        "VECTOR_SEARCH_ENABLED": "true"
      }
    }
  }
}
```

2. Restart your desktop client

### Direct Python Integration

```python
# For local development
cd himira-mcp
python run_mcp_server.py
```

## 🐳 Production Deployment

### Using Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.unified.yml ondc-stack

# Scale services
docker service scale ondc-stack_etl=2
```

### Using Kubernetes

See `k8s/` directory for Kubernetes manifests (coming soon).

## 🔒 Security Considerations

1. **API Keys**: Store securely using Docker secrets or environment management tools
2. **Network**: Use internal Docker networks, expose only necessary ports  
3. **Data**: Regular backups of Qdrant data volume
4. **Updates**: Keep Docker images updated

## 🆘 Troubleshooting

### Vector search not working

```bash
# Check if Qdrant is running
docker ps | grep qdrant

# Test vector search directly
docker exec himira-etl python -c "from etl.vector_search import test_connection; test_connection()"
```

### ETL pipeline failures

```bash
# Check ETL logs
docker logs himira-etl --tail 100

# Run manual test
docker exec himira-etl python scripts/test_extraction.py
```

### MCP server issues

```bash
# Check MCP logs
docker logs ondc-mcp-server --tail 100

# Restart MCP server
docker-compose -f docker-compose.unified.yml restart mcp-server
```

## 🔄 Backup & Recovery

### Backup Qdrant Data

```bash
# Create backup
docker run --rm -v ondc-shopping-system_qdrant_data:/data -v $(pwd):/backup alpine tar czf /backup/qdrant-backup.tar.gz -C /data .

# Restore backup  
docker run --rm -v ondc-shopping-system_qdrant_data:/data -v $(pwd):/backup alpine tar xzf /backup/qdrant-backup.tar.gz -C /data
```

## 📚 Additional Resources

- [Vector Database Documentation](https://github.com/Jagannath-Padhy/himira-vector-db)
- [MCP Server Documentation](https://github.com/Jagannath-Padhy/himira-mcp)
- [ONDC Protocol Specification](https://docs.ondc.org/)