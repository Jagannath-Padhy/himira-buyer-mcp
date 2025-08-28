# ONDC MCP System - Fresh System Setup Guide

Complete step-by-step guide for setting up the ONDC Shopping MCP system on a new machine from scratch.

## 🎯 What You'll Have After Setup

- **Conversational Commerce**: Chat with Claude to search and buy products
- **Semantic Search**: Find products using natural language queries  
- **Vector Database**: 86+ products with AI-powered similarity search
- **Complete ONDC Integration**: Real shopping capabilities via Himira backend

---

## 📋 Prerequisites

### System Requirements
- **OS**: Linux, macOS, or Windows with WSL2
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: 5GB free space
- **Network**: Internet connection for API calls

### Required Software

#### 1. Install Git
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install git

# macOS (if not already installed)
# Git comes with Xcode Command Line Tools
xcode-select --install

# Verify installation
git --version
```

#### 2. Install Docker & Docker Compose
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# macOS - Use Docker Desktop
# Download from: https://docs.docker.com/docker-for-mac/install/

# Log out and back in, then verify
docker --version
docker-compose --version
```

#### 3. Install Python 3.9+ (Optional - for local development)
```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip

# macOS
brew install python

# Verify
python3 --version
```

---

## 🚀 Installation Steps

### Step 1: Create Project Directory
```bash
# Create main project directory
mkdir ondc-shopping-system
cd ondc-shopping-system
```

### Step 2: Clone the Repository
```bash
# Clone the unified repository
git clone git@github.com:Jagannath-Padhy/himira-buyer-mcp.git .

# Or using HTTPS if SSH not configured
git clone https://github.com/Jagannath-Padhy/himira-buyer-mcp.git .

# Verify structure
ls -la
# You should see: ondc-shopping-mcp/, himira_vector_db/, docker-compose.unified.yml, etc.
```

### Step 3: Configure API Keys

You'll need these API keys:
- **Himira API Key**: Contact Himira team or use: `aPzSpx0rksO96PhGGNKRgfAay0vUbZ`
- **Google Gemini API Key**: Get from [Google AI Studio](https://makersuite.google.com/app/apikey)

#### 3a. Configure MCP Server Environment
```bash
# Create MCP server environment file
cp ondc-shopping-mcp/.env.example ondc-shopping-mcp/.env

# Edit the environment file
nano ondc-shopping-mcp/.env
```

Add these values:
```env
BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
WIL_API_KEY=aPzSpx0rksO96PhGGNKRgfAay0vUbZ
VECTOR_SEARCH_ENABLED=true
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=ondc_products
VECTOR_SIMILARITY_THRESHOLD=0.3
GEMINI_API_KEY=your_gemini_api_key_here
SESSION_TIMEOUT_MINUTES=30
SESSION_STORE=file
SESSION_STORE_PATH=~/.ondc-mcp/sessions
```

#### 3b. Configure Vector Database Environment
```bash
# Create vector database environment file
cp himira_vector_db/.env.example himira_vector_db/.env

# Edit the environment file
nano himira_vector_db/.env
```

Add these key values (the file has many settings, focus on these):
```env
# Core API Configuration
HIMIRA_BACKEND_URL=https://hp-buyer-backend-preprod.himira.co.in/clientApis
HIMIRA_API_KEY=aPzSpx0rksO96PhGGNKRgfAay0vUbZ
HIMIRA_USER_ID=guestUser
HIMIRA_DEVICE_ID=etl_pipeline_001

# Vector Database Configuration
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_PRODUCTS_COLLECTION=ondc_products

# AI/ML Configuration
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=models/text-embedding-004
EMBEDDING_DIMENSION=768
```

### Step 4: Deploy the System
```bash
# Make sure you're in the project root directory
cd ondc-shopping-system

# Start all services
docker-compose -f docker-compose.unified.yml up -d

# Check if services are starting
docker-compose -f docker-compose.unified.yml ps
```

### Step 5: Wait for Services to Initialize
```bash
# Monitor the startup process
docker-compose -f docker-compose.unified.yml logs -f

# In another terminal, wait for Qdrant to be healthy
while ! curl -sf http://localhost:6333/health > /dev/null; do
    echo "Waiting for Qdrant to be ready..."
    sleep 5
done
echo "✅ Qdrant is ready!"
```

### Step 6: Initialize Vector Database

#### Option A: Automatic ETL (Recommended)
The ETL container will automatically run every 2 hours, but for immediate setup:

```bash
# Run manual ETL to populate the database immediately
docker exec himira-etl python -m etl.pipeline --action full --data-types products

# Check if products were loaded
curl -s http://localhost:6333/collections/ondc_products | jq '.result.points_count'
# Should show: 86 (or similar number)
```

#### Option B: Manual ETL Script
```bash
# Alternative: Run the ETL script we created
docker exec himira-etl /app/run_etl.sh
```

---

## 🧪 Verify Installation

### Test 1: Check Service Status
```bash
docker-compose -f docker-compose.unified.yml ps

# All services should be "Up" or "Up (healthy)"
# himira-qdrant    Up (healthy)
# himira-etl       Up  
# ondc-mcp-server  Up
```

### Test 2: Test Vector Database
```bash
# Check Qdrant is running
curl http://localhost:6333/health

# Check products collection exists
curl http://localhost:6333/collections/ondc_products

# Should show collection with 86+ points
```

### Test 3: Test MCP Server
```bash
# Check MCP server logs for successful initialization
docker logs ondc-mcp-server --tail 20

# Look for:
# "Vector search auto-initialized: True (threshold: 0.3)"
# "MCP Server initialized successfully"
# "Vector search: Enabled"
```

### Test 4: Run System Test Script
```bash
# Copy and run our test script
python3 test_system.py

# Should show:
# ✅ All systems operational!
```

---

## 🔧 Configure Claude Desktop

### Step 1: Update Claude Desktop Configuration

**For macOS:**
```bash
# Open Claude Desktop config
nano ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

**For Windows:**
```bash
# Open config at:
# %APPDATA%\Claude\claude_desktop_config.json
```

**For Linux:**
```bash
# Open config at:
nano ~/.config/Claude/claude_desktop_config.json
```

### Step 2: Add MCP Server Configuration
```json
{
  "mcpServers": {
    "ondc-shopping": {
      "command": "docker",
      "args": ["exec", "-i", "ondc-mcp-server", "python", "run_mcp_server.py"],
      "env": {
        "VECTOR_SEARCH_ENABLED": "true",
        "QDRANT_HOST": "qdrant",
        "VECTOR_SIMILARITY_THRESHOLD": "0.3"
      }
    }
  }
}
```

### Step 3: Restart Claude Desktop

Completely restart Claude Desktop application to pick up the new configuration.

---

## 🎉 Test Your Installation

### Test in Claude Desktop

Try these commands in Claude:
```
1. Search for products:
   "search for laptop"
   "find me some productive gadgets"
   "show me available electronics"

2. Browse categories:
   "what categories are available?"

3. Advanced search:
   "find laptops under ₹25000"
```

### Expected Results
- **Vector Search First**: System tries semantic search with 0.3 threshold
- **API Fallback**: If no vector results, falls back to Himira API
- **Rich Results**: Product details with prices, descriptions, and availability
- **Session Persistence**: Your shopping session is maintained

---

## 🔄 Daily Operations

### Starting the System
```bash
cd ondc-shopping-system
docker-compose -f docker-compose.unified.yml up -d
```

### Stopping the System
```bash
docker-compose -f docker-compose.unified.yml down
```

### Viewing Logs
```bash
# All services
docker-compose -f docker-compose.unified.yml logs -f

# Specific service
docker logs ondc-mcp-server -f
docker logs himira-etl -f
docker logs himira-qdrant -f
```

### Updating Product Catalog
```bash
# Manual ETL run
docker exec himira-etl python -m etl.pipeline --action full
```

### Monitoring
- **Qdrant Dashboard**: http://localhost:6333/dashboard
- **Collection Status**: `curl http://localhost:6333/collections/ondc_products`

---

## 🆘 Troubleshooting

### Issue: "container himira-qdrant is unhealthy" 
```bash
# This is a common health check issue. Quick fixes:

# 1. Debug the health check
./debug_health_check.sh

# 2. Restart just Qdrant
docker restart himira-qdrant

# 3. Wait and restart all services
docker-compose -f docker-compose.unified.yml restart

# 4. Check if Qdrant is actually working
curl http://localhost:6333/  # Should return Qdrant version info
```

### Issue: Services Won't Start
```bash
# Check Docker is running
docker ps

# Check system resources
docker system df
docker system prune  # If needed

# Restart Docker service
sudo systemctl restart docker  # Linux
# Or restart Docker Desktop on macOS/Windows
```

### Issue: Vector Search Not Working
```bash
# Check Qdrant health
curl http://localhost:6333/health

# Check if collection has products
curl http://localhost:6333/collections/ondc_products

# Check MCP server logs for vector search initialization
docker logs ondc-mcp-server | grep "vector"
```

### Issue: No Products Found
```bash
# Run ETL manually
docker exec himira-etl python -m etl.pipeline --action full

# Check API connectivity
docker exec himira-etl python -c "
import requests
r = requests.get('https://hp-buyer-backend-preprod.himira.co.in/clientApis/v2/search/guestUser', 
                 headers={'x-api-key': 'aPzSpx0rksO96PhGGNKRgfAay0vUbZ'},
                 params={'name': 'laptop', 'page': 1, 'limit': 5, 'deviceId': 'test'})
print(f'Status: {r.status_code}')
print(f'Products: {len(r.json().get(\"data\", []))}')
"
```

### Issue: Claude Desktop Not Connecting
1. Verify JSON syntax in `claude_desktop_config.json`
2. Ensure MCP server container is running: `docker ps | grep mcp`
3. Check MCP server logs: `docker logs ondc-mcp-server`
4. Restart Claude Desktop completely

---

## 🎯 Success Criteria

You've successfully set up the system when:

1. ✅ All 3 Docker containers are running
2. ✅ Qdrant has 86+ products loaded
3. ✅ Vector search is enabled with threshold 0.3
4. ✅ Claude Desktop connects to MCP server
5. ✅ You can search for and find products in Claude
6. ✅ Session persistence works across conversations

---

## 📞 Support & Resources

- **Repository**: https://github.com/Jagannath-Padhy/himira-buyer-mcp
- **Vector Database**: Uses Qdrant v1.7.0 with Gemini embeddings
- **MCP Protocol**: Integrates with Claude Desktop via Model Context Protocol
- **ONDC Backend**: Powered by Himira's infrastructure

---

**🎊 Congratulations!** 

You now have a fully functional ONDC Shopping MCP system with AI-powered product search and conversational commerce capabilities!