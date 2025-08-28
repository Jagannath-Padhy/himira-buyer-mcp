#!/usr/bin/env python3
"""
Test script to verify vector search functionality
"""

import os
import asyncio
import sys
from typing import List, Dict, Any, Optional

# Add MCP source directory to path
mcp_src_dir = '/Users/jagannath/Desktop/ondc-genie/ondc-shopping-mcp/src'
if mcp_src_dir not in sys.path:
    sys.path.insert(0, mcp_src_dir)

# Set working directory for relative imports
original_dir = os.getcwd()
os.chdir('/Users/jagannath/Desktop/ondc-genie/ondc-shopping-mcp')

async def test_vector_search():
    """Test vector search with various queries"""
    print("🔍 Testing Vector Search Functionality\n")
    
    try:
        # Import after setting up paths
        from src.config import Config
        from src.vector_search.client import VectorSearchClient, SearchFilters
        
        # Load configuration
        config = Config()
        print(f"Vector search enabled: {config.vector.enabled}")
        print(f"Qdrant host: {config.vector.host}:{config.vector.port}")
        print(f"Collection: {config.vector.collection}")
        print(f"Similarity threshold: {config.vector.similarity_threshold}")
        print(f"Gemini API key configured: {'Yes' if config.vector.gemini_api_key else 'No'}")
        print()
        
        # Initialize vector client
        vector_client = VectorSearchClient(config.vector)
        
        if not vector_client.is_available():
            print("❌ Vector search client is not available")
            return
            
        print("✅ Vector search client initialized successfully\n")
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("Falling back to direct Qdrant test only")
        return
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        return
    
    # Test queries - from specific to generic
    test_queries = [
        # Specific products that should exist
        "laptop",
        "simarLaptop", 
        
        # Generic electronics terms
        "computer",
        "electronic device",
        "gadget",
        "productive gadgets",
        
        # Broader terms
        "technology",
        "device",
        "product"
    ]
    
    print("=== Testing Vector Search Queries ===\n")
    
    for query in test_queries:
        print(f"🔍 Testing query: '{query}'")
        try:
            # Test without filters first
            results = await vector_client.search(query=query, limit=5)
            
            if results:
                print(f"✅ Found {len(results)} results:")
                for i, result in enumerate(results[:3], 1):  # Show top 3
                    item = result['item']
                    score = result['score']
                    name = item.get('name', 'N/A')
                    category = item.get('category', 'N/A')
                    print(f"   {i}. {name} (category: {category}) - Score: {score:.4f}")
            else:
                print("❌ No results found")
                
        except Exception as e:
            print(f"❌ Error: {e}")
        
        print()
    
    # Test with filters
    print("=== Testing with Price Filters ===\n")
    
    filters = SearchFilters(
        price_min=10000,  # 10k+
        price_max=50000   # Up to 50k
    )
    
    results = await vector_client.search(query="laptop", filters=filters, limit=5)
    if results:
        print(f"✅ Found {len(results)} laptops in price range 10k-50k:")
        for result in results:
            item = result['item']
            name = item.get('name', 'N/A')
            price = item.get('price', 'N/A')
            print(f"   - {name}: ₹{price}")
    else:
        print("❌ No laptops found in price range")
    
    print("\n=== Test Complete ===")

async def test_direct_qdrant():
    """Test direct Qdrant connection"""
    print("\n🔍 Testing Direct Qdrant Connection\n")
    
    try:
        from qdrant_client import QdrantClient
        
        client = QdrantClient(host="localhost", port=6333)
        
        # Check collections
        collections = client.get_collections()
        print(f"Available collections: {[c.name for c in collections.collections]}")
        
        # Check ondc_products collection
        if any(c.name == "ondc_products" for c in collections.collections):
            collection_info = client.get_collection("ondc_products")
            print(f"ondc_products collection:")
            print(f"  Points count: {collection_info.points_count}")
            print(f"  Vectors count: {collection_info.vectors_count}")
            
            # Sample a few points
            points = client.scroll(
                collection_name="ondc_products",
                limit=3,
                with_payload=True
            )[0]
            
            print(f"  Sample products:")
            for point in points:
                payload = point.payload
                name = payload.get('name', 'N/A')
                category = payload.get('category', 'N/A')
                price = payload.get('price', 'N/A')
                print(f"    - {name} ({category}) - ₹{price}")
        else:
            print("❌ ondc_products collection not found")
            
    except Exception as e:
        print(f"❌ Direct Qdrant test failed: {e}")

def main():
    """Run all tests"""
    print("Vector Search Test Suite")
    print("=" * 50)
    
    # Set environment variables for testing
    os.environ.setdefault("VECTOR_SEARCH_ENABLED", "true")
    os.environ.setdefault("QDRANT_HOST", "localhost")
    os.environ.setdefault("QDRANT_PORT", "6333")
    os.environ.setdefault("QDRANT_COLLECTION", "ondc_products")
    os.environ.setdefault("VECTOR_SIMILARITY_THRESHOLD", "0.3")
    
    loop = asyncio.get_event_loop()
    
    # Test direct Qdrant connection first
    loop.run_until_complete(test_direct_qdrant())
    
    # Test vector search functionality
    loop.run_until_complete(test_vector_search())

if __name__ == "__main__":
    main()