#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"
INSTALL_DIR="/opt/extension-hub"
BIN_PATH="/usr/local/bin/extension-hub"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo bash install.sh"
  exit 1
fi

# Keep package-manager output out of the terminal.
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1; then
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq curl >/dev/null 2>&1
fi

echo "==> Preparing Extension Hub..."
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq bash coreutils grep sed >/dev/null 2>&1

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

echo "==> Downloading Extension Hub..."
if ! curl -fsSL --retry 3 --connect-timeout 15 \
  "$REPO_RAW/extension-hub.sh" -o "$tmp_file"; then
  echo "ERROR: Download failed. Check that the GitHub repository is public and extension-hub.sh is in the main branch root."
  exit 1
fi

if ! head -n 1 "$tmp_file" | grep -q '^#!/usr/bin/env bash'; then
  echo "ERROR: Downloaded file is not a valid Extension Hub Bash script."
  exit 1
fi

install -d -m 755 "$INSTALL_DIR"
install -m 755 "$tmp_file" "$INSTALL_DIR/extension-hub.sh"
install -m 755 "$tmp_file" "$BIN_PATH"

echo "==> Installation complete. Opening Extension Hub..."
exec "$BIN_PATH"
