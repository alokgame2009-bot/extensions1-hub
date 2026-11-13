#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"
INSTALL_DIR="/opt/extension-hub"
BIN_PATH="/usr/local/bin/extension-hub"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this installer as root:"
  echo "sudo bash install.sh"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  apt-get update
  apt-get install -y curl
fi

echo "==> Installing Extension Hub dependencies..."
apt-get update
apt-get install -y bash coreutils grep sed

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

echo "==> Downloading Extension Hub..."
if ! curl -fL --retry 3 --connect-timeout 15 \
  "$REPO_RAW/extension-hub.sh" -o "$tmp_file"; then
  echo "ERROR: Could not download extension-hub.sh from:"
  echo "$REPO_RAW/extension-hub.sh"
  echo "Check that the GitHub repository is public and the file is in the repository root."
  exit 1
fi

if ! head -n 1 "$tmp_file" | grep -q '^#!/usr/bin/env bash'; then
  echo "ERROR: Downloaded file does not look like the Extension Hub Bash script."
  exit 1
fi

install -d -m 755 "$INSTALL_DIR"
install -m 755 "$tmp_file" "$INSTALL_DIR/extension-hub.sh"
install -m 755 "$tmp_file" "$BIN_PATH"

echo
echo "Extension Hub installed successfully."
echo "Starting Extension Hub..."
exec "$BIN_PATH"
