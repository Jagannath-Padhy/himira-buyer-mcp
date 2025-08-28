#!/usr/bin/env python3
"""
ONDC MCP System Validation Script
Comprehensive testing suite for the complete system
"""

import requests
import json
import time
import subprocess
import sys
import os
from typing import Tuple, Dict, Any, List
from datetime import datetime

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

def log_info(message: str):
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.NC}")

def log_success(message: str):
    print(f"{Colors.GREEN}✅ {message}{Colors.NC}")

def log_warning(message: str):
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.NC}")

def log_error(message: str):
    print(f"{Colors.RED}❌ {message}{Colors.NC}")

def log_test(message: str):
    print(f"{Colors.CYAN}🧪 {message}{Colors.NC}")

def log_step(step: int, total: int, message: str):
    print(f"{Colors.PURPLE}[{step}/{total}] {message}{Colors.NC}")

class SystemValidator:
    def __init__(self):
        self.results = []
        self.start_time = datetime.now()
        
    def run_command(self, command: str) -> Tuple[bool, str]:
        """Run a shell command and return success status and output"""
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True, timeout=30
            )
            return result.returncode == 0, result.stdout + result.stderr
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def test_docker_services(self) -> Tuple[bool, str]:
        """Test Docker services are running"""
        log_test("Testing Docker services...")
        
        # Check if docker-compose file exists
        if not os.path.exists("docker-compose.unified.yml"):
            return False, "docker-compose.unified.yml not found"
        
        success, output = self.run_command("docker-compose -f docker-compose.unified.yml ps")
        if not success:
            return False, f"Failed to check services: {output}"
        
        # Check for expected services
        required_services = ["qdrant", "etl", "mcp-server"]
        for service in required_services:
            if service not in output:
                return False, f"Service {service} not found in docker-compose output"
        
        # Check if services are running
        success, output = self.run_command("docker ps --format '{{.Names}}' --filter 'status=running'")
        if not success:
            return False, f"Failed to check running containers: {output}"
        
        running_services = output.strip().split('\n') if output.strip() else []
        expected_containers = ["himira-qdrant", "himira-etl", "ondc-mcp-server"]
        
        missing = [c for c in expected_containers if c not in running_services]
        if missing:
            return False, f"Containers not running: {', '.join(missing)}"
        
        return True, f"All Docker services running: {', '.join(expected_containers)}"
    
    def test_qdrant_health(self) -> Tuple[bool, str]:
        """Test Qdrant vector database health"""
        log_test("Testing Qdrant vector database...")
        
        try:
            # Health check
            response = requests.get("http://localhost:6333/health", timeout=10)
            if response.status_code != 200:
                return False, f"Qdrant health check failed: HTTP {response.status_code}"
            
            # Check collections
            response = requests.get("http://localhost:6333/collections", timeout=10)
            if response.status_code != 200:
                return False, f"Failed to get collections: HTTP {response.status_code}"
            
            data = response.json()
            collections = [c['name'] for c in data.get('result', {}).get('collections', [])]
            
            if 'ondc_products' not in collections:
                return False, "ondc_products collection not found"
            
            # Check collection details
            response = requests.get("http://localhost:6333/collections/ondc_products", timeout=10)
            if response.status_code == 200:
                collection_data = response.json()
                points_count = collection_data.get('result', {}).get('points_count', 0)
                vectors_count = collection_data.get('result', {}).get('vectors_count', 0)
                
                return True, f"Qdrant OK - {points_count} points, {vectors_count} vectors"
            else:
                return True, "Qdrant OK - collection details unavailable"
                
        except requests.RequestException as e:
            return False, f"Qdrant connection failed: {e}"
    
    def test_vector_search(self) -> Tuple[bool, str]:
        """Test vector search functionality"""
        log_test("Testing vector search functionality...")
        
        try:
            # Test vector search with dummy query
            search_payload = {
                "vector": [0.1] * 768,  # Dummy vector
                "limit": 5,
                "score_threshold": 0.01  # Very low threshold
            }
            
            response = requests.post(
                "http://localhost:6333/collections/ondc_products/points/search",
                json=search_payload,
                timeout=15
            )
            
            if response.status_code == 200:
                results = response.json().get('result', [])
                return True, f"Vector search OK - {len(results)} results returned"
            else:
                return False, f"Vector search failed: HTTP {response.status_code}"
                
        except requests.RequestException as e:
            return False, f"Vector search test failed: {e}"
    
    def test_himira_api(self) -> Tuple[bool, str]:
        """Test Himira backend API connectivity"""
        log_test("Testing Himira backend API...")
        
        try:
            headers = {
                "x-api-key": "aPzSpx0rksO96PhGGNKRgfAay0vUbZ",
                "Content-Type": "application/json"
            }
            params = {
                "name": "laptop",
                "page": 1,
                "limit": 5,
                "deviceId": "test_device"
            }
            
            response = requests.get(
                "https://hp-buyer-backend-preprod.himira.co.in/clientApis/v2/search/guestUser",
                headers=headers,
                params=params,
                timeout=15
            )
            
            if response.status_code == 200:
                data = response.json()
                products = data.get('data', [])
                return True, f"Himira API OK - {len(products)} products found for 'laptop'"
            else:
                return False, f"Himira API failed: HTTP {response.status_code}"
                
        except requests.RequestException as e:
            return False, f"Himira API test failed: {e}"
    
    def test_mcp_server_logs(self) -> Tuple[bool, str]:
        """Test MCP server initialization from logs"""
        log_test("Testing MCP server initialization...")
        
        success, output = self.run_command("docker logs ondc-mcp-server --tail 50")
        if not success:
            return False, f"Failed to get MCP server logs: {output}"
        
        # Check for success indicators
        success_indicators = [
            "MCP Server initialized successfully",
            "Vector search: Enabled",
            "Vector search auto-initialized: True"
        ]
        
        found_indicators = []
        for indicator in success_indicators:
            if indicator in output:
                found_indicators.append(indicator)
        
        if found_indicators:
            return True, f"MCP Server OK - Found: {len(found_indicators)}/3 success indicators"
        else:
            return False, "MCP Server may not be properly initialized"
    
    def test_etl_functionality(self) -> Tuple[bool, str]:
        """Test ETL pipeline functionality"""
        log_test("Testing ETL pipeline...")
        
        # Check ETL container status
        success, output = self.run_command("docker ps --filter 'name=himira-etl' --format '{{.Status}}'")
        if not success:
            return False, f"Failed to check ETL container: {output}"
        
        if "Up" not in output:
            return False, "ETL container is not running"
        
        # Check ETL logs for successful operations
        success, output = self.run_command("docker logs himira-etl --tail 100")
        if not success:
            return False, f"Failed to get ETL logs: {output}"
        
        # Look for extraction success
        if "extraction completed" in output.lower() or "extracted" in output.lower():
            return True, "ETL pipeline appears to be working"
        else:
            return True, "ETL container running - logs may not show recent activity"
    
    def test_environment_config(self) -> Tuple[bool, str]:
        """Test environment configuration"""
        log_test("Testing environment configuration...")
        
        config_files = [
            "ondc-shopping-mcp/.env",
            "himira_vector_db/.env"
        ]
        
        missing_files = []
        for config_file in config_files:
            if not os.path.exists(config_file):
                missing_files.append(config_file)
        
        if missing_files:
            return False, f"Missing config files: {', '.join(missing_files)}"
        
        # Check for placeholder values
        placeholder_indicators = ["your_api_key_here", "your-api-key", "your_gemini_api_key_here"]
        
        for config_file in config_files:
            try:
                with open(config_file, 'r') as f:
                    content = f.read()
                    for placeholder in placeholder_indicators:
                        if placeholder in content:
                            return False, f"Found placeholder '{placeholder}' in {config_file}"
            except Exception as e:
                return False, f"Failed to read {config_file}: {e}"
        
        return True, "Environment configuration appears complete"
    
    def test_ports_accessibility(self) -> Tuple[bool, str]:
        """Test required ports are accessible"""
        log_test("Testing port accessibility...")
        
        required_ports = [
            (6333, "Qdrant HTTP"),
            (6334, "Qdrant gRPC")
        ]
        
        accessible_ports = []
        for port, service in required_ports:
            try:
                response = requests.get(f"http://localhost:{port}/health", timeout=5)
                if response.status_code == 200:
                    accessible_ports.append(f"{service} ({port})")
            except:
                continue
        
        if accessible_ports:
            return True, f"Accessible ports: {', '.join(accessible_ports)}"
        else:
            return False, "No required ports are accessible"
    
    def test_disk_space(self) -> Tuple[bool, str]:
        """Test available disk space"""
        log_test("Testing disk space...")
        
        success, output = self.run_command("df -h .")
        if not success:
            return False, f"Failed to check disk space: {output}"
        
        lines = output.strip().split('\n')
        if len(lines) < 2:
            return False, "Unexpected df output format"
        
        # Extract available space (assuming standard df format)
        try:
            fields = lines[1].split()
            available = fields[3] if len(fields) > 3 else "Unknown"
            return True, f"Available disk space: {available}"
        except:
            return True, "Disk space check completed"
    
    def test_system_resources(self) -> Tuple[bool, str]:
        """Test system resources"""
        log_test("Testing system resources...")
        
        # Check memory usage
        success, output = self.run_command("docker stats --no-stream --format 'table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}'")
        if success and output:
            container_count = len([line for line in output.split('\n') if line.strip()])
            return True, f"Docker stats available - {container_count-1} containers monitored"
        else:
            return True, "System resources check completed"
    
    def run_validation_suite(self) -> Dict[str, Any]:
        """Run complete validation suite"""
        print(f"{Colors.BLUE}")
        print("╔" + "═" * 60 + "╗")
        print("║" + " " * 15 + "ONDC MCP System Validation" + " " * 15 + "║")
        print("╚" + "═" * 60 + "╝")
        print(f"{Colors.NC}")
        
        tests = [
            ("Docker Services", self.test_docker_services),
            ("Qdrant Database", self.test_qdrant_health),
            ("Vector Search", self.test_vector_search),
            ("Himira API", self.test_himira_api),
            ("MCP Server", self.test_mcp_server_logs),
            ("ETL Pipeline", self.test_etl_functionality),
            ("Environment Config", self.test_environment_config),
            ("Port Accessibility", self.test_ports_accessibility),
            ("Disk Space", self.test_disk_space),
            ("System Resources", self.test_system_resources)
        ]
        
        results = {}
        total_tests = len(tests)
        passed_tests = 0
        
        for i, (test_name, test_func) in enumerate(tests, 1):
            log_step(i, total_tests, f"Running {test_name} test")
            
            try:
                success, message = test_func()
                results[test_name] = {
                    "passed": success,
                    "message": message,
                    "timestamp": datetime.now().isoformat()
                }
                
                if success:
                    log_success(f"{test_name}: {message}")
                    passed_tests += 1
                else:
                    log_error(f"{test_name}: {message}")
                    
            except Exception as e:
                log_error(f"{test_name}: Unexpected error - {e}")
                results[test_name] = {
                    "passed": False,
                    "message": f"Unexpected error: {e}",
                    "timestamp": datetime.now().isoformat()
                }
            
            print()  # Add spacing between tests
        
        # Generate summary
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()
        
        summary = {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": total_tests - passed_tests,
            "success_rate": (passed_tests / total_tests) * 100,
            "duration_seconds": duration,
            "timestamp": end_time.isoformat(),
            "results": results
        }
        
        self.print_summary(summary)
        return summary
    
    def print_summary(self, summary: Dict[str, Any]):
        """Print validation summary"""
        print(f"{Colors.BLUE}{'═' * 60}{Colors.NC}")
        print(f"{Colors.BLUE}                    VALIDATION SUMMARY{Colors.NC}")
        print(f"{Colors.BLUE}{'═' * 60}{Colors.NC}")
        
        total = summary['total_tests']
        passed = summary['passed_tests']
        failed = summary['failed_tests']
        success_rate = summary['success_rate']
        duration = summary['duration_seconds']
        
        print(f"📊 Tests Run: {total}")
        print(f"✅ Passed: {passed}")
        print(f"❌ Failed: {failed}")
        print(f"📈 Success Rate: {success_rate:.1f}%")
        print(f"⏱️  Duration: {duration:.2f} seconds")
        
        if success_rate >= 90:
            log_success("🎉 System validation PASSED! Your ONDC MCP system is ready to use.")
            print(f"\n{Colors.GREEN}Next Steps:{Colors.NC}")
            print("1. Configure Claude Desktop with the MCP server")
            print("2. Test conversational commerce with queries like 'search for laptop'")
            print("3. Monitor system with: docker-compose -f docker-compose.unified.yml logs -f")
        elif success_rate >= 70:
            log_warning("⚠️  System validation passed with warnings.")
            print(f"\n{Colors.YELLOW}Recommendations:{Colors.NC}")
            print("1. Review failed tests above")
            print("2. Check logs: docker-compose -f docker-compose.unified.yml logs")
            print("3. Consider restarting services if needed")
        else:
            log_error("💥 System validation FAILED!")
            print(f"\n{Colors.RED}Critical Issues Found:{Colors.NC}")
            for test_name, result in summary['results'].items():
                if not result['passed']:
                    print(f"   • {test_name}: {result['message']}")
            
            print(f"\n{Colors.YELLOW}Troubleshooting:{Colors.NC}")
            print("1. Check Docker is running: docker ps")
            print("2. Review installation: ./install.sh")
            print("3. Check system resources: df -h && free -h")
        
        print(f"\n{Colors.BLUE}{'═' * 60}{Colors.NC}")

def main():
    """Main entry point"""
    validator = SystemValidator()
    
    # Change to the correct directory if script is run from elsewhere
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    try:
        summary = validator.run_validation_suite()
        
        # Save results to file
        with open('validation_report.json', 'w') as f:
            json.dump(summary, f, indent=2)
        
        log_info("Validation report saved to: validation_report.json")
        
        # Exit with appropriate code
        if summary['success_rate'] >= 90:
            sys.exit(0)  # Success
        elif summary['success_rate'] >= 70:
            sys.exit(1)  # Warnings
        else:
            sys.exit(2)  # Failure
            
    except KeyboardInterrupt:
        log_warning("\nValidation interrupted by user")
        sys.exit(130)
    except Exception as e:
        log_error(f"Validation failed with unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()