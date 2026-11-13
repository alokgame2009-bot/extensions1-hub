#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"
INSTALL_DIR="/opt/extension-hub"
BIN_PATH="/usr/local/bin/extension-hub"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash install.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1; then
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq curl >/dev/null 2>&1
fi

echo "==> Preparing Extension Hub..."
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq bash coreutils grep sed >/dev/null 2>&1

tmp_main="$(mktemp)"
tmp_nex="$(mktemp)"
trap 'rm -f "$tmp_main" "$tmp_nex"' EXIT

echo "==> Downloading Main UI..."
if ! curl -fsSL --retry 3 "$REPO_RAW/extension-hub.sh" -o "$tmp_main"; then echo "Failed: extension-hub.sh"; exit 1; fi

echo "==> Downloading NexyonCloud Installer..."
if ! curl -fsSL --retry 3 "$REPO_RAW/nexyoncloud-installer.sh" -o "$tmp_nex"; then echo "Failed: nexyoncloud-installer.sh"; exit 1; fi

install -d -m 755 "$INSTALL_DIR"
install -m 755 "$tmp_main" "$INSTALL_DIR/extension-hub.sh"
install -m 755 "$tmp_nex" "$INSTALL_DIR/nexyoncloud-installer.sh"
install -m 755 "$tmp_main" "$BIN_PATH"

echo "==> Installation complete. Opening Extension Hub..."
sleep 1
exec "$BIN_PATH"
