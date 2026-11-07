@echo off
setlocal enabledelayedexpansion

:: Switch to UTF-8 encoding
chcp 65001 >nul 2>&1

:: Always navigate to the Dark Matter root directory
cd /d "%~dp0"

title Dark Matter 🌌 ^| Autonomous Server Log Investigator

:: Ensure Ollama keeps model in memory indefinitely (Always Awake)
set OLLAMA_KEEP_ALIVE=-1

:: 0. Check for --dry-run argument
echo "%*" | findstr /i "\-\-dry\-run" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo.
    echo =================================================================
    echo        DARK MATTER - PRE-FLIGHT DRY RUN VALIDATION               
    echo =================================================================
    echo.
    where python >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo  [OK] Python CLI found.
    ) else (
        echo  [!] Python not found in PATH.
    )
    where ollama >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo  [OK] Ollama CLI found.
    ) else (
        echo  [!] Ollama not found in PATH.
    )
    where docker >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo  [OK] Docker CLI found.
    ) else (
        echo  [!] Docker not found in PATH.
    )
    if exist "%~dp0agent.yaml" (echo  [OK] Required asset verified: agent.yaml) else (echo  [ERROR] Missing agent.yaml & exit /b 1)
    if exist "%~dp0Modelfile" (echo  [OK] Required asset verified: Modelfile) else (echo  [ERROR] Missing Modelfile & exit /b 1)
    if exist "%~dp0sample.log" (echo  [OK] Required asset verified: sample.log) else (echo  [ERROR] Missing sample.log & exit /b 1)
    if exist "%~dp0analyze_logs.py" (echo  [OK] Required asset verified: analyze_logs.py) else (echo  [ERROR] Missing analyze_logs.py & exit /b 1)
    echo.
    echo  [OK] Dry run successful! All prerequisites and files verified.
    exit /b 0
)

echo.
echo    .  *        +        .       *       .       .  *    +       .
echo          [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]
echo                Autonomous SRE ^& DevOps AI Agent
echo                Model: dark-matter (qwen2.5:7b) ^| Agent: dark-matter
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

:: 2. Ensure Ollama service is running; poll health endpoint up to 15 seconds
curl -s -m 2 http://127.0.0.1:11434/api/tags >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [*] Starting local Ollama service in background...
    start "" /b ollama serve >nul 2>&1
    set RETRIES=0
    :POLL_OLLAMA
    timeout /t 1 /nobreak >nul 2>&1
    curl -s -m 1 http://127.0.0.1:11434/api/tags >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        set /a RETRIES+=1
        if !RETRIES! lss 15 goto POLL_OLLAMA
        echo  [ERROR] Ollama service did not respond within 15 seconds.
        pause
        exit /b 1
    )
)

:: 3. Check if base Qwen 2.5 7B model is installed; if not, pull it
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
    echo  [OK] Base model qwen2.5:7b is ready.
)

:: 4. Check if Dark Matter custom model is compiled from Modelfile
ollama list | findstr /i "dark-matter" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [*] Compiling Dark Matter tuned SRE model from Modelfile...
    ollama create dark-matter -f "%~dp0Modelfile"
    if !ERRORLEVEL! neq 0 (
        echo  [ERROR] Failed to compile dark-matter model.
        pause
        exit /b 1
    )
    echo  [OK] Dark Matter custom model compiled successfully!
)

:: 5. Pre-warm custom dark-matter model so it stays awake in memory indefinitely
curl -s -m 5 -X POST http://127.0.0.1:11434/api/generate -d "{\"model\": \"dark-matter\", \"keep_alive\": -1}" >nul 2>&1
echo  [OK] Dark Matter model is awake and pinned in memory [Always Awake: Active].

:: 6. Check if Docker is available
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

:: 7. Run Dark Matter Agent
docker agent run --app-name "Dark Matter" "%~dp0agent.yaml" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [!] Dark Matter exited with code %ERRORLEVEL%.
    echo  Press any key to close this window...
    pause >nul
)
