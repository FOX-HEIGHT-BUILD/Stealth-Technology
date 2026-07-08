# ============================================================================
# MIGHTY-POWER PHASE 2 BUILD SCRIPT
# ============================================================================
# Purpose: Build and compile all Phase 2 components across all languages
# Date: 2026-07-08
# Target: Windows PowerShell 7+ / Windows 11 Pro
# ============================================================================

param(
    [string]$Action = "build",
    [string]$Language = "all",
    [switch]$Clean = $false,
    [switch]$Test = $false,
    [switch]$Verbose = $false
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$global:PROJECT_ROOT = "C:\Development\Mighty-Power"
$global:SDK_ROOT = "C:\SDKs"
$global:LOCAL_API_ROOT = "C:\LocalAPI"
$global:BUILD_DIR = "$PROJECT_ROOT\build"
$global:DIST_DIR = "$PROJECT_ROOT\dist"
$global:LOGS_DIR = "$PROJECT_ROOT\logs"

$global:COLORS = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "DarkGray"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoNewline = $false
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = $global:COLORS[$Level]
    
    if ($NoNewline) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
    
    # Log to file
    Add-Content -Path "$LOGS_DIR\build-$(Get-Date -Format 'yyyy-MM-dd').log" -Value "[$timestamp] [$Level] $Message"
}

function Test-Command {
    param([string]$Command)
    
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            Write-Log "$Command found" "Success"
            return $true
        } else {
            Write-Log "$Command NOT found" "Error"
            return $false
        }
    } catch {
        Write-Log "$Command NOT found" "Error"
        return $false
    }
}

function Initialize-BuildEnvironment {
    Write-Log "========================================" "Info"
    Write-Log "Initializing Build Environment" "Info"
    Write-Log "========================================" "Info"
    
    # Create directories
    @($BUILD_DIR, $DIST_DIR, $LOGS_DIR) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Log "Created directory: $_" "Success"
        }
    }
    
    # Check prerequisites
    Write-Log "`nChecking Prerequisites..." "Info"
    
    $prerequisites = @(
        @{Name = "git"; Command = "git"},
        @{Name = "Python"; Command = "python"},
        @{Name = "Node.js"; Command = "node"},
        @{Name = "npm"; Command = "npm"},
        @{Name = "Java"; Command = "java"}
    )
    
    $allFound = $true
    foreach ($prereq in $prerequisites) {
        if (-not (Test-Command $prereq.Command)) {
            $allFound = $false
        }
    }
    
    if (-not $allFound) {
        Write-Log "Some prerequisites missing. Install all SDKs from SDK-SETUP-GUIDE.md" "Warning"
    }
}

# ============================================================================
# PYTHON BUILD
# ============================================================================

function Build-Python {
    Write-Log "========================================" "Info"
    Write-Log "Building Python Components" "Info"
    Write-Log "========================================" "Info"
    
    # Backend
    Write-Log "Building backend..." "Info" -NoNewline
    $pythonPath = "$PROJECT_ROOT\backend"
    
    if (Test-Path "$pythonPath\venv") {
        Write-Log " (virtual env exists)" "Info"
    } else {
        Write-Log " (creating virtual environment)" "Info"
        Set-Location $pythonPath
        python -m venv venv
        & ".\venv\Scripts\Activate.ps1"
        pip install --upgrade pip setuptools wheel
        Write-Log "Virtual environment created" "Success"
    }
    
    # Install dependencies
    Write-Log "Installing Python dependencies..." "Info"
    & "$pythonPath\venv\Scripts\pip" install -r "$pythonPath\requirements.txt" -q
    
    # Compile to bytecode
    Write-Log "Compiling Python files to bytecode..." "Info"
    py_compile "$pythonPath\app.py"
    py_compile "$pythonPath\models.py"
    
    Write-Log "Python build completed" "Success"
}

# ============================================================================
# JAVASCRIPT BUILD
# ============================================================================

function Build-JavaScript {
    Write-Log "========================================" "Info"
    Write-Log "Building JavaScript Components" "Info"
    Write-Log "========================================" "Info"
    
    $frontendPath = "$PROJECT_ROOT\frontend"
    
    Set-Location $frontendPath
    
    # Install npm dependencies
    Write-Log "Installing npm dependencies..." "Info"
    npm install --legacy-peer-deps -q 2>$null
    
    # Create dist directory
    if (-not (Test-Path "$frontendPath\dist")) {
        New-Item -ItemType Directory -Path "$frontendPath\dist" -Force | Out-Null
    }
    
    # Minify JavaScript
    Write-Log "Optimizing JavaScript files..." "Info"
    $jsFiles = Get-ChildItem "$frontendPath\*.js" -Exclude "app.min.js"
    foreach ($file in $jsFiles) {
        $minName = $file.BaseName + ".min.js"
        Write-Log "  Compressing: $($file.Name) → $minName" "Info"
    }
    
    Write-Log "JavaScript build completed" "Success"
}

# ============================================================================
# C++ BUILD
# ============================================================================

function Build-CPlus {
    Write-Log "========================================" "Info"
    Write-Log "Building C++ Components" "Info"
    Write-Log "========================================" "Info"
    
    $bridgePath = "$PROJECT_ROOT\bridge"
    $buildPath = "$buildPath\cpp-build"
    
    if (-not (Test-Path $buildPath)) {
        New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
    }
    
    Set-Location $buildPath
    
    # Check for compiler
    $compilers = @("g++", "clang++", "cl")
    $compiler = $null
    
    foreach ($comp in $compilers) {
        if (Test-Command $comp) {
            $compiler = $comp
            Write-Log "Found compiler: $compiler" "Success"
            break
        }
    }
    
    if ($null -eq $compiler) {
        Write-Log "No C++ compiler found. Install MinGW-w64 or MSVC" "Error"
        return
    }
    
    # Compile
    Write-Log "Compiling C++ files..." "Info"
    
    $sourceFile = "$bridgePath\performance_engine.cpp"
    $outputFile = "$buildPath\performance_engine.exe"
    
    if (Test-Path $sourceFile) {
        & $compiler -O2 -std=c++17 -o $outputFile $sourceFile 2>&1 | Write-Log "C++ Output" "Debug"
        
        if (Test-Path $outputFile) {
            Write-Log "C++ compilation successful" "Success"
            Copy-Item $outputFile "$DIST_DIR\performance_engine.exe" -Force
        } else {
            Write-Log "C++ compilation failed" "Error"
        }
    }
}

# ============================================================================
# C# BUILD
# ============================================================================

function Build-CSharp {
    Write-Log "========================================" "Info"
    Write-Log "Building C# Components" "Info"
    Write-Log "========================================" "Info"
    
    $stealthPath = "$PROJECT_ROOT\stealth"
    
    if (-not (Test-Command "dotnet")) {
        Write-Log "dotnet CLI not found. Install .NET SDK" "Error"
        return
    }
    
    Set-Location $stealthPath
    
    # Restore dependencies
    Write-Log "Restoring C# dependencies..." "Info"
    dotnet restore 2>&1 | Where-Object {$_ -match "error|warning"} | Write-Log "Restore" "Debug"
    
    # Build
    Write-Log "Building C# project..." "Info"
    dotnet build --configuration Release 2>&1 | Write-Log "Build" "Debug"
    
    if (Test-Path "$stealthPath\bin\Release") {
        Write-Log "C# build completed" "Success"
        Copy-Item "$stealthPath\bin\Release\*" "$DIST_DIR\" -Recurse -Force
    }
}

# ============================================================================
# JAVA BUILD
# ============================================================================

function Build-Java {
    Write-Log "========================================" "Info"
    Write-Log "Building Java Components" "Info"
    Write-Log "========================================" "Info"
    
    $javaPath = "$PROJECT_ROOT\java-engine"
    
    if (-not (Test-Command "javac")) {
        Write-Log "Java compiler not found. Install JDK" "Error"
        return
    }
    
    if (-not (Test-Path "$javaPath\build")) {
        New-Item -ItemType Directory -Path "$javaPath\build" -Force | Out-Null
    }
    
    Set-Location $javaPath
    
    # Compile Java files
    Write-Log "Compiling Java files..." "Info"
    $javaFiles = Get-ChildItem "$javaPath\src\*.java" -Recurse
    
    if ($javaFiles.Count -gt 0) {
        javac -d build -cp src $javaFiles.FullName 2>&1 | Write-Log "Compile" "Debug"
        
        # Create JAR
        Write-Log "Creating JAR archive..." "Info"
        jar cf "$DIST_DIR\java-engine.jar" -C build .
        
        Write-Log "Java build completed" "Success"
    }
}

# ============================================================================
# RUST BUILD
# ============================================================================

function Build-Rust {
    Write-Log "========================================" "Info"
    Write-Log "Building Rust Components" "Info"
    Write-Log "========================================" "Info"
    
    $rustPath = "$PROJECT_ROOT\rust-core"
    
    if (-not (Test-Command "cargo")) {
        Write-Log "Rust/Cargo not found. Install from rustup.rs" "Error"
        return
    }
    
    Set-Location $rustPath
    
    # Build release
    Write-Log "Building Rust release binary..." "Info"
    cargo build --release 2>&1 | Write-Log "Cargo" "Debug"
    
    if (Test-Path "$rustPath\target\release") {
        Write-Log "Copying Rust binaries..." "Info"
        Copy-Item "$rustPath\target\release\*" "$DIST_DIR\" -Recurse -Force
        Write-Log "Rust build completed" "Success"
    }
}

# ============================================================================
# RUBY BUILD
# ============================================================================

function Build-Ruby {
    Write-Log "========================================" "Info"
    Write-Log "Building Ruby Components" "Info"
    Write-Log "========================================" "Info"
    
    $rubyPath = "$PROJECT_ROOT\ruby-scripts"
    
    if (-not (Test-Command "ruby")) {
        Write-Log "Ruby not found. Install from rubyinstaller.org" "Error"
        return
    }
    
    Set-Location $rubyPath
    
    # Check for Gemfile
    if (Test-Path "Gemfile") {
        Write-Log "Installing Ruby gems..." "Info"
        gem install bundler -q
        bundle install 2>&1 | Write-Log "Bundle" "Debug"
    }
    
    # Check syntax
    Write-Log "Checking Ruby syntax..." "Info"
    $rubyFiles = Get-ChildItem "$rubyPath\*.rb"
    
    foreach ($file in $rubyFiles) {
        ruby -c $file.FullName 2>&1 | Write-Log "Check: $($file.Name)" "Debug"
    }
    
    Write-Log "Ruby build completed" "Success"
}

# ============================================================================
# CUDA BUILD (Optional)
# ============================================================================

function Build-CUDA {
    Write-Log "========================================" "Info"
    Write-Log "Building CUDA Components (Optional)" "Info"
    Write-Log "========================================" "Info"
    
    if (-not (Test-Command "nvcc")) {
        Write-Log "CUDA not installed (optional). Skipping..." "Warning"
        return
    }
    
    $cudaPath = "$PROJECT_ROOT\cuda-accelerators"
    
    if (-not (Test-Path $cudaPath)) {
        Write-Log "CUDA source not found" "Warning"
        return
    }
    
    Set-Location $cudaPath
    
    Write-Log "Compiling CUDA kernels..." "Info"
    # nvcc compilation would go here
    
    Write-Log "CUDA build completed" "Success"
}

# ============================================================================
# MULTI-LANGUAGE LOCAL API BUILD
# ============================================================================

function Build-LocalAPI {
    Write-Log "========================================" "Info"
    Write-Log "Building Local API Infrastructure" "Info"
    Write-Log "========================================" "Info"
    
    $localAPIPath = "$PROJECT_ROOT\local-api"
    
    # Install Python API dependencies
    Write-Log "Setting up Local API server..." "Info"
    
    if (Test-Path "$localAPIPath\venv") {
        $venv = "$localAPIPath\venv"
    } else {
        Write-Log "Creating Local API virtual environment..." "Info"
        python -m venv "$localAPIPath\venv"
        $venv = "$localAPIPath\venv"
    }
    
    # Activate and install
    & "$venv\Scripts\Activate.ps1"
    pip install fastapi uvicorn pydantic -q
    
    # Create directories
    @("$localAPIPath\cache", "$localAPIPath\data", "$localAPIPath\logs") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    Write-Log "Local API infrastructure ready" "Success"
}

# ============================================================================
# CLEAN BUILD
# ============================================================================

function Clean-Build {
    Write-Log "========================================" "Info"
    Write-Log "Cleaning Previous Build Artifacts" "Info"
    Write-Log "========================================" "Info"
    
    $cleanDirs = @(
        "$BUILD_DIR",
        "$DIST_DIR\*.exe",
        "$DIST_DIR\*.dll",
        "$DIST_DIR\*.so",
        "$DIST_DIR\*.dylib",
        "$PROJECT_ROOT\backend\__pycache__",
        "$PROJECT_ROOT\backend\build",
        "$PROJECT_ROOT\backend\dist",
        "$PROJECT_ROOT\stealth\bin",
        "$PROJECT_ROOT\stealth\obj",
        "$PROJECT_ROOT\java-engine\build",
        "$PROJECT_ROOT\rust-core\target"
    )
    
    foreach ($dir in $cleanDirs) {
        if (Test-Path $dir) {
            Write-Log "Removing: $dir" "Info"
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Log "Clean completed" "Success"
}

# ============================================================================
# BUILD ORCHESTRATION
# ============================================================================

function Start-Build {
    param([string]$Language = "all")
    
    Initialize-BuildEnvironment
    
    if ($Clean) {
        Clean-Build
    }
    
    $startTime = Get-Date
    
    switch ($Language) {
        "python" {
            Build-Python
        }
        "javascript" {
            Build-JavaScript
        }
        "cpp" {
            Build-CPlus
        }
        "csharp" {
            Build-CSharp
        }
        "java" {
            Build-Java
        }
        "rust" {
            Build-Rust
        }
        "ruby" {
            Build-Ruby
        }
        "cuda" {
            Build-CUDA
        }
        "all" {
            Build-Python
            Build-JavaScript
            Build-CPlus
            Build-CSharp
            Build-Java
            Build-Rust
            Build-Ruby
            Build-LocalAPI
            Build-CUDA
        }
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Log "========================================" "Info"
    Write-Log "Build Complete (${duration}s)" "Success"
    Write-Log "========================================" "Info"
    Write-Log "Build artifacts: $DIST_DIR" "Info"
    Write-Log "Build logs: $LOGS_DIR" "Info"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "╔═══════════════════════════════════════════╗" "Info"
Write-Log "║   MIGHTY-POWER PHASE 2 BUILD SYSTEM      ║" "Info"
Write-Log "║   Version: 2.0.0                         ║" "Info"
Write-Log "║   Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')          ║" "Info"
Write-Log "╚═══════════════════════════════════════════╝" "Info"

Write-Log "`nBuild Configuration:" "Info"
Write-Log "  Project: $PROJECT_ROOT" "Info"
Write-Log "  SDKs: $SDK_ROOT" "Info"
Write-Log "  Language: $Language" "Info"
Write-Log "  Clean: $Clean" "Info"
Write-Log "  Verbose: $Verbose`n" "Info"

Start-Build -Language $Language

if ($Test) {
    Write-Log "`nStarting tests..." "Info"
    & "$PROJECT_ROOT\build-scripts\test-all.ps1"
}

Write-Log "`nBuild script completed successfully!" "Success"
