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
- Python 3.9+
- API Keys: Himira (WIL_API_KEY) and Google Gemini

### Automated Deployment

```bash
# Run the deployment script
./deploy.sh

# This will:
# 1. Check prerequisites
# 2. Set up environment files
# 3. Deploy all services with Docker
# 4. Initialize vector database
# 5. Configure MCP server
```

### Manual Deployment

```bash
# Start all services
docker-compose -f docker-compose.unified.yml up -d

# Initialize vector database
docker exec himira-etl python -m etl.pipeline --mode full

# Check service health
docker-compose -f docker-compose.unified.yml ps
```

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[ondc-shopping-mcp/README.md](ondc-shopping-mcp/README.md)** - MCP server documentation
- **[himira_vector_db/README.md](himira_vector_db/README.md)** - Vector database documentation

## 🔧 Configuration

### MCP Server Configuration
Edit `ondc-shopping-mcp/.env`:
```
BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
WIL_API_KEY=your-api-key
VECTOR_SEARCH_ENABLED=true
```

### Vector Database Configuration
Edit `himira_vector_db/.env`:
```
HIMIRA_BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
HIMIRA_API_KEY=your-api-key
GEMINI_API_KEY=your-gemini-key
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
- **Logs**: Check `ondc-shopping-mcp/logs/` and `himira_vector_db/logs/`

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