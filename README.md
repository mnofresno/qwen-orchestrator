# Qwen Orchestrator

Cross-platform user-level service (macOS / Linux) that monitors GPU/Grafana load, audits stuck Qwen Code sessions, and resumes work through Qwen Code's `--input-file` remote-input channel.

## Features

- **Multi-strategy load detection** — choose between SSH/nvidia-smi, Grafana API (LLM gateway slots, GPU power), or both
- **Smart error detection** — scans running and recent Qwen Code sessions for timeout/API errors or stale user requests
- **Round-robin control** — resumes one configurable session per cycle so the GPU stays busy without stampeding the server
- **Configurable resume message** — asks resumed agents to continue, validate, commit, and push when appropriate
- **User-level service** — `systemctl --user` on Linux, `launchd` on macOS
- **Auto-push** — commits config changes to this repo periodically
- **One-line install** — `curl -fsSL https://raw.githubusercontent.com/mnofresno/qwen-orchestrator/main/install.sh | bash`

## Strategies

| Strategy | What it checks | Config keys |
|---|---|---|
| `ssh` | `nvidia-smi` GPU utilization over SSH | `ssh.*`, `gpu.threshold` |
| `grafana-llm` | `vllm:num_requests_running` via Grafana API | `grafana.*`, `grafana.query` |
| `grafana-power` | `DCGM_FI_DEV_POWER_USAGE` via Grafana API | `grafana.*`, `grafana.query` |

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/mnofresno/qwen-orchestrator/main/install.sh | bash
```

Then edit `~/.config/qwen-orchestrator/config.yaml` and restart:

```bash
systemctl --user restart qwen-orchestrator    # Linux
launchctl kickstart -k gui/$(id -u)/com.mnofresno.qwen-orchestrator  # macOS
```

## Manual Usage

```bash
# Check capacity + running Qwen processes
bin/qwen-orchestrator status

# Audit recent sessions and explain why each one is running/stopped/stale
bin/qwen-orchestrator audit

# Run one capacity-gated round-robin cycle
bin/qwen-orchestrator once

# Force one round-robin resume, skipping the GPU capacity gate
bin/qwen-orchestrator resume

# Preview the control actions without launching or writing input
bin/qwen-orchestrator round-robin --dry-run --force
```

## Control Model

Qwen Code accepts remote commands through `--input-file`. The orchestrator writes JSONL lines like:

```json
{"type":"submit","text":"Dale papito segui..."}
```

Sessions that were already launched with `--input-file` can be controlled directly. Older sessions without that flag are relaunched with `qwen --resume <session> --input-file <file>`; on macOS that happens in Terminal so Qwen still has a real TTY.

## Config

See `config/config.example.yaml`.

## License

MIT
