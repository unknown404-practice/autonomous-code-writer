# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Local Execution & Data Privacy

- **Local Inference:** This agent communicates exclusively with local Ollama (`http://127.0.0.1:11434/v1`). No log contents, server IP addresses, or environment traces are ever transmitted outside the host machine.
- **Tool Sandbox:** Docker Agent restricts tool permissions. Use `--safety balanced` or `--safety strict` to manually approve shell and filesystem modifications.

## Reporting a Vulnerability

If you discover a security vulnerability, please open a private GitHub security advisory or contact the maintainers. We respond within 48 hours.
