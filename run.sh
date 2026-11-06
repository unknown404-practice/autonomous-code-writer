#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

# Ensure Ollama keeps model in memory indefinitely (Always Awake)
export OLLAMA_KEEP_ALIVE="-1"

echo ""
echo "   .  *        +        .       *       .       .  *    +       ."
echo "         [#]   DARK MATTER - SERVER LOG INVESTIGATOR   [#]"
echo "               Autonomous SRE & DevOps AI Agent"
echo "               Model: qwen2.5:7b [Local Ollama] | Agent: dark-matter"
echo "   -------------------------------------------------------------"
echo ""

# 1. Check if Ollama CLI is installed
if ! command -v ollama &>/dev/null; then
    echo " [!] Ollama CLI was not found on your system."
    echo " [*] Attempting to install Ollama via official installer (https://ollama.com)..."
    if command -v curl &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo " [ERROR] curl is required to auto-install Ollama. Please install Ollama from https://ollama.com/download"
        exit 1
    fi
fi

# 2. Check if Ollama service is running
if ! curl -s -m 2 http://127.0.0.1:11434/api/tags &>/dev/null; then
    echo " [*] Starting Ollama service in background..."
    ollama serve &>/dev/null &
    sleep 3
fi

# 3. Check if Qwen 2.5 7B model is installed; if not, automatically pull it
if ! ollama list 2>/dev/null | grep -q "qwen2.5:7b"; then
    echo ""
    echo " [!] Qwen 2.5 7B model is not installed yet."
    echo " [*] Automatically downloading qwen2.5:7b (one-time setup, ~4.7GB)..."
    echo ""
    ollama pull qwen2.5:7b
    echo ""
    echo " [OK] Qwen 2.5 7B installed successfully!"
    echo ""
else
    echo " [OK] Local Ollama is online with qwen2.5:7b ready."
fi

# 4. Pre-warm Qwen 2.5 7B so it stays awake in memory indefinitely (Zero Cold-Start)
curl -s -m 5 -X POST http://127.0.0.1:11434/api/generate -d '{"model": "qwen2.5:7b", "keep_alive": -1}' &>/dev/null || true
echo " [OK] Qwen 2.5 7B is awake and pinned in memory [Always Awake: Active]."

# 5. Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo " [ERROR] Docker CLI was not found in PATH. Please install Docker Desktop or Docker Engine."
    exit 1
fi

echo " [OK] Launching Dark Matter TUI..."
echo ""

docker agent run --app-name "Dark Matter" "$DIR/agent.yaml" "$@"
