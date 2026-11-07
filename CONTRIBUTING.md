# Contributing to Dark Matter

Thank you for your interest in contributing to **Dark Matter**! We welcome bug reports, feature suggestions, documentation enhancements, and pull requests from the global open-source community.

---

## Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free environment for everyone. Please be respectful, constructive, and collaborative in all discussions and pull requests.

---

## Development Workflow

1. **Fork the Repository**
   Create a personal fork on GitHub.

2. **Clone Your Fork**
   ```bash
   git clone https://github.com/<your-username>/autonomous-code-writer.git
   cd autonomous-code-writer
   ```

3. **Create a Feature Branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

4. **Verify Prerequisites**
   Ensure you have:
   - [Ollama](https://ollama.com/) with `qwen2.5:7b` installed:
     ```bash
     ollama pull qwen2.5:7b
     ```
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) or Docker Engine with Docker Agent CLI plugin.
   - Python 3.10+ (for log analyzer scripts and test verification).

5. **Test Your Changes**
   - Test standalone analyzer:
     ```bash
     python analyze_logs.py sample.log
     ```
   - Test the dry-run launcher:
     ```bash
     # Windows PowerShell:
     .\run.ps1 --dry-run

     # Windows Command Prompt:
     run.bat --dry-run

     # Linux / macOS:
     ./run.sh --dry-run
     ```
   - Test automated headless execution:
     ```bash
     docker agent run --app-name "Dark Matter" ./agent.yaml --exec --safety autonomous "echo verification"
     ```

6. **Commit & Push**
   Follow conventional commits format:
   - `feat: add new log pattern matcher for Nginx 499 errors`
   - `fix: resolve Ollama timeout on low-spec hardware`
   - `docs: update troubleshooting matrix for Windows Terminal`

7. **Submit a Pull Request**
   Open a pull request against the `master` branch. Please fill out the PR template completely.

---

## Pull Request Guidelines

- Keep pull requests focused on a single change or feature.
- Ensure all launcher scripts (`run.ps1`, `run.bat`, `run.sh`) remain functional.
- Maintain documentation integrity and update `README.md` if options change.
- All code and markdown must pass CI validation.
