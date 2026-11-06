@echo off
setlocal enabledelayedexpansion

:: Switch to UTF-8 encoding
chcp 65001 >nul 2>&1

:: Always navigate to the Dark Matter root directory
cd /d "%~dp0"

title Dark Matter 🌌 ^| Autonomous Server Log Investigator

:: Ensure Ollama keeps model in memory indefinitely (Always Awake)
set OLLAMA_KEEP_ALIVE=-1

echo.
echo    .  *        +        .       *       .       .  *    +       .
echo          [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]
echo                Autonomous SRE ^& DevOps AI Agent
echo                Model: qwen2.5:7b [Local Ollama] ^| Agent: dark-matter
echo    -----------------------------------------------------------------
echo.

:: 1. Check if Ollama CLI is installed
where ollama >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [!] Ollama was not found on your system.
    echo  Attempting to install Ollama via Windows Package Manager...
    where winget >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        winget install -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements
        echo.
        echo  [OK] Ollama installed. Please restart this terminal if Ollama is not yet in PATH.
    ) else (
        echo  Please download and install Ollama from https://ollama.com/download
        pause
        exit /b 1
    )
)

:: 2. Ensure Ollama service is running
curl -s -m 2 http://127.0.0.1:11434/api/tags >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [*] Starting local Ollama service in background...
    start "" /b ollama serve >nul 2>&1
    timeout /t 3 /nobreak >nul 2>&1
)

:: 3. Check if Qwen 2.5 7B model is installed; if not, automatically pull it
ollama list | findstr /i "qwen2.5:7b" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo  [!] Qwen 2.5 7B model is not installed yet.
    echo  [*] Automatically downloading qwen2.5:7b - one-time setup, ~4.7GB...
    echo.
    ollama pull qwen2.5:7b
    if !ERRORLEVEL! neq 0 (
        echo.
        echo  [ERROR] Failed to download qwen2.5:7b. Please check your internet connection.
        pause
        exit /b 1
    )
    echo.
    echo  [OK] Qwen 2.5 7B installed successfully!
    echo.
) else (
    echo  [OK] Local Ollama is online with qwen2.5:7b ready.
)

:: 4. Pre-warm Qwen 2.5 7B so it stays awake in memory indefinitely (Zero Cold-Start)
curl -s -m 5 -X POST http://127.0.0.1:11434/api/generate -d "{\"model\": \"qwen2.5:7b\", \"keep_alive\": -1}" >nul 2>&1
echo  [OK] Qwen 2.5 7B is awake and pinned in memory [Always Awake: Active].

:: 5. Check if Docker is available
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo  [ERROR] Docker CLI was not found in your PATH.
    echo  Please ensure Docker Desktop is installed and added to PATH.
    echo.
    pause
    exit /b 1
)

echo  [OK] Launching Dark Matter TUI...
echo.

:: 6. Run Dark Matter Agent
docker agent run --app-name "Dark Matter" "%~dp0agent.yaml" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [!] Dark Matter exited with code %ERRORLEVEL%.
    echo  Press any key to close this window...
    pause >nul
)
