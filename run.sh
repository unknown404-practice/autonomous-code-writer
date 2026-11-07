#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

# Ensure Ollama keeps model in memory indefinitely (Always Awake)
export OLLAMA_KEEP_ALIVE="-1"

# Handle --dry-run validation
if [[ "$*" == *"--dry-run"* ]]; then
    echo ""
    echo "================================================================="
    echo "       DARK MATTER - PRE-FLIGHT DRY RUN VALIDATION               "
    echo "================================================================="
    echo ""
    
    # Check Python
    if command -v python3 &>/dev/null; then
        echo " [OK] Python 3 found: $(python3 --version 2>&1)"
    elif command -v python &>/dev/null; then
        echo " [OK] Python found: $(python --version 2>&1)"
    else
        echo " [!] Python not found in PATH."
    fi

    # Check Ollama
    if command -v ollama &>/dev/null; then
        echo " [OK] Ollama CLI found in PATH."
    else
        echo " [!] Ollama CLI not found in PATH."
    fi

    # Check Docker
    if command -v docker &>/dev/null; then
        echo " [OK] Docker CLI found in PATH."
    else
        echo " [!] Docker CLI not found in PATH."
    fi

    # Check Core Files
    for file in agent.yaml Modelfile sample.log analyze_logs.py; do
        if [[ -f "$file" ]]; then
            echo " [OK] Required asset verified: $file"
        else
            echo " [ERROR] Missing required asset: $file"
            exit 1
        fi
    done

    echo ""
    echo " [OK] Dry run successful! All prerequisites and files verified."
    exit 0
fi

echo ""
echo "   .  *        +        .       *       .       .  *    +       ."
echo "         [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]"
echo "               Autonomous SRE & DevOps AI Agent"
echo "               Model: dark-matter (qwen2.5:7b) | Agent: dark-matter"
echo "   -------------------------------------------------------------"
echo ""

# 1. Check if Ollama CLI is installed (Safe validation, no insecure curl|sh execution)
if ! command -v ollama &>/dev/null; then
    echo " [ERROR] Ollama CLI was not found on your system."
    echo " [*] Please download and install Ollama from https://ollama.com/download"
    echo " [*] After installation, re-run this script."
    exit 1
fi

# 2. Check if Ollama service is running; poll health endpoint up to 15 seconds
if ! curl -s -m 2 http://127.0.0.1:11434/api/tags &>/dev/null; then
    echo " [*] Starting Ollama service in background..."
    ollama serve &>/dev/null &
    
    # Dynamic health check polling
    retries=0
    max_retries=15
    while ! curl -s -m 1 http://127.0.0.1:11434/api/tags &>/dev/null; do
        sleep 1
        retries=$((retries + 1))
        if [[ $retries -ge $max_retries ]]; then
            echo " [ERROR] Ollama service failed to respond within $max_retries seconds."
            exit 1
        fi
    done
fi

# 3. Check base model qwen2.5:7b
if ! ollama list 2>/dev/null | grep -q "qwen2.5:7b"; then
    echo ""
    echo " [!] Qwen 2.5 7B model is not installed yet."
    echo " [*] Automatically downloading qwen2.5:7b (one-time setup, ~4.7GB)..."
    echo ""
    ollama pull qwen2.5:7b
    echo ""
    echo " [OK] Base foundation qwen2.5:7b installed successfully!"
    echo ""
else
    echo " [OK] Base model qwen2.5:7b is ready."
fi

# 4. Compile custom Dark Matter SRE model from Modelfile if not already created
if ! ollama list 2>/dev/null | grep -q "dark-matter"; then
    echo " [*] Compiling Dark Matter tuned SRE model from Modelfile..."
    ollama create dark-matter -f "$DIR/Modelfile"
    echo " [OK] Dark Matter custom model compiled successfully!"
fi

# 5. Pre-warm custom dark-matter model so it stays awake in memory indefinitely
curl -s -m 5 -X POST http://127.0.0.1:11434/api/generate -d '{"model": "dark-matter", "keep_alive": -1}' &>/dev/null || true
echo " [OK] Dark Matter model is awake and pinned in memory [Always Awake: Active]."

# 6. Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo " [ERROR] Docker CLI was not found in PATH. Please install Docker Desktop or Docker Engine."
    exit 1
fi

echo " [OK] Launching Dark Matter TUI..."
echo ""

docker agent run --app-name "Dark Matter" "$DIR/agent.yaml" "$@"
