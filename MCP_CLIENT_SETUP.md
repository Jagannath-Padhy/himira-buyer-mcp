# MCP Client Setup for ONDC Shopping MCP

## Quick Setup

1. **Start the system**:
   ```bash
   docker-compose -f docker-compose.unified.yml up -d
   ```

2. **Update your MCP client config**:
   Example for Claude Desktop, edit `/Users/jagannath/Library/Application Support/Claude/claude_desktop_config.json`:
   
   ```json
   {
     "mcpServers": {
       "ondc-shopping": {
         "command": "docker",
         "args": ["exec", "-i", "ondc-mcp-server", "python", "run_mcp_server.py"],
         "env": {
           "VECTOR_SEARCH_ENABLED": "true",
           "QDRANT_HOST": "qdrant",
           "QDRANT_PORT": "6333",
           "QDRANT_COLLECTION": "ondc_products", 
           "VECTOR_SIMILARITY_THRESHOLD": "0.3",
           "LOG_LEVEL": "INFO"
         }
       }
     }
   }
   ```

3. **Restart your MCP client** completely

4. **Test with your AI assistant**: 
   - "search for laptops"
   - "find me some snacks"
   - "what categories are available?"

## Why This Approach?

The MCP server runs inside a Docker container where it has:
- ✅ All Python dependencies installed
- ✅ Access to vector database at `qdrant:6333`
- ✅ Proper environment variables
- ✅ 172+ products loaded and ready

The MCP client connects via `docker exec -i` to the running container, bridging the host system to the containerized MCP server.

## Verification

Check system status:
```bash
# Verify containers are running
docker-compose -f docker-compose.unified.yml ps

# Check product count
curl -s http://localhost:6333/collections/ondc_products | jq '.result.points_count'

# Test docker exec connection
timeout 3 docker exec -i ondc-mcp-server python run_mcp_server.py < /dev/null
```

Should show:
- All containers healthy
- 172+ products in database  
- MCP server starts and initializes successfully

## Available Tools

Once connected, your AI assistant will have access to:
- **search_products**: Find products by name, category, or description
- **get_categories**: List all available product categories
- **add_to_cart**: Add items to shopping cart
- **view_cart**: See current cart contents
- **checkout**: Complete purchase flow
- **get_session_info**: View current session details

## Troubleshooting

If your MCP client shows "Extension ondc-shopping not found":
1. Ensure all containers are running: `docker-compose -f docker-compose.unified.yml ps`
2. Restart your MCP client completely
3. Check container logs: `docker logs ondc-mcp-server`
4. Verify config file syntax is valid JSON