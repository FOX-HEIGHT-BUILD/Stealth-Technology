#!/usr/bin/env python3
# ============================================================================
# TEST MULTI-LANGUAGE FUNCTION EXECUTION
# ============================================================================
# Purpose: Test execution of all registered multi-language functions
# Date: 2026-07-08
# ============================================================================

import requests
import json
import sys
from typing import Dict, Any
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

LOCAL_API_URL = "http://127.0.0.1:8000"

# ============================================================================
# TEST CASES
# ============================================================================

TEST_CASES = [
    {
        "id": "py-array-sum-optimized",
        "name": "Python: Array Sum",
        "arguments": {"numbers": [1, 2, 3, 4, 5, 10, 20, 30]}
    },
    {
        "id": "js-string-analyzer",
        "name": "JavaScript: String Analysis",
        "arguments": {"text": "Hello World! This is JavaScript. Visit https://example.com"}
    },
    {
        "id": "java-matrix-multiply",
        "name": "Java: Matrix Multiplication",
        "arguments": {"matrix1": [[1, 2, 3], [4, 5, 6]], "matrix2": [[7, 8], [9, 10], [11, 12]]}
    },
    {
        "id": "cpp-merge-sort",
        "name": "C++: Merge Sort",
        "arguments": {"numbers": [64, 34, 25, 12, 22, 11, 90, 88, 45]}
    },
    {
        "id": "cs-stealth-cipher",
        "name": "C#: Stealth Encryption",
        "arguments": {"plaintext": "Secret stealth message", "key": "mighty_power_2026"}
    },
    {
        "id": "rs-parallel-compute",
        "name": "Rust: Parallel Compute",
        "arguments": {"numbers": [10, 20, 30, 40, 50], "operation": "average"}
    },
    {
        "id": "rb-dynamic-data-processor",
        "name": "Ruby: Data Transform",
        "arguments": {"data_hash": {"name": "stealth", "status": "active", "value": 42}, "transformations": ["uppercase", "doubled"]}
    },
]

# ============================================================================
# EXECUTION FUNCTIONS
# ============================================================================

def execute_function(func_id: str, arguments: Dict[str, Any]) -> bool:
    """Execute a single function"""
    try:
        response = requests.post(
            f"{LOCAL_API_URL}/execute",
            json={"function_id": func_id, "arguments": arguments},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            status = result.get("status", "unknown")
            execution_time = result.get("execution_time", 0)
            
            print(f"✓ Status: {status:10} | Time: {execution_time*1000:8.2f}ms")
            return True
        else:
            print(f"✗ HTTP {response.status_code}: {response.text[:100]}")
            return False
    except Exception as e:
        print(f"✗ Error: {str(e)[:100]}")
        return False

def test_all_functions() -> int:
    """Test all functions"""
    print("\n" + "="*70)
    print("TESTING MULTI-LANGUAGE FUNCTION EXECUTION")
    print("="*70 + "\n")
    
    # Check API availability
    try:
        response = requests.get(f"{LOCAL_API_URL}/health", timeout=5)
        if response.status_code != 200:
            print("✗ Local API not available")
            return 0
    except Exception as e:
        print("✗ Cannot connect to Local API")
        print(f"  Error: {str(e)}")
        return 0
    
    passed = 0
    
    for test in TEST_CASES:
        print(f"Testing: {test['name']:40s} ", end="")
        if execute_function(test["id"], test["arguments"]):
            passed += 1
        time.sleep(0.5)
    
    print(f"\n" + "="*70)
    print(f"RESULTS: {passed}/{len(TEST_CASES)} tests passed")
    print("="*70 + "\n")
    
    return passed

if __name__ == "__main__":
    passed = test_all_functions()
    sys.exit(0 if passed == len(TEST_CASES) else 1)
