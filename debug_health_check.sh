#!/bin/bash
# Debug script for Qdrant health check issues

echo "🔍 Qdrant Health Check Debugging Script"
echo "======================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check Docker status
echo -e "\n${BLUE}1. Docker Status${NC}"
echo "==================="
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi

log_success "Docker is running"

# Check Qdrant container
echo -e "\n${BLUE}2. Qdrant Container Status${NC}"
echo "============================"
if docker ps | grep -q "himira-qdrant"; then
    log_success "Qdrant container is running"
    
    # Show container details
    echo "Container details:"
    docker ps --filter name=himira-qdrant --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Show health status
    echo -e "\nHealth status:"
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' himira-qdrant 2>/dev/null || echo "no-health-check")
    echo "Current health status: $HEALTH_STATUS"
    
    if [[ "$HEALTH_STATUS" != "healthy" && "$HEALTH_STATUS" != "no-health-check" ]]; then
        log_warning "Container is not healthy. Recent health check logs:"
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' himira-qdrant 2>/dev/null || echo "No health check logs available"
    fi
    
else
    log_error "Qdrant container (himira-qdrant) is not running"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

# Test network connectivity
echo -e "\n${BLUE}3. Network Connectivity${NC}"
echo "========================="

# Test from host
echo "Testing from host machine:"
for endpoint in "/" "/health" "/readiness" "/collections"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:6333${endpoint}" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        log_success "http://localhost:6333${endpoint} -> HTTP $HTTP_CODE"
    elif [[ "$HTTP_CODE" == "404" ]]; then
        log_warning "http://localhost:6333${endpoint} -> HTTP $HTTP_CODE (Not Found)"
    else
        log_error "http://localhost:6333${endpoint} -> HTTP $HTTP_CODE or Connection Failed"
    fi
done

# Test from inside container
echo -e "\nTesting from inside Qdrant container:"
for endpoint in "/" "/health" "/readiness"; do
    RESULT=$(docker exec himira-qdrant sh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:6333${endpoint}" 2>/dev/null || echo "EXEC_FAILED")
    if [[ "$RESULT" == "200" ]]; then
        log_success "Internal http://localhost:6333${endpoint} -> HTTP $RESULT"
    elif [[ "$RESULT" == "404" ]]; then
        log_warning "Internal http://localhost:6333${endpoint} -> HTTP $RESULT (Not Found)"
    elif [[ "$RESULT" == "EXEC_FAILED" ]]; then
        log_error "Internal http://localhost:6333${endpoint} -> Command execution failed"
    else
        log_error "Internal http://localhost:6333${endpoint} -> HTTP $RESULT or Connection Failed"
    fi
done

# Check available tools in container
echo -e "\n${BLUE}4. Available Tools in Container${NC}"
echo "=================================="
TOOLS=("curl" "wget" "nc" "netcat")
for tool in "${TOOLS[@]}"; do
    if docker exec himira-qdrant which "$tool" &>/dev/null; then
        log_success "$tool is available"
    else
        log_warning "$tool is not available"
    fi
done

# Test current health check command
echo -e "\n${BLUE}5. Current Health Check Test${NC}"
echo "================================"
echo "Testing current health check command:"
echo 'curl -f http://localhost:6333/ > /dev/null 2>&1 || wget -q --spider http://localhost:6333/ || nc -z localhost 6333'

HEALTH_RESULT=$(docker exec himira-qdrant sh -c 'curl -f http://localhost:6333/ > /dev/null 2>&1 && echo "SUCCESS" || (wget -q --spider http://localhost:6333/ && echo "WGET_SUCCESS" || (nc -z localhost 6333 && echo "NC_SUCCESS" || echo "ALL_FAILED"))')

case "$HEALTH_RESULT" in
    "SUCCESS")
        log_success "Health check PASSED (curl)"
        ;;
    "WGET_SUCCESS")
        log_success "Health check PASSED (wget fallback)"
        ;;
    "NC_SUCCESS")
        log_success "Health check PASSED (netcat fallback)"
        ;;
    "ALL_FAILED")
        log_error "Health check FAILED (all methods failed)"
        ;;
    *)
        log_error "Health check result unclear: $HEALTH_RESULT"
        ;;
esac

# Check Qdrant logs
echo -e "\n${BLUE}6. Recent Qdrant Logs${NC}"
echo "======================"
echo "Last 20 lines of Qdrant logs:"
docker logs himira-qdrant --tail 20

# Check port binding
echo -e "\n${BLUE}7. Port Binding${NC}"
echo "================"
if netstat -ln 2>/dev/null | grep -q ":6333" || ss -ln 2>/dev/null | grep -q ":6333"; then
    log_success "Port 6333 is bound and listening"
    # Show what's listening on the port
    if command -v lsof &>/dev/null; then
        echo "Process listening on port 6333:"
        sudo lsof -i :6333 2>/dev/null || echo "lsof requires sudo or is not available"
    fi
else
    log_error "Port 6333 is not bound or listening"
fi

# Test Docker Compose health check
echo -e "\n${BLUE}8. Docker Compose Health Status${NC}"
echo "=================================="
if [ -f "docker-compose.unified.yml" ]; then
    echo "Current service health status:"
    docker-compose -f docker-compose.unified.yml ps
else
    log_warning "docker-compose.unified.yml not found in current directory"
fi

# Recommendations
echo -e "\n${BLUE}9. Recommendations${NC}"
echo "=================="

if [[ "$HEALTH_RESULT" == "SUCCESS" || "$HEALTH_RESULT" == *"SUCCESS" ]]; then
    log_success "Health check is working. The issue might be timing-related."
    echo "Consider:"
    echo "  • Increasing start_period in docker-compose.yml"
    echo "  • Checking if dependent services start too quickly"
    echo "  • Restarting services: docker-compose -f docker-compose.unified.yml restart"
else
    log_error "Health check is failing. Try these solutions:"
    echo "  • Restart Qdrant: docker restart himira-qdrant"
    echo "  • Check firewall/network settings"
    echo "  • Use alternative health check: change to 'nc -z localhost 6333'"
    echo "  • Disable health check temporarily for testing"
fi

echo -e "\n${BLUE}10. Quick Fix Commands${NC}"
echo "======================"
echo "To restart services:"
echo "  docker-compose -f docker-compose.unified.yml restart"
echo ""
echo "To restart just Qdrant:"
echo "  docker restart himira-qdrant"
echo ""
echo "To check logs continuously:"
echo "  docker logs himira-qdrant -f"
echo ""
echo "To disable health check temporarily, comment out the healthcheck section in docker-compose.unified.yml"

echo -e "\n🎉 Debug complete!"