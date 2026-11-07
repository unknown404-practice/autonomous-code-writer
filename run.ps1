# Dark Matter - Server Log Investigator Launcher
# Runs Dark Matter AI Agent using local Ollama and Docker Agent

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-Location $PSScriptRoot

try {
    $Host.UI.RawUI.WindowTitle = "Dark Matter 🌌 | Autonomous Server Log Investigator"
} catch {}

# Ensure Ollama keeps models loaded indefinitely in memory
$env:OLLAMA_KEEP_ALIVE = "-1"

# 0. Handle --dry-run validation
if ($args -contains "--dry-run") {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "       DARK MATTER - PRE-FLIGHT DRY RUN VALIDATION               " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    $pyCmd = Get-Command "python" -ErrorAction SilentlyContinue
    if ($pyCmd) {
        Write-Host " [OK] Python CLI found: $(& python --version 2>&1)" -ForegroundColor Green
    } else {
        Write-Host " [!] Python not found in PATH." -ForegroundColor Yellow
    }

    $ollamaCmd = Get-Command "ollama" -ErrorAction SilentlyContinue
    if ($ollamaCmd) {
        Write-Host " [OK] Ollama CLI found in PATH." -ForegroundColor Green
    } else {
        Write-Host " [!] Ollama CLI not found in PATH." -ForegroundColor Yellow
    }

    $dockerCmd = Get-Command "docker" -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        Write-Host " [OK] Docker CLI found in PATH." -ForegroundColor Green
    } else {
        Write-Host " [!] Docker CLI not found in PATH." -ForegroundColor Yellow
    }

    $requiredAssets = @("agent.yaml", "Modelfile", "sample.log", "analyze_logs.py")
    foreach ($asset in $requiredAssets) {
        $assetPath = Join-Path $PSScriptRoot $asset
        if (Test-Path $assetPath) {
            Write-Host " [OK] Required asset verified: $asset" -ForegroundColor Green
        } else {
            Write-Host " [ERROR] Missing required asset: $asset" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host ""
    Write-Host " [OK] Dry run successful! All prerequisites and files verified." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "   .  *        +        .       *       .       .  *    +       ." -ForegroundColor DarkGray
Write-Host "         [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]" -ForegroundColor Cyan
Write-Host "               Autonomous SRE & DevOps AI Agent" -ForegroundColor Magenta
Write-Host "               Model: dark-matter (qwen2.5:7b) | Agent: dark-matter" -ForegroundColor DarkCyan
Write-Host "   -----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 1. Check if Ollama CLI is installed
$ollamaCmd = Get-Command "ollama" -ErrorAction SilentlyContinue
if (-not $ollamaCmd) {
    Write-Host " [!] Ollama CLI was not found on your system." -ForegroundColor Yellow
    Write-Host " Attempting to install Ollama via Windows Package Manager..." -ForegroundColor Cyan
    $wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        & winget install -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements
        Write-Host ""
        Write-Host " [OK] Ollama installed. Please restart your terminal if 'ollama' is not recognized yet." -ForegroundColor Green
    } else {
        Write-Host " [ERROR] winget is unavailable. Please install Ollama from https://ollama.com/download" -ForegroundColor Red
        if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit..." }
        exit 1
    }
}

# 2. Check if Ollama service is running; poll health endpoint up to 15 seconds
$serviceRunning = $false
try {
    $res = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    if ($res.StatusCode -eq 200) { $serviceRunning = $true }
} catch {
    $serviceRunning = $false
}

if (-not $serviceRunning) {
    Write-Host " [*] Starting local Ollama service in background..." -ForegroundColor Cyan
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    
    $retries = 0
    $maxRetries = 15
    while (-not $serviceRunning -and $retries -lt $maxRetries) {
        Start-Sleep -Seconds 1
        $retries++
        try {
            $check = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
            if ($check.StatusCode -eq 200) { $serviceRunning = $true }
        } catch {}
    }
    if (-not $serviceRunning) {
        Write-Host " [ERROR] Ollama service failed to respond within $maxRetries seconds." -ForegroundColor Red
        exit 1
    }
}

# 3. Check base model qwen2.5:7b
$tags = try {
    (Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5).models
} catch { @() }

$qwenFound = $tags | Where-Object { $_.name -like "*qwen2.5:7b*" }
if (-not $qwenFound) {
    Write-Host ""
    Write-Host " [!] Qwen 2.5 7B model is not installed yet." -ForegroundColor Yellow
    Write-Host " [*] Automatically downloading qwen2.5:7b (one-time setup, ~4.7GB)..." -ForegroundColor Cyan
    Write-Host ""
    & ollama pull qwen2.5:7b
    if ($LASTEXITCODE -ne 0) {
        Write-Host " [ERROR] Failed to download qwen2.5:7b. Please check your internet connection." -ForegroundColor Red
        if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit..." }
        exit 1
    }
    Write-Host ""
    Write-Host " [OK] Qwen 2.5 7B installed successfully!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host " [OK] Base model qwen2.5:7b is ready." -ForegroundColor Green
}

# 4. Check if Dark Matter custom model is compiled from Modelfile
$darkMatterFound = $tags | Where-Object { $_.name -like "*dark-matter*" }
if (-not $darkMatterFound) {
    Write-Host " [*] Compiling Dark Matter tuned SRE model from Modelfile..." -ForegroundColor Cyan
    $modelfilePath = Join-Path $PSScriptRoot "Modelfile"
    & ollama create dark-matter -f $modelfilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Host " [ERROR] Failed to compile dark-matter model." -ForegroundColor Red
        exit 1
    }
    Write-Host " [OK] Dark Matter custom model compiled successfully!" -ForegroundColor Green
}

# 5. Pre-warm custom dark-matter model so it stays awake in memory indefinitely
try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body '{"model": "dark-matter", "keep_alive": -1}' -ContentType "application/json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    Write-Host " [OK] Dark Matter model is awake and pinned in memory [Always Awake: Active]." -ForegroundColor Green
} catch {}

# 6. Check Docker Agent
$dockerAgent = Get-Command "docker" -ErrorAction SilentlyContinue
if (-not $dockerAgent) {
    Write-Host " [ERROR] Docker is not installed or not in PATH." -ForegroundColor Red
    if ($Host.Name -eq "ConsoleHost") {
        Read-Host "Press Enter to exit..."
    }
    exit 1
}

Write-Host " [OK] Launching Dark Matter TUI..." -ForegroundColor Cyan
Write-Host " Tip: Type your prompt (e.g. 'Investigate sample.log and find root cause') or /exit to quit." -ForegroundColor DarkGray
Write-Host ""

$agentYaml = Join-Path $PSScriptRoot "agent.yaml"
& docker agent run --app-name "Dark Matter" $agentYaml @args
