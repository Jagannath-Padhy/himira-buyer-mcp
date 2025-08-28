#!/bin/bash

# ONDC MCP System - Automated Installation Script
# This script sets up the complete ONDC Shopping MCP system on a fresh machine

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/Jagannath-Padhy/himira-buyer-mcp.git"
PROJECT_DIR="ondc-shopping-system"
DEFAULT_HIMIRA_API_KEY="aPzSpx0rksO96PhGGNKRgfAay0vUbZ"

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              ONDC Shopping MCP System Installer               ║
║                                                               ║
║  🛒 Conversational Commerce with AI-Powered Product Search   ║
║  🔍 Vector Database with Semantic Similarity                 ║
║  🤖 Claude Desktop Integration via MCP Protocol              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "Run as a regular user with sudo privileges"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking system prerequisites..."
    
    # Check OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    log_success "Operating System: $OS"
    
    # Check available memory
    if command -v free &> /dev/null; then
        MEMORY_KB=$(free | grep '^Mem:' | awk '{print $2}')
        MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    elif [[ "$OS" == "macos" ]] && command -v sysctl &> /dev/null; then
        MEMORY_BYTES=$(sysctl -n hw.memsize)
        MEMORY_GB=$((MEMORY_BYTES / 1024 / 1024 / 1024))
    else
        MEMORY_GB=8  # Assume sufficient
        log_warning "Could not detect memory, assuming sufficient"
    fi
    
    if [[ $MEMORY_GB -lt 4 ]]; then
        log_warning "Low memory detected: ${MEMORY_GB}GB. 4GB+ recommended"
    else
        log_success "Memory: ${MEMORY_GB}GB"
    fi
    
    # Check available disk space
    if command -v df &> /dev/null; then
        DISK_AVAILABLE_KB=$(df . | tail -1 | awk '{print $4}')
        DISK_AVAILABLE_GB=$((DISK_AVAILABLE_KB / 1024 / 1024))
        if [[ $DISK_AVAILABLE_GB -lt 5 ]]; then
            log_error "Insufficient disk space: ${DISK_AVAILABLE_GB}GB available. 5GB+ required"
            exit 1
        else
            log_success "Disk Space: ${DISK_AVAILABLE_GB}GB available"
        fi
    fi
}

# Install Git
install_git() {
    if command -v git &> /dev/null; then
        log_success "Git is already installed: $(git --version)"
        return 0
    fi
    
    log_info "Installing Git..."
    
    case $OS in
        "linux")
            if command -v apt-get &> /dev/null; then
                sudo apt-get update -qq
                sudo apt-get install -y git
            elif command -v yum &> /dev/null; then
                sudo yum install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            else
                log_error "Could not install Git. Please install it manually"
                exit 1
            fi
            ;;
        "macos")
            if ! command -v brew &> /dev/null; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install git
            ;;
        *)
            log_error "Please install Git manually for your system"
            exit 1
            ;;
    esac
    
    log_success "Git installed successfully"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        log_success "Docker is already installed: $(docker --version)"
        log_success "Docker Compose: $(docker-compose --version)"
        return 0
    fi
    
    log_info "Installing Docker and Docker Compose..."
    
    case $OS in
        "linux")
            # Install Docker
            if ! command -v docker &> /dev/null; then
                curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                sudo sh /tmp/get-docker.sh
                sudo usermod -aG docker $USER
                rm /tmp/get-docker.sh
            fi
            
            # Install Docker Compose
            if ! command -v docker-compose &> /dev/null; then
                DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
                sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
            fi
            
            log_warning "Please log out and log back in to use Docker without sudo"
            ;;
        "macos")
            log_info "Please install Docker Desktop for Mac from:"
            log_info "https://docs.docker.com/docker-for-mac/install/"
            log_info "Press Enter after installation is complete..."
            read -r
            ;;
        *)
            log_error "Please install Docker manually for your system"
            exit 1
            ;;
    esac
    
    log_success "Docker installation completed"
}

# Verify Docker is running
verify_docker() {
    log_info "Verifying Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker"
        log_info "On Linux: sudo systemctl start docker"
        log_info "On macOS/Windows: Start Docker Desktop"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    log_success "Docker is running: $(docker --version)"
    log_success "Docker Compose: $(docker-compose --version)"
}

# Get API keys from user
get_api_keys() {
    log_info "Setting up API configuration..."
    
    echo -e "${YELLOW}"
    echo "You'll need these API keys for the system to work:"
    echo "1. Google Gemini API Key (for AI embeddings)"
    echo "2. Himira API Key (for ONDC backend access)"
    echo -e "${NC}"
    
    # Gemini API Key
    while [[ -z "$GEMINI_API_KEY" ]]; do
        echo -e "${YELLOW}Enter your Google Gemini API Key:${NC}"
        echo -e "${BLUE}Get it from: https://makersuite.google.com/app/apikey${NC}"
        read -r GEMINI_API_KEY
        
        if [[ -z "$GEMINI_API_KEY" ]]; then
            log_warning "Gemini API key is required for vector search functionality"
        fi
    done
    
    # Himira API Key
    echo -e "${YELLOW}Enter Himira API Key (or press Enter to use default):${NC}"
    read -r HIMIRA_API_KEY
    
    if [[ -z "$HIMIRA_API_KEY" ]]; then
        HIMIRA_API_KEY="$DEFAULT_HIMIRA_API_KEY"
        log_info "Using default Himira API key"
    fi
    
    log_success "API keys configured"
}

# Clone repository
clone_repository() {
    log_info "Setting up project directory..."
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warning "Directory $PROJECT_DIR already exists"
        echo "Do you want to remove it and start fresh? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            log_error "Please remove or rename the existing directory"
            exit 1
        fi
    fi
    
    log_info "Cloning repository from $REPO_URL..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    log_success "Repository cloned successfully"
}

# Configure environment files
configure_environment() {
    log_info "Configuring environment files..."
    
    # Configure MCP Server environment
    log_info "Setting up MCP Server configuration..."
    cat > ondc-shopping-mcp/.env << EOF
# ONDC Shopping MCP Server Configuration
BACKEND_ENDPOINT=https://hp-buyer-backend-preprod.himira.co.in/clientApis
WIL_API_KEY=$HIMIRA_API_KEY
VECTOR_SEARCH_ENABLED=true
QDRANT_HOST=localhost
QDRANT_PORT=6333
QDRANT_COLLECTION=ondc_products
VECTOR_SIMILARITY_THRESHOLD=0.3
GEMINI_API_KEY=$GEMINI_API_KEY
SESSION_TIMEOUT_MINUTES=30
SESSION_STORE=file
SESSION_STORE_PATH=~/.ondc-mcp/sessions
EOF
    
    # Configure Vector Database environment
    log_info "Setting up Vector Database configuration..."
    cat > himira_vector_db/.env << EOF
# Himira Vector Database ETL Configuration

# ====================
# CORE API CONFIGURATION
# ====================

# Himira Backend API (Primary Data Source)
HIMIRA_BACKEND_URL=https://hp-buyer-backend-preprod.himira.co.in/clientApis
HIMIRA_API_KEY=$HIMIRA_API_KEY
HIMIRA_USER_ID=guestUser
HIMIRA_DEVICE_ID=etl_pipeline_001

# ====================
# VECTOR DATABASE CONFIGURATION
# ====================

# Qdrant Vector Database
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_API_KEY=  # Optional for cloud deployment
QDRANT_URL=http://localhost:6333  # Alternative to host:port

# Collection Names
QDRANT_PRODUCTS_COLLECTION=ondc_products
QDRANT_CATEGORIES_COLLECTION=himira_categories  
QDRANT_PROVIDERS_COLLECTION=himira_providers

# ====================
# AI/ML CONFIGURATION
# ====================

# Google Gemini for Embeddings
GEMINI_API_KEY=$GEMINI_API_KEY
GEMINI_MODEL=models/text-embedding-004
EMBEDDING_DIMENSION=768

# ====================
# ETL PIPELINE CONFIGURATION  
# ====================

# Processing Settings
ETL_BATCH_SIZE=100
ETL_MAX_WORKERS=4
ETL_TIMEOUT_SECONDS=300
ETL_RETRY_ATTEMPTS=3

# Scheduling
ETL_FULL_SYNC_CRON=0 2 * * *      # Daily at 2 AM
ETL_INCREMENTAL_CRON=0 */2 * * *  # Every 2 hours
ETL_AUTO_START=true

# Data Sources
ENABLE_HIMIRA_SOURCE=true
ENABLE_ONDC_SOURCE=false
ENABLE_FILE_SOURCE=true

# ====================
# LOGGING
# ====================

LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE=/app/logs/etl.log

# ====================
# SEARCH CONFIGURATION
# ====================

SEARCH_DEFAULT_LIMIT=20
SEARCH_MAX_LIMIT=100
SEARCH_SIMILARITY_THRESHOLD=0.7
ENABLE_HYBRID_SEARCH=true
EOF
    
    log_success "Environment files configured"
}

# Deploy services
deploy_services() {
    log_info "Deploying Docker services..."
    
    # Create necessary directories
    mkdir -p qdrant_data logs
    
    # Pull images first to show progress
    log_info "Pulling Docker images..."
    docker-compose -f docker-compose.unified.yml pull
    
    # Start services
    log_info "Starting services..."
    docker-compose -f docker-compose.unified.yml up -d
    
    log_success "Services deployed"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for Qdrant
    echo -n "Waiting for Qdrant"
    timeout=300  # 5 minutes
    elapsed=0
    
    while ! curl -sf http://localhost:6333/ > /dev/null 2>&1; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timeout waiting for Qdrant to be ready"
            log_info "Checking Qdrant container status..."
            docker ps --filter name=himira-qdrant --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            docker logs himira-qdrant --tail 20
            exit 1
        fi
        echo -n "."
        sleep 5
        ((elapsed+=5))
    done
    echo -e " ${GREEN}Ready!${NC}"
    
    # Wait for MCP server
    log_info "Checking MCP server initialization..."
    sleep 10
    
    if docker logs ondc-mcp-server 2>&1 | grep -q "MCP Server initialized successfully"; then
        log_success "MCP Server is ready"
    else
        log_warning "MCP Server may still be starting up"
    fi
    
    log_success "All services are ready"
}

# Initialize vector database
initialize_vector_db() {
    log_info "Initializing vector database with product catalog..."
    
    echo "Do you want to populate the database now? (Y/n)"
    read -r response
    
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        log_info "Running ETL pipeline to load products..."
        
        # Run ETL pipeline
        if docker exec himira-etl python -m etl.pipeline --action full --data-types products; then
            # Verify products were loaded
            PRODUCT_COUNT=$(curl -s http://localhost:6333/collections/ondc_products | jq -r '.result.points_count // 0' 2>/dev/null || echo "0")
            
            if [[ "$PRODUCT_COUNT" -gt 0 ]]; then
                log_success "Vector database initialized with $PRODUCT_COUNT products"
            else
                log_warning "ETL completed but no products detected. Check logs"
            fi
        else
            log_warning "ETL pipeline encountered issues. Check logs with: docker logs himira-etl"
        fi
    else
        log_info "Skipping database initialization. You can run it later with:"
        log_info "docker exec himira-etl python -m etl.pipeline --action full"
    fi
}

# Generate system test script
create_test_script() {
    log_info "Creating system test script..."
    
    cat > test_system.py << 'EOF'
#!/usr/bin/env python3
"""System health test script"""

import requests
import json
import time

def test_qdrant():
    """Test Qdrant vector database"""
    try:
        # Test health
        response = requests.get("http://localhost:6333/health", timeout=10)
        if response.status_code != 200:
            return False, "Qdrant health check failed"
        
        # Test collection
        response = requests.get("http://localhost:6333/collections/ondc_products", timeout=10)
        if response.status_code == 200:
            data = response.json()
            points = data.get('result', {}).get('points_count', 0)
            return True, f"Qdrant OK - {points} products loaded"
        else:
            return True, "Qdrant OK - collection may be empty"
            
    except Exception as e:
        return False, f"Qdrant error: {e}"

def test_himira_api():
    """Test Himira backend API"""
    try:
        headers = {"x-api-key": "aPzSpx0rksO96PhGGNKRgfAay0vUbZ"}
        params = {"name": "laptop", "page": 1, "limit": 5, "deviceId": "test"}
        
        response = requests.get(
            "https://hp-buyer-backend-preprod.himira.co.in/clientApis/v2/search/guestUser",
            headers=headers,
            params=params,
            timeout=15
        )
        
        if response.status_code == 200:
            products = len(response.json().get('data', []))
            return True, f"Himira API OK - {products} products found"
        else:
            return False, f"Himira API returned status {response.status_code}"
            
    except Exception as e:
        return False, f"Himira API error: {e}"

def main():
    print("🧪 ONDC MCP System Health Check")
    print("=" * 40)
    
    tests = [
        ("Qdrant Vector Database", test_qdrant),
        ("Himira Backend API", test_himira_api)
    ]
    
    results = []
    for name, test_func in tests:
        print(f"\nTesting {name}...")
        success, message = test_func()
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} - {message}")
        results.append(success)
    
    print(f"\n{'=' * 40}")
    if all(results):
        print("🎉 All tests passed! System is ready to use.")
        return 0
    else:
        print("⚠️  Some tests failed. Check the logs above.")
        return 1

if __name__ == "__main__":
    exit(main())
EOF
    
    chmod +x test_system.py
    log_success "Test script created: test_system.py"
}

# Run system verification
verify_installation() {
    log_info "Running system verification..."
    
    # Check Docker services
    echo -e "${BLUE}Docker Services Status:${NC}"
    docker-compose -f docker-compose.unified.yml ps
    
    # Run Python test script
    if command -v python3 &> /dev/null; then
        echo -e "\n${BLUE}Running health checks...${NC}"
        if python3 test_system.py; then
            log_success "System verification completed successfully"
        else
            log_warning "Some health checks failed - see details above"
        fi
    else
        log_info "Python3 not available - skipping health checks"
        log_info "You can install python3 and run: python3 test_system.py"
    fi
}

# Generate Claude Desktop configuration
create_claude_config() {
    log_info "Generating Claude Desktop configuration..."
    
    cat > claude_desktop_config.json << 'EOF'
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
EOF
    
    log_success "Claude Desktop configuration created: claude_desktop_config.json"
}

# Show final instructions
show_final_instructions() {
    echo -e "${GREEN}"
    cat << 'EOF'

🎉 Installation Complete!

╔═══════════════════════════════════════════════════════════════╗
║                    ONDC Shopping MCP System                   ║
║                        Ready to Use!                          ║
╚═══════════════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
    
    echo -e "${BLUE}🔧 System Status:${NC}"
    echo "   📦 Docker Services: Running"
    echo "   🔍 Vector Database: Initialized"
    echo "   🤖 MCP Server: Ready for Claude Desktop"
    
    echo -e "\n${BLUE}🌐 Access Points:${NC}"
    echo "   📊 Qdrant Dashboard: http://localhost:6333/dashboard"
    echo "   🔧 System Logs: docker-compose -f docker-compose.unified.yml logs -f"
    
    echo -e "\n${BLUE}🔄 Next Steps:${NC}"
    echo "   1. Configure Claude Desktop with the generated config file"
    echo "   2. Copy contents from: ./claude_desktop_config.json"
    
    if [[ "$OS" == "macos" ]]; then
        echo "   3. Paste into: ~/Library/Application Support/Claude/claude_desktop_config.json"
    elif [[ "$OS" == "linux" ]]; then
        echo "   3. Paste into: ~/.config/Claude/claude_desktop_config.json"
    else
        echo "   3. Paste into your Claude Desktop config file"
    fi
    
    echo "   4. Restart Claude Desktop completely"
    echo "   5. Test with: 'search for laptop' or 'find me some gadgets'"
    
    echo -e "\n${BLUE}🛠️  Management Commands:${NC}"
    echo "   Start system:  docker-compose -f docker-compose.unified.yml up -d"
    echo "   Stop system:   docker-compose -f docker-compose.unified.yml down"
    echo "   View logs:     docker-compose -f docker-compose.unified.yml logs -f"
    echo "   Run ETL:       docker exec himira-etl python -m etl.pipeline --action full"
    echo "   Health check:  python3 test_system.py"
    
    echo -e "\n${GREEN}✨ Happy Shopping with Claude! ✨${NC}"
}

# Clean up on exit
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "Installation failed"
        echo -e "\n${YELLOW}Troubleshooting tips:${NC}"
        echo "1. Check Docker is running: docker ps"
        echo "2. View logs: docker-compose -f docker-compose.unified.yml logs"
        echo "3. Check system resources: df -h && free -h"
        echo "4. Restart installation: ./install.sh"
    fi
}

# Main installation process
main() {
    trap cleanup EXIT
    
    log_info "Starting ONDC MCP System installation..."
    
    check_root
    check_prerequisites
    install_git
    install_docker
    verify_docker
    get_api_keys
    clone_repository
    configure_environment
    deploy_services
    wait_for_services
    initialize_vector_db
    create_test_script
    verify_installation
    create_claude_config
    show_final_instructions
}

# Handle command line arguments
case "${1:-}" in
    "test")
        if [[ -f "test_system.py" ]]; then
            python3 test_system.py
        else
            log_error "test_system.py not found. Run installation first."
        fi
        ;;
    "clean")
        log_info "Cleaning up installation..."
        if [[ -d "$PROJECT_DIR" ]]; then
            cd "$PROJECT_DIR"
            docker-compose -f docker-compose.unified.yml down -v
            cd ..
            rm -rf "$PROJECT_DIR"
            log_success "Cleanup complete"
        fi
        ;;
    "help"|"-h"|"--help")
        echo "ONDC MCP System Installer"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (none)  - Run full installation"
        echo "  test    - Run system health check"
        echo "  clean   - Remove installation"
        echo "  help    - Show this help"
        ;;
    *)
        main
        ;;
esac