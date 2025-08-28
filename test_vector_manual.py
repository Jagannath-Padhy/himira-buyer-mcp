#!/usr/bin/env python3
"""
Manual test using Qdrant client directly with improved threshold
"""

import asyncio
import json
from qdrant_client import QdrantClient
from qdrant_client.models import Filter, FieldCondition, Range

async def test_direct_vector_search():
    """Test vector search directly with Qdrant"""
    print("🔍 Testing Direct Vector Search with Lower Threshold")
    print("=" * 50)
    
    try:
        # Connect to Qdrant
        client = QdrantClient(host="localhost", port=6333)
        
        # Test 1: Get sample products to understand data structure
        print("\n📋 Sample Products in Database:")
        points = client.scroll(
            collection_name="ondc_products",
            limit=3,
            with_payload=True
        )[0]
        
        for i, point in enumerate(points, 1):
            payload = point.payload
            print(f"{i}. Name: {payload.get('name', 'N/A')}")
            print(f"   Category: {payload.get('category', 'N/A')}")
            print(f"   Description: {payload.get('description', 'N/A')[:100]}...")
            print()
        
        # Test 2: Search without embeddings using metadata only
        print("\n🔍 Testing Metadata-based Search (no embeddings needed):")
        
        # Search for laptops by name
        laptop_filter = Filter(
            must=[
                FieldCondition(
                    key="name",
                    match={"text": "laptop"}
                )
            ]
        )
        
        try:
            laptop_results = client.search(
                collection_name="ondc_products",
                query_vector=[0.1] * 768,  # Dummy vector
                query_filter=laptop_filter,
                limit=5,
                score_threshold=0.0  # Very low threshold
            )
            
            print(f"Found {len(laptop_results)} laptop results:")
            for result in laptop_results:
                name = result.payload.get('name', 'N/A')
                score = result.score
                print(f"  - {name} (score: {score:.4f})")
                
        except Exception as e:
            print(f"Laptop search failed: {e}")
        
        # Test 3: Search for any products with very low threshold
        print(f"\n🔍 Testing Low Threshold Search:")
        try:
            low_threshold_results = client.search(
                collection_name="ondc_products",
                query_vector=[0.1] * 768,  # Dummy vector - normally would be query embedding
                limit=10,
                score_threshold=0.01  # Very low threshold
            )
            
            print(f"Found {len(low_threshold_results)} results with threshold 0.01:")
            for result in low_threshold_results[:5]:
                name = result.payload.get('name', 'N/A')
                score = result.score
                print(f"  - {name} (score: {score:.4f})")
                
        except Exception as e:
            print(f"Low threshold search failed: {e}")
            
        # Test 4: Get collection stats
        print(f"\n📊 Collection Statistics:")
        collection_info = client.get_collection("ondc_products")
        print(f"Total points: {collection_info.points_count}")
        print(f"Total vectors: {collection_info.vectors_count}")
        print(f"Vector config: {collection_info.config}")
        
    except Exception as e:
        print(f"❌ Direct search failed: {e}")

def main():
    """Run the test"""
    asyncio.run(test_direct_vector_search())

if __name__ == "__main__":
    main()