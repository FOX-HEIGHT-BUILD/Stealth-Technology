# ============================================================================
# MIGHTY-POWER ENVIRONMENT SETUP
# ============================================================================
# Purpose: Configure all environment variables and paths for Phase 2
# Date: 2026-07-08
# Target: Windows PowerShell 7+ (Run as Administrator)
# ============================================================================

param(
    [switch]$Permanent = $false,
    [switch]$Verify = $false
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$global:SDK_PATHS = @{
    PYTHON_HOME = "C:\SDKs\Python-3.11"
    NODEJS_HOME = "C:\SDKs\node-v18"
    JAVA_HOME = "C:\SDKs\jdk-11"
    RUST_HOME = "$env:USERPROFILE\.cargo"
    RUBY_HOME = "C:\SDKs\ruby-3.2"
    DOTNET_ROOT = "C:\Program Files\dotnet"
    MINGW_HOME = "C:\SDKs\mingw-w64"
    GIT_HOME = "C:\Program Files\Git"
    CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0"
}

$global:PROJECT_ROOT = "C:\Development\Mighty-Power"
$global:LOCAL_API_ROOT = "C:\LocalAPI"
$global:COLORS = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-Setup {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = $global:COLORS[$Status]
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-EnvironmentVariable {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Scope = "User"
    )
    
    if ($Permanent) {
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        Write-Setup "Set permanent: $Name = $Value" "Success"
    } else {
        $env:$Name = $Value
        Write-Setup "Set session: $Name = $Value" "Success"
    }
}

function Add-PathEntry {
    param(
        [string]$PathEntry
    )
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    if ($currentPath -notlike "*$PathEntry*") {
        $newPath = "$currentPath;$PathEntry"
        
        if ($Permanent) {
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Setup "Added to PATH: $PathEntry" "Success"
        } else {
            $env:PATH = "$env:PATH;$PathEntry"
            Write-Setup "Added to session PATH: $PathEntry" "Success"
        }
    } else {
        Write-Setup "Already in PATH: $PathEntry" "Warning"
    }
}

# ============================================================================
# PYTHON SETUP
# ============================================================================

function Setup-Python {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Python Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $pythonHome = $global:SDK_PATHS.PYTHON_HOME
    
    if (-not (Test-Path $pythonHome)) {
        Write-Setup "Python not found at: $pythonHome" "Error"
        Write-Setup "Install from: https://www.python.org/downloads/" "Info"
        return
    }
    
    Set-EnvironmentVariable "PYTHON_HOME" $pythonHome
    Add-PathEntry "$pythonHome"
    Add-PathEntry "$pythonHome\Scripts"
    
    Write-Setup "Python environment configured" "Success"
}

# ============================================================================
# NODE.JS SETUP
# ============================================================================

function Setup-NodeJS {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Node.js Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $nodeHome = $global:SDK_PATHS.NODEJS_HOME
    
    if (-not (Test-Path $nodeHome)) {
        Write-Setup "Node.js not found at: $nodeHome" "Error"
        Write-Setup "Install from: https://nodejs.org/" "Info"
        return
    }
    
    Set-EnvironmentVariable "NODEJS_HOME" $nodeHome
    Add-PathEntry $nodeHome
    
    # npm global directory
    $npmGlobal = "$env:APPDATA\npm"
    Add-PathEntry $npmGlobal
    
    Write-Setup "Node.js environment configured" "Success"
}

# ============================================================================
# JAVA SETUP
# ============================================================================

function Setup-Java {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Java Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $javaHome = $global:SDK_PATHS.JAVA_HOME
    
    if (-not (Test-Path $javaHome)) {
        Write-Setup "Java not found at: $javaHome" "Error"
        Write-Setup "Install from: https://adoptium.net/" "Info"
        return
    }
    
    Set-EnvironmentVariable "JAVA_HOME" $javaHome
    Add-PathEntry "$javaHome\bin"
    
    Write-Setup "Java environment configured" "Success"
}

# ============================================================================
# C++ SETUP
# ============================================================================

function Setup-CPlus {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring C++ Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $mingwHome = $global:SDK_PATHS.MINGW_HOME
    
    if (-not (Test-Path $mingwHome)) {
        Write-Setup "MinGW not found at: $mingwHome" "Error"
        Write-Setup "Install from: https://www.mingw-w64.org/" "Info"
        return
    }
    
    Set-EnvironmentVariable "MINGW_HOME" $mingwHome
    Add-PathEntry "$mingwHome\bin"
    
    Write-Setup "C++ environment configured" "Success"
}

# ============================================================================
# C# .NET SETUP
# ============================================================================

function Setup-DotNet {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring .NET Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $dotnetRoot = $global:SDK_PATHS.DOTNET_ROOT
    
    if (-not (Test-Path $dotnetRoot)) {
        Write-Setup ".NET not found at: $dotnetRoot" "Error"
        Write-Setup "Install from: https://dotnet.microsoft.com/download" "Info"
        return
    }
    
    Set-EnvironmentVariable "DOTNET_ROOT" $dotnetRoot
    Add-PathEntry $dotnetRoot
    
    Write-Setup ".NET environment configured" "Success"
}

# ============================================================================
# RUST SETUP
# ============================================================================

function Setup-Rust {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Rust Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $rustHome = $global:SDK_PATHS.RUST_HOME
    
    if (-not (Test-Path "$rustHome\bin")) {
        Write-Setup "Rust not found. Installing..." "Warning"
        Write-Setup "Run: https://rustup.rs/" "Info"
        return
    }
    
    Set-EnvironmentVariable "RUST_HOME" $rustHome
    Add-PathEntry "$rustHome\bin"
    
    Write-Setup "Rust environment configured" "Success"
}

# ============================================================================
# RUBY SETUP
# ============================================================================

function Setup-Ruby {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Ruby Environment" "Info"
    Write-Setup "========================================" "Info"
    
    $rubyHome = $global:SDK_PATHS.RUBY_HOME
    
    if (-not (Test-Path $rubyHome)) {
        Write-Setup "Ruby not found at: $rubyHome" "Error"
        Write-Setup "Install from: https://rubyinstaller.org/" "Info"
        return
    }
    
    Set-EnvironmentVariable "RUBY_HOME" $rubyHome
    Add-PathEntry "$rubyHome\bin"
    
    Write-Setup "Ruby environment configured" "Success"
}

# ============================================================================
# CUDA SETUP (Optional)
# ============================================================================

function Setup-CUDA {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring CUDA Environment (Optional)" "Info"
    Write-Setup "========================================" "Info"
    
    $cudaHome = $global:SDK_PATHS.CUDA_HOME
    
    if (-not (Test-Path $cudaHome)) {
        Write-Setup "CUDA not found (optional). Skipping..." "Warning"
        return
    }
    
    Set-EnvironmentVariable "CUDA_HOME" $cudaHome
    Add-PathEntry "$cudaHome\bin"
    Add-PathEntry "$cudaHome\libnvvp"
    
    Write-Setup "CUDA environment configured" "Success"
}

# ============================================================================
# LOCAL API SETUP
# ============================================================================

function Setup-LocalAPI {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Local API Environment" "Info"
    Write-Setup "========================================" "Info"
    
    # Create Local API directories
    @("$LOCAL_API_ROOT\api-core", "$LOCAL_API_ROOT\api-cache", "$LOCAL_API_ROOT\api-data", "$LOCAL_API_ROOT\api-logs") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Setup "Created: $_" "Success"
        }
    }
    
    Set-EnvironmentVariable "LOCAL_API_ROOT" $LOCAL_API_ROOT
    Set-EnvironmentVariable "LOCAL_API_HOST" "127.0.0.1"
    Set-EnvironmentVariable "LOCAL_API_PORT" "8000"
    Set-EnvironmentVariable "LOCAL_API_DEBUG" "true"
    
    Write-Setup "Local API environment configured" "Success"
}

# ============================================================================
# PROJECT SETUP
# ============================================================================

function Setup-Project {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Configuring Project Environment" "Info"
    Write-Setup "========================================" "Info"
    
    # Create project directories
    @("$PROJECT_ROOT\build", "$PROJECT_ROOT\dist", "$PROJECT_ROOT\logs") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Setup "Created: $_" "Success"
        }
    }
    
    Set-EnvironmentVariable "PROJECT_ROOT" $PROJECT_ROOT
    Set-EnvironmentVariable "BUILD_DIR" "$PROJECT_ROOT\build"
    Set-EnvironmentVariable "DIST_DIR" "$PROJECT_ROOT\dist"
    
    Write-Setup "Project environment configured" "Success"
}

# ============================================================================
# VERIFICATION
# ============================================================================

function Verify-Environment {
    Write-Setup "`n========================================" "Info"
    Write-Setup "Verifying Environment Configuration" "Info"
    Write-Setup "========================================" "Info"
    
    $tools = @(
        @{Name = "Python"; Command = "python"; Args = "--version"}
        @{Name = "Node.js"; Command = "node"; Args = "--version"}
        @{Name = "npm"; Command = "npm"; Args = "--version"}
        @{Name = "Java"; Command = "java"; Args = "-version"}
        @{Name = "Rust"; Command = "rustc"; Args = "--version"}
        @{Name = "Ruby"; Command = "ruby"; Args = "--version"}
        @{Name = "Git"; Command = "git"; Args = "--version"}
    )
    
    foreach ($tool in $tools) {
        try {
            $output = & $tool.Command $tool.Args 2>&1
            Write-Setup "✓ $($tool.Name): $($output[0])" "Success"
        } catch {
            Write-Setup "✗ $($tool.Name): Not found" "Error"
        }
    }
    
    # Verify paths
    Write-Setup "`nVerifying PATH entries:" "Info"
    $pathEntries = $env:PATH -split ";"
    Write-Setup "  Total entries: $($pathEntries.Count)" "Info"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Setup "╔═══════════════════════════════════════════╗" "Info"
Write-Setup "║   MIGHTY-POWER ENVIRONMENT SETUP         ║" "Info"
Write-Setup "║   Version: 2.0.0                         ║" "Info"
Write-Setup "╚═══════════════════════════════════════════╝" "Info"

if (-not (Test-Admin)) {
    Write-Setup "`n⚠ WARNING: This script should be run as Administrator for permanent changes" "Warning"
    Write-Setup "For permanent configuration, run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" "Warning"
}

Write-Setup "`nConfiguration Mode:" "Info"
if ($Permanent) {
    Write-Setup "  Type: Permanent (User scope)" "Info"
} else {
    Write-Setup "  Type: Session only" "Info"
}

# Run setup
Setup-Python
Setup-NodeJS
Setup-Java
Setup-CPlus
Setup-DotNet
Setup-Rust
Setup-Ruby
Setup-CUDA
Setup-LocalAPI
Setup-Project

if ($Verify) {
    Verify-Environment
}

Write-Setup "`n╔═══════════════════════════════════════════╗" "Info"
Write-Setup "║   ENVIRONMENT SETUP COMPLETED            ║" "Info"
Write-Setup "╚═══════════════════════════════════════════╝" "Info"

Write-Setup "`nNext steps:" "Info"
Write-Setup "  1. Verify all tools installed: .\config\environment-setup.ps1 -Verify" "Info"
Write-Setup "  2. Build all components: .\build-scripts\build-all.ps1" "Info"
Write-Setup "  3. Run all tests: .\build-scripts\test-all.ps1" "Info"
Write-Setup "  4. Start Local API: cd local-api && python local_api_core.py" "Info"
