#!/usr/bin/env python3
# ============================================================================
# MIGHTY-POWER LOCAL API CORE ENGINE
# ============================================================================
# Purpose: Multi-language function registry and executor
# Supports: Python, JavaScript, Java, C++, C#, Rust, Ruby
# Date: 2026-07-08
# ============================================================================

import os
import sys
import json
import subprocess
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
import logging
import hashlib
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# ============================================================================
# CONFIGURATION
# ============================================================================

LOG_DIR = Path("./logs")
DATA_DIR = Path("./data")
CACHE_DIR = Path("./cache")

LOG_DIR.mkdir(exist_ok=True)
DATA_DIR.mkdir(exist_ok=True)
CACHE_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / f"api-{datetime.now().strftime('%Y%m%d')}.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("LocalAPI")

# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class FunctionSignature:
    """Function metadata"""
    id: str
    name: str
    language: str
    category: str
    description: str
    source_code: str
    input_params: Dict[str, str]
    output_type: str
    created_at: str = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now().isoformat()

@dataclass
class ExecutionResult:
    """Execution result"""
    function_id: str
    status: str  # success, error, timeout
    output: Any
    error: Optional[str] = None
    execution_time: float = 0.0
    timestamp: str = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now().isoformat()

class FunctionModel(BaseModel):
    id: str
    name: str
    language: str
    category: str
    description: str
    source_code: str
    input_params: Dict[str, str]
    output_type: str

class ExecuteRequest(BaseModel):
    function_id: str
    arguments: Dict[str, Any]

class BatchExecuteRequest(BaseModel):
    functions: List[str]
    arguments: List[Dict[str, Any]]

# ============================================================================
# LANGUAGE EXECUTORS
# ============================================================================

class PythonExecutor:
    """Execute Python functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute Python code with arguments"""
        try:
            # Create temporary Python file
            temp_file = CACHE_DIR / f"exec_{hashlib.md5(code.encode()).hexdigest()}.py"
            
            # Wrap code with argument injection
            wrapped_code = f"""
import json
import sys

def execute_function({', '.join(args.keys())}):
{chr(10).join('    ' + line for line in code.split(chr(10)))}

try:
    result = execute_function({', '.join(f'{k}={repr(v)}' for k, v in args.items())})
    print(json.dumps({{"status": "success", "result": result}}, default=str))
except Exception as e:
    print(json.dumps({{"status": "error", "error": str(e)}}, default=str))
"""
            
            temp_file.write_text(wrapped_code)
            
            # Execute
            process = await asyncio.create_subprocess_exec(
                sys.executable, str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class JavaScriptExecutor:
    """Execute JavaScript functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute JavaScript code with Node.js"""
        try:
            temp_file = CACHE_DIR / f"exec_{hashlib.md5(code.encode()).hexdigest()}.js"
            
            wrapped_code = f"""
const args = {json.dumps(args)};

async function executeFunction() {{
{chr(10).join('  ' + line for line in code.split(chr(10)))}
}}

executeFunction().then(result => {{
  console.log(JSON.stringify({{status: "success", result: result}}, null, 2));
}}).catch(error => {{
  console.log(JSON.stringify({{status: "error", error: error.message}}, null, 2));
}});
"""
            
            temp_file.write_text(wrapped_code)
            
            process = await asyncio.create_subprocess_exec(
                "node", str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class JavaExecutor:
    """Execute Java functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute Java code"""
        try:
            class_name = "ExecutableFunction"
            temp_file = CACHE_DIR / f"{class_name}.java"
            
            wrapped_code = f"""
import java.util.*;
import com.google.gson.Gson;

public class {class_name} {{
    public static void main(String[] args) {{
        try {{
            Map<String, Object> arguments = new HashMap<>();
{chr(10).join(f'            arguments.put("{k}", {repr(v)});' for k, v in args.items())}
            
            Object result = executeFunction(arguments);
            System.out.println(new Gson().toJson(new Object() {{
                public String status = "success";
                public Object result = result;
            }}));
        }} catch (Exception e) {{
            System.out.println(new Gson().toJson(new Object() {{
                public String status = "error";
                public String error = e.getMessage();
            }}));
        }}
    }}
    
    static Object executeFunction(Map<String, Object> args) throws Exception {{
{chr(10).join('        ' + line for line in code.split(chr(10)))}
    }}
}}
"""
            
            temp_file.write_text(wrapped_code)
            
            # Compile
            compile_proc = await asyncio.create_subprocess_exec(
                "javac", str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            await asyncio.wait_for(compile_proc.communicate(), timeout=30.0)
            
            # Execute
            process = await asyncio.create_subprocess_exec(
                "java", "-cp", str(CACHE_DIR), class_name,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class RustExecutor:
    """Execute Rust functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute Rust code"""
        try:
            temp_file = CACHE_DIR / f"main_{hashlib.md5(code.encode()).hexdigest()}.rs"
            
            wrapped_code = f"""
use std::collections::HashMap;

fn main() {{
    let mut args = HashMap::new();
{chr(10).join(f'    args.insert("{k}", r#"{json.dumps(v)}"#);' for k, v in args.items())}
    
    match execute_function(args) {{
        Ok(result) => println!("{{\"status\": \"success\", \"result\": \"{{}}\"}}", result),
        Err(e) => println!("{{\"status\": \"error\", \"error\": \"{{}}\"}}", e),
    }}
}}

fn execute_function(args: HashMap<&str, &str>) -> Result<String, String> {{
{chr(10).join('    ' + line for line in code.split(chr(10)))}
}}
"""
            
            temp_file.write_text(wrapped_code)
            
            # Compile and run with rustc
            process = await asyncio.create_subprocess_exec(
                "rustc", str(temp_file), "-o", str(CACHE_DIR / "main"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            _, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            # Execute compiled binary
            exec_proc = await asyncio.create_subprocess_exec(
                str(CACHE_DIR / "main"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(exec_proc.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class CSharpExecutor:
    """Execute C# functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute C# code with dotnet"""
        try:
            temp_file = CACHE_DIR / f"Program_{hashlib.md5(code.encode()).hexdigest()}.cs"
            
            wrapped_code = f"""
using System;
using System.Collections.Generic;
using System.Text.Json;

class Program {{
    static void Main() {{
        var args = new Dictionary<string, object>() {{
{chr(10).join(f'            {{"{k}", {json.dumps(v)}}}, ' for k, v in args.items())}
        }};
        
        try {{
            var result = ExecuteFunction(args);
            Console.WriteLine(JsonSerializer.Serialize(new {{ status = "success", result = result }}));
        }} catch (Exception ex) {{
            Console.WriteLine(JsonSerializer.Serialize(new {{ status = "error", error = ex.Message }}));
        }}
    }}
    
    static object ExecuteFunction(Dictionary<string, object> args) {{
{chr(10).join('        ' + line for line in code.split(chr(10)))}
    }}
}}
"""
            
            temp_file.write_text(wrapped_code)
            
            process = await asyncio.create_subprocess_exec(
                "dotnet", "run", "--project", str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=str(CACHE_DIR)
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class RubyExecutor:
    """Execute Ruby functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute Ruby code"""
        try:
            temp_file = CACHE_DIR / f"exec_{hashlib.md5(code.encode()).hexdigest()}.rb"
            
            wrapped_code = f"""
require 'json'

args = {json.dumps(args)}

begin
  result = execute_function(args)
  puts JSON.generate({{status: 'success', result: result}})
rescue => e
  puts JSON.generate({{status: 'error', error: e.message}})
end

def execute_function(args)
{chr(10).join('  ' + line for line in code.split(chr(10)))}
end
"""
            
            temp_file.write_text(wrapped_code)
            
            process = await asyncio.create_subprocess_exec(
                "ruby", str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

class CPlusExecutor:
    """Execute C++ functions"""
    
    @staticmethod
    async def execute(code: str, args: Dict[str, Any]) -> Any:
        """Execute C++ code"""
        try:
            temp_file = CACHE_DIR / f"main_{hashlib.md5(code.encode()).hexdigest()}.cpp"
            
            wrapped_code = f"""
#include <iostream>
#include <map>
#include <string>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

int main() {{
    json args = {json.dumps(args)};
    
    try {{
        auto result = executeFunction(args);
        json response = {{{"status", "success"}, {{"result", result}}}};
        std::cout << response.dump() << std::endl;
    }} catch (std::exception& e) {{
        json response = {{{"status", "error"}, {{"error", e.what()}}}};
        std::cout << response.dump() << std::endl;
    }}
    return 0;
}}

json executeFunction(json args) {{
{chr(10).join('    ' + line for line in code.split(chr(10)))}
}}
"""
            
            temp_file.write_text(wrapped_code)
            
            # Compile
            compile_proc = await asyncio.create_subprocess_exec(
                "g++", "-std=c++17", "-o", str(CACHE_DIR / "main"), str(temp_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            _, stderr = await asyncio.wait_for(compile_proc.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            # Execute
            process = await asyncio.create_subprocess_exec(
                str(CACHE_DIR / "main"),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            
            if stderr:
                return {"status": "error", "error": stderr.decode()}
            
            return json.loads(stdout.decode())
            
        except asyncio.TimeoutError:
            return {"status": "error", "error": "Execution timeout"}
        except Exception as e:
            return {"status": "error", "error": str(e)}

# ============================================================================
# FUNCTION REGISTRY
# ============================================================================

class FunctionRegistry:
    """Manage function registration and execution"""
    
    def __init__(self):
        self.functions: Dict[str, FunctionSignature] = {}
        self.load_registry()
    
    def load_registry(self):
        """Load functions from disk"""
        registry_file = DATA_DIR / "registry.json"
        if registry_file.exists():
            with open(registry_file) as f:
                data = json.load(f)
                self.functions = {
                    k: FunctionSignature(**v) for k, v in data.items()
                }
            logger.info(f"Loaded {len(self.functions)} functions from registry")
    
    def save_registry(self):
        """Save functions to disk"""
        registry_file = DATA_DIR / "registry.json"
        data = {k: asdict(v) for k, v in self.functions.items()}
        with open(registry_file, 'w') as f:
            json.dump(data, f, indent=2)
        logger.info(f"Saved {len(self.functions)} functions to registry")
    
    def register(self, func: FunctionSignature):
        """Register a function"""
        self.functions[func.id] = func
        self.save_registry()
        logger.info(f"Registered function: {func.id} ({func.language})")
    
    def get(self, func_id: str) -> Optional[FunctionSignature]:
        """Get function by ID"""
        return self.functions.get(func_id)
    
    def list_functions(self, language: str = None) -> List[FunctionSignature]:
        """List functions, optionally filtered by language"""
        funcs = list(self.functions.values())
        if language:
            funcs = [f for f in funcs if f.language == language]
        return funcs
    
    async def execute(self, func_id: str, args: Dict[str, Any]) -> ExecutionResult:
        """Execute a function"""
        start_time = datetime.now()
        
        func = self.get(func_id)
        if not func:
            return ExecutionResult(
                function_id=func_id,
                status="error",
                output=None,
                error=f"Function not found: {func_id}"
            )
        
        try:
            logger.info(f"Executing function: {func_id} ({func.language})")
            
            executors = {
                "python": PythonExecutor,
                "javascript": JavaScriptExecutor,
                "java": JavaExecutor,
                "rust": RustExecutor,
                "csharp": CSharpExecutor,
                "ruby": RubyExecutor,
                "cpp": CPlusExecutor,
            }
            
            executor_class = executors.get(func.language.lower())
            if not executor_class:
                return ExecutionResult(
                    function_id=func_id,
                    status="error",
                    output=None,
                    error=f"Unsupported language: {func.language}"
                )
            
            result = await executor_class.execute(func.source_code, args)
            
            execution_time = (datetime.now() - start_time).total_seconds()
            
            return ExecutionResult(
                function_id=func_id,
                status=result.get("status", "error"),
                output=result.get("result"),
                error=result.get("error"),
                execution_time=execution_time
            )
            
        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds()
            logger.error(f"Execution error for {func_id}: {str(e)}")
            
            return ExecutionResult(
                function_id=func_id,
                status="error",
                output=None,
                error=str(e),
                execution_time=execution_time
            )

# ============================================================================
# FASTAPI APPLICATION
# ============================================================================

app = FastAPI(
    title="Mighty-Power Local API",
    description="Multi-language function registry and execution engine",
    version="2.0.0"
)

registry = FunctionRegistry()

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """API status"""
    return {
        "status": "running",
        "version": "2.0.0",
        "functions": len(registry.functions),
        "timestamp": datetime.now().isoformat()
    }

@app.post("/functions/register")
async def register_function(func: FunctionModel):
    """Register a new function"""
    try:
        sig = FunctionSignature(
            id=func.id,
            name=func.name,
            language=func.language,
            category=func.category,
            description=func.description,
            source_code=func.source_code,
            input_params=func.input_params,
            output_type=func.output_type
        )
        registry.register(sig)
        
        return {
            "status": "success",
            "message": f"Function registered: {func.id}",
            "function": asdict(sig)
        }
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/functions")
async def list_functions(language: str = None):
    """List all functions"""
    funcs = registry.list_functions(language)
    return {
        "count": len(funcs),
        "functions": [asdict(f) for f in funcs]
    }

@app.get("/functions/{func_id}")
async def get_function(func_id: str):
    """Get function details"""
    func = registry.get(func_id)
    if not func:
        raise HTTPException(status_code=404, detail=f"Function not found: {func_id}")
    
    return asdict(func)

@app.post("/execute")
async def execute_function(request: ExecuteRequest):
    """Execute a function"""
    result = await registry.execute(request.function_id, request.arguments)
    
    return {
        "function_id": result.function_id,
        "status": result.status,
        "output": result.output,
        "error": result.error,
        "execution_time": result.execution_time,
        "timestamp": result.timestamp
    }

@app.post("/execute/batch")
async def batch_execute(request: BatchExecuteRequest):
    """Execute multiple functions"""
    results = []
    
    for func_id, args in zip(request.functions, request.arguments):
        result = await registry.execute(func_id, args)
        results.append({
            "function_id": result.function_id,
            "status": result.status,
            "output": result.output,
            "error": result.error,
            "execution_time": result.execution_time
        })
    
    return {
        "total": len(results),
        "results": results
    }

@app.get("/stats")
async def get_stats():
    """Get system statistics"""
    languages = {}
    for func in registry.functions.values():
        languages[func.language] = languages.get(func.language, 0) + 1
    
    return {
        "total_functions": len(registry.functions),
        "languages": languages,
        "categories": list(set(f.category for f in registry.functions.values())),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "uptime": (datetime.now()).isoformat(),
        "functions": len(registry.functions)
    }

# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    logger.info("╔════════════════════════════════════════════════╗")
    logger.info("║   MIGHTY-POWER LOCAL API v2.0.0              ║")
    logger.info("║   Multi-Language Function Executor           ║")
    logger.info("╚════════════════════════════════════════════════╝")
    
    host = os.getenv("LOCAL_API_HOST", "127.0.0.1")
    port = int(os.getenv("LOCAL_API_PORT", "8000"))
    
    logger.info(f"Starting API server: {host}:{port}")
    logger.info(f"Available languages: Python, JavaScript, Java, Rust, C#, Ruby, C++")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info"
    )
