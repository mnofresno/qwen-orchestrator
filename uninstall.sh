#!/usr/bin/env bash
# uninstall.sh — Remove qwen-orchestrator service, config, and repo
set -euo pipefail

PLATFORM="$(uname -s)"
if [ "$PLATFORM" = "Darwin" ]; then
    PLATFORM="macos"
elif [ "$PLATFORM" = "Linux" ]; then
    PLATFORM="linux"
else
    echo "==> Unsupported platform: $PLATFORM"
    exit 1
fi

echo "==> Uninstalling qwen-orchestrator on $PLATFORM ..."

# --- Stop service ---
if [ "$PLATFORM" = "linux" ]; then
    systemctl --user stop qwen-orchestrator 2>/dev/null || true
    systemctl --user disable qwen-orchestrator 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/qwen-orchestrator.service"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "==> systemd: service stopped, disabled, removed"
else
    launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.mnofresno.qwen-orchestrator.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.mnofresno.qwen-orchestrator.plist"
    echo "==> launchd: service stopped, plist removed"
fi

# --- Remove config ---
rm -rf "$HOME/.config/qwen-orchestrator"
echo "==> Config: ~/.config/qwen-orchestrator removed"

# --- Remove repo (optional — confirm) ---
echo "==> To remove the repo directory, run:"
echo "    rm -rf ~/qwen-orchestrator"
echo "==> Done."
