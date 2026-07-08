#!/usr/bin/env python3
# ============================================================================
# TEST BATCH EXECUTION OF MULTI-LANGUAGE FUNCTIONS
# ============================================================================
# Purpose: Test concurrent execution of all functions
# Date: 2026-07-08
# ============================================================================

import requests
import json
import sys
import time
from typing import List, Dict, Any

# ============================================================================
# CONFIGURATION
# ============================================================================

LOCAL_API_URL = "http://127.0.0.1:8000"

# ============================================================================
# BATCH TEST DATA
# ============================================================================

BATCH_TEST = {
    "functions": [
        "py-array-sum-optimized",
        "js-string-analyzer",
        "java-matrix-multiply",
        "cpp-merge-sort",
        "cs-stealth-cipher",
        "rs-parallel-compute",
        "rb-dynamic-data-processor"
    ],
    "arguments": [
        {"numbers": [1, 2, 3, 4, 5]},
        {"text": "Mighty Power Phase 2 Stealth Technology"},
        {"matrix1": [[1, 2], [3, 4]], "matrix2": [[5, 6], [7, 8]]},
        {"numbers": [5, 2, 8, 1, 9, 3, 7, 4, 6]},
        {"plaintext": "Stealth Algorithm", "key": "secure_key_2026"},
        {"numbers": [100, 200, 300], "operation": "average"},
        {"data_hash": {"key": "value", "test": "data"}, "transformations": ["uppercase"]}
    ]
}

# ============================================================================
# BATCH EXECUTION
# ============================================================================

def execute_batch(batch_data: Dict[str, Any]) -> bool:
    """Execute batch of functions"""
    try:
        print("Sending batch execution request...")
        start_time = time.time()
        
        response = requests.post(
            f"{LOCAL_API_URL}/execute/batch",
            json=batch_data,
            timeout=60
        )
        
        elapsed = time.time() - start_time
        
        if response.status_code == 200:
            result = response.json()
            total = result.get("total", 0)
            results = result.get("results", [])
            
            print(f"\n✓ Batch execution completed in {elapsed:.2f}s")
            print(f"  Functions executed: {total}")
            print(f"  Status breakdown:")
            
            successful = 0
            total_execution_time = 0
            
            for res in results:
                func_id = res.get("function_id")
                status = res.get("status")
                exec_time = res.get("execution_time", 0)
                
                status_symbol = "✓" if status == "success" else "✗"
                print(f"    {status_symbol} {func_id:35s} | {status:10s} | {exec_time*1000:8.2f}ms")
                
                if status == "success":
                    successful += 1
                total_execution_time += exec_time
            
            print(f"\n  Summary:")
            print(f"    Successful: {successful}/{total}")
            print(f"    Total function time (serial): {total_execution_time*1000:.2f}ms")
            print(f"    Batch time (concurrent): {elapsed*1000:.2f}ms")
            speedup = total_execution_time / elapsed if elapsed > 0 else 0
            print(f"    Speedup: {speedup:.1f}x faster with concurrency")
            
            return successful == total
        else:
            print(f"✗ HTTP {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def get_system_stats() -> None:
    """Get system statistics"""
    try:
        response = requests.get(f"{LOCAL_API_URL}/stats", timeout=5)
        
        if response.status_code == 200:
            stats = response.json()
            print("\n" + "="*70)
            print("LOCAL API SYSTEM STATISTICS")
            print("="*70)
            print(f"Total functions registered: {stats.get('total_functions')}")
            print(f"Languages: {stats.get('languages')}")
            print(f"Categories: {stats.get('categories')}")
            print("="*70 + "\n")
    except Exception as e:
        print(f"Could not retrieve stats: {str(e)}")

def main() -> int:
    """Main test function"""
    print("\n" + "="*70)
    print("BATCH EXECUTION TEST - MULTI-LANGUAGE FUNCTIONS")
    print("="*70 + "\n")
    
    # Check API availability
    try:
        response = requests.get(f"{LOCAL_API_URL}/health", timeout=5)
        if response.status_code != 200:
            print("✗ Local API not available")
            return 1
    except Exception as e:
        print("✗ Cannot connect to Local API")
        print(f"  Error: {str(e)}")
        return 1
    
    # Get stats
    get_system_stats()
    
    # Execute batch
    success = execute_batch(BATCH_TEST)
    
    if success:
        print("\n" + "="*70)
        print("✓ BATCH EXECUTION TEST PASSED")
        print("="*70 + "\n")
        return 0
    else:
        print("\n" + "="*70)
        print("✗ BATCH EXECUTION TEST FAILED")
        print("="*70 + "\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
