# Dark Matter - Server Log Investigator Launcher
# Runs Dark Matter AI Agent using local Ollama (qwen2.5:7b)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-Location $PSScriptRoot

try {
    $Host.UI.RawUI.WindowTitle = "Dark Matter 🌌 | Autonomous Server Log Investigator"
} catch {}

# Ensure Ollama keeps models loaded indefinitely in memory
$env:OLLAMA_KEEP_ALIVE = "-1"

# Ensure user config preserves banner display
$configDir = "$HOME\.config\cagent"
$configFile = "$configDir\config.yaml"
try {
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $configFile)) {
        Set-Content -Path $configFile -Value "version: v1`nsettings:`n  theme: gruvbox-dark`n  show_banner: true" -Encoding UTF8
    } else {
        $cfg = Get-Content -Path $configFile -Raw
        if ($cfg -match "show_banner:\s*false") {
            $cfg = $cfg -replace "show_banner:\s*false", "show_banner: true"
            Set-Content -Path $configFile -Value $cfg -Encoding UTF8
        }
    }
} catch {}

Write-Host ""
Write-Host "   .  *        +        .       *       .       .  *    +       ." -ForegroundColor DarkGray
Write-Host "         [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]" -ForegroundColor Cyan
Write-Host "               Autonomous SRE & DevOps AI Agent" -ForegroundColor Magenta
Write-Host "               Model: qwen2.5:7b [Local Ollama] | Agent: dark-matter" -ForegroundColor DarkCyan
Write-Host "   -----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# 1. Check if Ollama CLI is installed
$ollamaCmd = Get-Command "ollama" -ErrorAction SilentlyContinue
if (-not $ollamaCmd) {
    Write-Host " [!] Ollama CLI was not found on your system." -ForegroundColor Yellow
    $wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-Host " [*] Attempting to install Ollama via Windows Package Manager (winget)..." -ForegroundColor Cyan
        & winget install -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements
        Write-Host " [OK] Ollama installed. If command is not recognized, please restart your terminal." -ForegroundColor Green
    } else {
        Write-Host " [ERROR] Please install Ollama from https://ollama.com/download" -ForegroundColor Red
        if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit..." }
        exit 1
    }
}

# 2. Check if Ollama service is running
$ollamaOnline = $false
try {
    $ollamaTags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method Get -TimeoutSec 3 -ErrorAction Stop
    $ollamaOnline = $true
} catch {
    Write-Host " [*] Starting local Ollama service in background..." -ForegroundColor Yellow
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    try {
        $ollamaTags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        $ollamaOnline = $true
    } catch {
        $ollamaTags = $null
    }
}

# 3. Check if Qwen 2.5 7B model is installed; if not, automatically pull it
$qwenFound = $false
if ($ollamaTags -and $ollamaTags.models) {
    $qwenFound = $ollamaTags.models | Where-Object { $_.name -like "*qwen2.5:7b*" }
}

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
    Write-Host " [OK] Local Ollama is online with qwen2.5:7b ready." -ForegroundColor Green
}

# 4. Pre-warm Qwen 2.5 7B so it stays awake in memory indefinitely (Zero Cold-Start)
try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body '{"model": "qwen2.5:7b", "keep_alive": -1}' -ContentType "application/json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    Write-Host " [OK] Qwen 2.5 7B is awake and pinned in memory [Always Awake: Active]." -ForegroundColor Green
} catch {}

# 5. Check Docker Agent
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
