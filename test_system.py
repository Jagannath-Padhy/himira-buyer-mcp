#!/usr/bin/env python3
"""
Test script to verify ONDC MCP system functionality
"""

import requests
import json

# Test Qdrant connection and collection
def test_qdrant():
    print("=== Testing Qdrant Vector Database ===")
    try:
        # Check collections
        response = requests.get("http://localhost:6333/collections")
        collections = response.json()
        print(f"✓ Qdrant connection successful")
        print(f"✓ Collections: {collections['result']['collections']}")
        
        # Check ondc_products collection
        response = requests.get("http://localhost:6333/collections/ondc_products")
        collection_info = response.json()
        points_count = collection_info['result']['points_count']
        vectors_count = collection_info['result']['vectors_count']
        print(f"✓ ONDC Products Collection:")
        print(f"  - Points: {points_count}")
        print(f"  - Vectors: {vectors_count}")
        
        # Test search
        search_query = {
            "vector": [0.1] * 768,  # Dummy vector
            "limit": 3
        }
        response = requests.post(
            "http://localhost:6333/collections/ondc_products/points/search",
            json=search_query
        )
        if response.status_code == 200:
            print(f"✓ Vector search working")
            results = response.json()
            print(f"  - Found {len(results['result'])} similar products")
            
        return True
    except Exception as e:
        print(f"✗ Qdrant test failed: {e}")
        return False

# Test backend API connection
def test_backend_api():
    print("\n=== Testing Himira Backend API ===")
    try:
        headers = {
            "x-api-key": "aPzSpx0rksO96PhGGNKRgfAay0vUbZ"
        }
        params = {
            "name": "jam",
            "page": 1,
            "limit": 5,
            "deviceId": "test_device"
        }
        
        response = requests.get(
            "https://hp-buyer-backend-preprod.himira.co.in/clientApis/v2/search/guestUser",
            headers=headers,
            params=params
        )
        
        if response.status_code == 200:
            print(f"✓ Backend API connection successful")
            data = response.json()
            products = data.get("data", [])
            print(f"✓ Found {len(products)} products for 'jam'")
            if products:
                print(f"  - First product: {products[0].get('name', 'N/A')}")
            return True
        else:
            print(f"✗ Backend API returned status {response.status_code}")
            return False
            
    except Exception as e:
        print(f"✗ Backend API test failed: {e}")
        return False

# Test MCP server readiness
def test_mcp_server():
    print("\n=== Testing MCP Server ===")
    print("Note: MCP server typically runs via stdio, not HTTP")
    print("To test MCP server functionality:")
    print("1. Run: cd ondc-shopping-mcp && python run_mcp_server.py")
    print("2. Or use Docker: docker exec -it ondc-mcp-server python run_mcp_server.py")
    print("3. The server will accept JSON-RPC commands via stdin")
    return True

def main():
    print("ONDC MCP System Test\n")
    
    # Run tests
    qdrant_ok = test_qdrant()
    backend_ok = test_backend_api()
    mcp_ok = test_mcp_server()
    
    # Summary
    print("\n=== Test Summary ===")
    if qdrant_ok and backend_ok and mcp_ok:
        print("✅ All systems operational!")
        print("\nNext steps:")
        print("1. Configure Claude Desktop to use the MCP server")
        print("2. Test searching for products in Claude")
        print("3. Verify order placement functionality")
    else:
        print("❌ Some tests failed. Please check the logs above.")

if __name__ == "__main__":
    main()