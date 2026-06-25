#!/usr/bin/env bash
# install.sh — Qwen Orchestrator cross-platform installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mnofresno/qwen-orchestrator/main/install.sh | bash
#        bash install.sh [--start|--stop|--status|--uninstall]
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve repo root from the script location
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Detect piped-stdin install (curl | bash)
# ---------------------------------------------------------------------------
if [ ! -t 0 ]; then
    echo "==> Piped install detected — ensuring repo is available locally."
    if [ ! -d "$HOME/qwen-orchestrator/.git" ]; then
        echo "==> Cloning qwen-orchestrator to ~/qwen-orchestrator ..."
        rm -rf "$HOME/qwen-orchestrator"
        git clone https://github.com/mnofresno/qwen-orchestrator.git "$HOME/qwen-orchestrator"
    fi
    REPO_ROOT="$HOME/qwen-orchestrator"
    SCRIPT_DIR="$REPO_ROOT"
fi

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
OS="$(uname -s)"
case "$OS" in
    Darwin)  PLATFORM="macos" ;;
    Linux)   PLATFORM="linux" ;;
    *)       echo "Unsupported OS: $OS"; exit 1 ;;
esac

CONFIG_DIR="$HOME/.config/qwen-orchestrator"
CONFIG_SRC="$REPO_ROOT/config/config.example.yaml"
BINARY="$REPO_ROOT/bin/qwen-orchestrator"
SERVICE_SRC="$REPO_ROOT/service/qwen-orchestrator.service"

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------
ACTION="${1:-install}"

# ---------------------------------------------------------------------------
# Helper: install config
# ---------------------------------------------------------------------------
install_config() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        cp "$CONFIG_SRC" "$CONFIG_DIR/config.yaml"
        echo "==> Config: $CONFIG_DIR/config.yaml (created from example)"
    else
        echo "==> Config: $CONFIG_DIR/config.yaml (already exists, untouched)"
    fi
}

# ---------------------------------------------------------------------------
# Helper: make binary executable
# ---------------------------------------------------------------------------
make_executable() {
    if [ -f "$BINARY" ]; then
        chmod +x "$BINARY"
        echo "==> Binary: $BINARY (executable)"
    else
        echo "==> Warning: $BINARY not found"
    fi
}

# ---------------------------------------------------------------------------
# Linux: systemd user service
# ---------------------------------------------------------------------------
install_systemd() {
    mkdir -p "$HOME/.config/systemd/user"
    cp "$SERVICE_SRC" "$HOME/.config/systemd/user/qwen-orchestrator.service"
    systemctl --user daemon-reload
    systemctl --user enable qwen-orchestrator
    echo "==> systemd: service enabled (run 'systemctl --user start qwen-orchestrator')"
}

# ---------------------------------------------------------------------------
# macOS: launchd user service
# ---------------------------------------------------------------------------
install_launchd() {
    local plist_dir="$HOME/Library/LaunchAgents"
    local plist="$plist_dir/com.mnofresno.qwen-orchestrator.plist"
    local log_dir="$HOME/.local/share/qwen-orchestrator"
    mkdir -p "$plist_dir" "$log_dir"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mnofresno.qwen-orchestrator</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BINARY</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$log_dir/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$log_dir/launchd.err.log</string>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)" "$plist" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist"
    launchctl kickstart -k "gui/$(id -u)/com.mnofresno.qwen-orchestrator"
    echo "==> launchd: installed and started $plist"
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
case "$ACTION" in
    install|--install)
        echo "==> Installing qwen-orchestrator on $PLATFORM ..."
        install_config
        make_executable
        if [ "$PLATFORM" = "linux" ]; then
            install_systemd
        else
            install_launchd
        fi
        echo "==> Done."
        ;;

    start|--start)
        echo "==> Starting qwen-orchestrator ..."
        if [ "$PLATFORM" = "linux" ]; then
            systemctl --user start qwen-orchestrator
        else
            launchctl kickstart -k "gui/$(id -u)/com.mnofresno.qwen-orchestrator"
        fi
        ;;

    stop|--stop)
        echo "==> Stopping qwen-orchestrator ..."
        if [ "$PLATFORM" = "linux" ]; then
            systemctl --user stop qwen-orchestrator
        else
            launchctl kill TERM "gui/$(id -u)/com.mnofresno.qwen-orchestrator" 2>/dev/null || true
        fi
        ;;

    status|--status)
        echo "==> qwen-orchestrator status:"
        if [ "$PLATFORM" = "linux" ]; then
            systemctl --user status qwen-orchestrator || true
        else
            launchctl print "gui/$(id -u)/com.mnofresno.qwen-orchestrator" || true
        fi
        ;;

    uninstall|--uninstall)
        bash "$REPO_ROOT/uninstall.sh"
        ;;

    *)
        echo "Usage: $0 [install|start|stop|status|uninstall]"
        echo "       install (default) — set up config, binary, and service"
        echo "       start             — start the service"
        echo "       stop              — stop the service"
        echo "       status            — show service status"
        echo "       uninstall         — remove everything"
        exit 1
        ;;
esac
