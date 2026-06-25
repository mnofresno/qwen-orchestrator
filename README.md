# Qwen Orchestrator

Cross-platform user-level service (macOS / Linux) that monitors GPU/Grafana load, audits stuck Qwen Code sessions, and resumes work through Qwen Code's `--input-file` remote-input channel.

## Features

- **Multi-strategy load detection** — choose between SSH/nvidia-smi, Grafana API (LLM gateway slots, GPU power), or both
- **Smart error detection** — scans running and recent Qwen Code sessions for timeout/API errors, stale unanswered user requests, and completed work
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

The installer creates a user-level service on both platforms. On Linux it writes
`~/.config/systemd/user/qwen-orchestrator.service`, runs `systemctl --user enable
--now qwen-orchestrator`, and points `ExecStart` at the checked-out binary.

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

The round-robin loop intentionally avoids relaunching completed or already
answered sessions. By default, age-based resume only applies when the latest
relevant chat turn is still a user request. Completion detection is configurable:

```yaml
qwen:
  completion_detection_enabled: true
  completion_regex: "complete|completed|done|pushed|created pull request|merged"
  user_completion_regex: \s*(ok\s*)?fin\s*
  resume_after_assistant_response: false
```

Set `resume_after_assistant_response: true` only if you want the older aggressive
behavior where old sessions can be retried even after an assistant response that
did not match `completion_regex`.

## Config

See `config/config.example.yaml`.

## License

MIT
