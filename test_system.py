#!/usr/bin/env python3
"""
Quick system health test script for ONDC MCP system
"""

import requests
import json
import subprocess
import sys

def test_qdrant():
    """Test Qdrant vector database"""
    print("=== Testing Qdrant Vector Database ===")
    try:
        # Check health
        response = requests.get("http://localhost:6333/health", timeout=10)
        if response.status_code != 200:
            print(f"✗ Qdrant health check failed: HTTP {response.status_code}")
            return False
        print("✓ Qdrant health check passed")
        
        # Check collections
        response = requests.get("http://localhost:6333/collections", timeout=10)
        if response.status_code == 200:
            collections = response.json()
            collection_names = [c['name'] for c in collections['result']['collections']]
            print(f"✓ Collections found: {collection_names}")
            
            if 'ondc_products' in collection_names:
                # Check collection details
                response = requests.get("http://localhost:6333/collections/ondc_products", timeout=10)
                if response.status_code == 200:
                    collection_info = response.json()
                    points_count = collection_info['result']['points_count']
                    vectors_count = collection_info['result']['vectors_count']
                    print(f"✓ ONDC Products Collection: {points_count} points, {vectors_count} vectors")
                    
                    if points_count > 0:
                        # Test vector search
                        search_query = {
                            "vector": [0.1] * 768,  # Dummy vector
                            "limit": 3,
                            "score_threshold": 0.01
                        }
                        response = requests.post(
                            "http://localhost:6333/collections/ondc_products/points/search",
                            json=search_query,
                            timeout=10
                        )
                        if response.status_code == 200:
                            results = response.json()
                            print(f"✓ Vector search working - {len(results['result'])} results")
                        else:
                            print(f"⚠️ Vector search test failed: HTTP {response.status_code}")
                    else:
                        print("⚠️ No products in vector database - run ETL to populate")
                else:
                    print("⚠️ Could not get collection details")
            else:
                print("⚠️ ondc_products collection not found")
        else:
            print(f"⚠️ Could not get collections: HTTP {response.status_code}")
        
        return True
    except Exception as e:
        print(f"✗ Qdrant test failed: {e}")
        return False

def test_himira_api():
    """Test Himira backend API"""
    print("\n=== Testing Himira Backend API ===")
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
            print("✓ Backend API connection successful")
            data = response.json()
            products = data.get("data", [])
            print(f"✓ Found {len(products)} products for 'laptop'")
            if products:
                print(f"  - Sample product: {products[0].get('name', 'N/A')}")
            return True
        else:
            print(f"✗ Backend API returned status {response.status_code}")
            return False
            
    except Exception as e:
        print(f"✗ Backend API test failed: {e}")
        return False

def test_docker_services():
    """Test Docker services status"""
    print("\n=== Testing Docker Services ===")
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}\t{{.Status}}", "--filter", "status=running"],
            capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            running_services = result.stdout.strip().split('\n') if result.stdout.strip() else []
            expected_services = ["himira-qdrant", "himira-etl", "ondc-mcp-server"]
            
            found_services = []
            for line in running_services:
                name = line.split('\t')[0]
                if name in expected_services:
                    found_services.append(name)
                    print(f"✓ {name}: Running")
            
            missing_services = [s for s in expected_services if s not in found_services]
            if missing_services:
                print(f"⚠️ Missing services: {', '.join(missing_services)}")
                return len(found_services) > 0
            else:
                print("✓ All expected Docker services are running")
                return True
        else:
            print(f"✗ Docker command failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"✗ Docker services test failed: {e}")
        return False

def test_mcp_server():
    """Test MCP server logs for initialization"""
    print("\n=== Testing MCP Server ===")
    try:
        result = subprocess.run(
            ["docker", "logs", "ondc-mcp-server", "--tail", "20"],
            capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            logs = result.stdout + result.stderr
            success_indicators = [
                "MCP Server initialized successfully",
                "Vector search: Enabled",
                "Vector search auto-initialized: True"
            ]
            
            found_indicators = [indicator for indicator in success_indicators if indicator in logs]
            
            if found_indicators:
                print(f"✓ MCP Server initialized - Found {len(found_indicators)}/3 success indicators")
                for indicator in found_indicators:
                    print(f"  - {indicator}")
                
                if "threshold: 0.3" in logs:
                    print("✓ Vector search threshold properly configured (0.3)")
                elif "threshold:" in logs:
                    threshold_line = [line for line in logs.split('\n') if 'threshold:' in line]
                    if threshold_line:
                        print(f"✓ Vector search threshold: {threshold_line[0].strip()}")
                
                return True
            else:
                print("⚠️ MCP Server may still be initializing - no success indicators found")
                return False
        else:
            print(f"✗ Could not get MCP server logs: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"✗ MCP Server test failed: {e}")
        return False

def main():
    """Run all tests and show summary"""
    print("🧪 ONDC MCP System - Quick Health Check")
    print("=" * 50)
    
    tests = [
        ("Docker Services", test_docker_services),
        ("Qdrant Database", test_qdrant),
        ("Himira API", test_himira_api),
        ("MCP Server", test_mcp_server)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"✗ {test_name} test crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 HEALTH CHECK SUMMARY")
    print("=" * 50)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\nScore: {passed}/{total} tests passed ({(passed/total)*100:.0f}%)")
    
    if passed == total:
        print("🎉 All tests passed! Your ONDC MCP system is ready.")
        print("\n📋 Next Steps:")
        print("1. Configure Claude Desktop with the MCP server")
        print("2. Test with queries like: 'search for laptop'")
        print("3. Check detailed status: python validate_system.py")
        return 0
    elif passed >= total * 0.75:
        print("⚠️ Most tests passed. System should work with minor issues.")
        print("\n🔧 Recommendations:")
        print("1. Check failed tests above")
        print("2. Run full validation: python validate_system.py")
        return 1
    else:
        print("💥 Multiple test failures. System needs attention.")
        print("\n🛠️ Troubleshooting:")
        print("1. Ensure Docker services are running: docker ps")
        print("2. Check logs: docker-compose -f docker-compose.unified.yml logs")
        print("3. Restart services: docker-compose -f docker-compose.unified.yml restart")
        print("4. Run installation: ./install.sh")
        return 2

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)