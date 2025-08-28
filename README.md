# ONDC Shopping System with MCP Server & Vector Search

A complete ONDC (Open Network for Digital Commerce) shopping system featuring an MCP server for conversational commerce and a vector database for semantic product search.

## 🏗️ System Components

### 1. **ONDC Shopping MCP Server** (`ondc-shopping-mcp/`)
- Model Context Protocol server for Claude Desktop integration
- Conversational shopping interface with ONDC APIs
- Session management and cart operations
- Vector-first search with API fallback

### 2. **Himira Vector Database** (`himira_vector_db/`)
- ETL pipeline for product catalog ingestion
- Qdrant vector database with Google Gemini embeddings
- Semantic search capabilities for better product discovery
- Scheduled synchronization with Himira backend

### 3. **Buyer Backend Client** (`biap-client-node-js/`)
- Node.js implementation of ONDC buyer app
- Backend APIs for order management
- Integration with Himira's ONDC infrastructure

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Python 3.9+ (optional)
- API Keys: Himira (WIL_API_KEY) and Google Gemini

### 🎯 One-Command Installation (Recommended)

```bash
# Clone and run automated installer
git clone https://github.com/Jagannath-Padhy/himira-buyer-mcp.git
cd himira-buyer-mcp
./install.sh

# The installer will:
# 1. Check system prerequisites
# 2. Set up API keys interactively
# 3. Deploy all services with Docker
# 4. Initialize vector database with products
# 5. Generate Claude Desktop configuration
# 6. Validate system functionality
```

### ⚡ Quick Manual Setup

```bash
# 1. Clone with submodules
git clone --recurse-submodules git@github.com:Jagannath-Padhy/himira-buyer-mcp.git
cd himira-buyer-mcp

# 2. Configure environment (single .env file!)
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY (Himira API key included)

# 3. Start all services
docker-compose -f docker-compose.unified.yml up -d

# 4. Vector database populates automatically!
# Wait ~2 minutes for ETL to complete, then test:
python test_system.py
```

### 🔍 System Validation

```bash
# Quick health check
python test_system.py

# Comprehensive validation
python validate_system.py
```

## 📚 Documentation

- **[FRESH_SYSTEM_SETUP.md](FRESH_SYSTEM_SETUP.md)** - Complete fresh system setup guide  
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment reference guide
- **[ondc-shopping-mcp/README.md](ondc-shopping-mcp/README.md)** - MCP server documentation
- **[himira_vector_db/README.md](himira_vector_db/README.md)** - Vector database documentation

## 🔧 Configuration

### Single Configuration File
Edit `.env` in the root directory:
```
# Only GEMINI_API_KEY needs to be added - everything else has defaults
HIMIRA_API_KEY=aPzSpx0rksO96PhGGNKRgfAay0vUbZ  # Pre-configured
WIL_API_KEY=aPzSpx0rksO96PhGGNKRgfAay0vUbZ      # Pre-configured
GEMINI_API_KEY=your_gemini_api_key_here          # ADD THIS

# Backend endpoints (pre-configured)
BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
HIMIRA_BACKEND_URL=https://hp-buyer-backend-preprod.himira.co.in/clientApis

# Vector search (pre-configured)
VECTOR_SEARCH_ENABLED=true
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_COLLECTION=ondc_products
VECTOR_SIMILARITY_THRESHOLD=0.3
```

## 🌐 Architecture

```
┌─────────────────┐     ┌─────────────────┐
│ Claude Desktop  │────▶│   MCP Server    │
│  (User Chat)    │     │  (Tools & AI)   │
└─────────────────┘     └────────┬────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
         ┌─────────────────┐       ┌─────────────────┐
         │  Vector Search  │       │  Himira Backend │
         │    (Qdrant)     │       │   (ONDC APIs)   │
         └─────────────────┘       └─────────────────┘
                    ▲                         │
                    │                         │
         ┌─────────────────┐                 │
         │  ETL Pipeline   │◀────────────────┘
         │  (Scheduled)    │
         └─────────────────┘
```

## 🛠️ Services

- **Qdrant**: Vector database on port 6333
- **ETL**: Automated product synchronization
- **MCP Server**: Conversational interface

## 🔍 Features

- **Semantic Search**: Find products by meaning, not just keywords
- **Session Persistence**: Shopping sessions maintained across conversations
- **Multi-step Checkout**: Complete order flows with address and payment
- **Real-time Sync**: ETL pipeline keeps catalog updated
- **Hybrid Search**: Vector search with API fallback for best results

## 🐳 Docker Services

```bash
# View logs
docker-compose -f docker-compose.unified.yml logs -f

# Restart services
docker-compose -f docker-compose.unified.yml restart

# Stop all services
docker-compose -f docker-compose.unified.yml down
```

## 📊 Monitoring

- **Qdrant Dashboard**: http://localhost:6333/dashboard
- **System Health**: `python test_system.py`
- **Logs**: `docker-compose -f docker-compose.unified.yml logs -f`

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "container himira-qdrant is unhealthy" | Run `./debug_health_check.sh` or `docker restart himira-qdrant` |
| Services won't start | `docker ps` to check Docker, restart Docker Desktop |
| Vector search not working | Check API keys, restart: `docker-compose restart` |
| No products found | Run ETL: `docker exec himira-etl python -m etl.pipeline --action full` |
| Claude can't connect | Verify MCP config, restart Claude Desktop completely |

### Quick Fixes
```bash
# Restart all services
docker-compose -f docker-compose.unified.yml restart

# Fix Qdrant health check issues
./debug_health_check.sh

# Check service logs
docker logs ondc-mcp-server --tail 50
docker logs himira-qdrant --tail 50

# Clean restart (removes volumes)
docker-compose -f docker-compose.unified.yml down -v
docker-compose -f docker-compose.unified.yml up -d

# Run system validation
python validate_system.py
```

### Health Check Issues
If you see "container himira-qdrant is unhealthy":

1. **Quick fix**: `docker restart himira-qdrant`
2. **Debug**: `./debug_health_check.sh` 
3. **Check endpoint**: Verify `curl http://localhost:6333/` returns HTTP 200
4. **Timing**: Wait 30+ seconds for health check to stabilize

## 🤝 Contributing

1. Fork the repositories
2. Create feature branches
3. Submit pull requests to:
   - [himira-mcp](https://github.com/Jagannath-Padhy/himira-mcp)
   - [himira-vector-db](https://github.com/Jagannath-Padhy/himira-vector-db)

## 📄 License

MIT License - See individual repository LICENSE files

## 🙏 Acknowledgments

- Built on [ONDC Protocol](https://ondc.org)
- Powered by [Himira](https://himira.co.in) infrastructure
- Uses [Anthropic MCP](https://modelcontextprotocol.io) for conversational AI