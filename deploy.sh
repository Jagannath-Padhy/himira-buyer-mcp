#!/bin/bash

# ONDC Shopping System Deployment Script
# This script automates the deployment of both MCP server and vector database

set -e  # Exit on error

echo "🚀 ONDC Shopping System Deployment Script"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Clone repositories if not present
clone_repos() {
    echo -e "${YELLOW}Setting up repositories...${NC}"
    
    if [ ! -d "himira-vector-db" ]; then
        echo "Cloning vector database repository..."
        git clone git@github.com:Jagannath-Padhy/himira-vector-db.git
    else
        echo "Vector database repository already exists"
    fi
    
    if [ ! -d "himira-mcp" ]; then
        echo "Cloning MCP server repository..."
        git clone git@github.com:Jagannath-Padhy/himira-mcp.git ondc-shopping-mcp
    else
        echo "MCP server repository already exists"
    fi
    
    echo -e "${GREEN}✓ Repositories ready${NC}"
}

# Setup environment files
setup_env() {
    echo -e "${YELLOW}Setting up environment files...${NC}"
    
    # Vector DB env
    if [ ! -f "himira-vector-db/.env" ]; then
        if [ -f "himira-vector-db/.env.example" ]; then
            cp himira-vector-db/.env.example himira-vector-db/.env
            echo -e "${YELLOW}Please edit himira-vector-db/.env with your credentials${NC}"
        fi
    fi
    
    # MCP Server env
    if [ ! -f "ondc-shopping-mcp/.env" ]; then
        if [ -f "ondc-shopping-mcp/.env.example" ]; then
            cp ondc-shopping-mcp/.env.example ondc-shopping-mcp/.env
            echo -e "${YELLOW}Please edit ondc-shopping-mcp/.env with your credentials${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Environment files ready${NC}"
}

# Deploy services
deploy_services() {
    echo -e "${YELLOW}Deploying services...${NC}"
    
    # Create necessary directories
    mkdir -p qdrant_data redis_data logs
    
    # Start services
    docker-compose -f docker-compose.unified.yml up -d
    
    echo -e "${GREEN}✓ Services deployed${NC}"
}

# Wait for services to be healthy
wait_for_services() {
    echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
    
    # Wait for Qdrant
    echo -n "Waiting for Qdrant..."
    until curl -sf http://localhost:6333/health > /dev/null; do
        echo -n "."
        sleep 2
    done
    echo -e " ${GREEN}Ready${NC}"
    
}

# Initialize vector database
init_vector_db() {
    echo -e "${YELLOW}Initializing vector database...${NC}"
    
    read -p "Run initial data ingestion? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running ETL pipeline..."
        docker exec himira-etl python -m etl.pipeline --mode full
        echo -e "${GREEN}✓ Vector database initialized${NC}"
    fi
}

# Display status
show_status() {
    echo -e "\n${YELLOW}System Status:${NC}"
    docker-compose -f docker-compose.unified.yml ps
    
    echo -e "\n${GREEN}Deployment Complete!${NC}"
    echo "=========================="
    echo "🌐 Qdrant Dashboard: http://localhost:6333/dashboard"
    echo ""
    echo "📝 Next Steps:"
    echo "1. Edit environment files if you haven't already"
    echo "2. Check logs: docker-compose -f docker-compose.unified.yml logs -f"
    echo "3. Configure your MCP client to connect to the server"
}

# Main execution
main() {
    check_prerequisites
    clone_repos
    setup_env
    
    # Check if environment files are configured
    if grep -q "your-api-key" himira-vector-db/.env 2>/dev/null || grep -q "your-api-key" ondc-shopping-mcp/.env 2>/dev/null; then
        echo -e "${RED}Please configure your API keys in the .env files before continuing${NC}"
        echo "1. Edit himira-vector-db/.env"
        echo "2. Edit ondc-shopping-mcp/.env"
        exit 1
    fi
    
    deploy_services
    wait_for_services
    init_vector_db
    show_status
}

# Handle script arguments
case "$1" in
    "stop")
        echo "Stopping services..."
        docker-compose -f docker-compose.unified.yml down
        echo -e "${GREEN}Services stopped${NC}"
        ;;
    "restart")
        echo "Restarting services..."
        docker-compose -f docker-compose.unified.yml restart
        echo -e "${GREEN}Services restarted${NC}"
        ;;
    "logs")
        docker-compose -f docker-compose.unified.yml logs -f
        ;;
    "status")
        docker-compose -f docker-compose.unified.yml ps
        ;;
    *)
        main
        ;;
esac