#!/usr/bin/env bash
# Extension Hub v1.0 - Pterodactyl Panel manager
# Made by Ziro | Powered by NexyonCloud
set -Eeuo pipefail

APP_NAME="Extension Hub"
APP_VERSION="v1.0"
AUTHOR="Ziro"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
BLUEPRINT_RELEASE_URL="https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip"
STATE_DIR="/var/lib/extension-hub"
BACKUP_DIR="$STATE_DIR/backups"
LOG_FILE="/var/log/extension-hub.log"
TMP_DIR=""

# ---------- colors ----------
if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_CYAN=$'\033[38;5;45m'; C_BLUE=$'\033[38;5;39m'
  C_GREEN=$'\033[38;5;82m'; C_YELLOW=$'\033[38;5;220m'
  C_RED=$'\033[38;5;203m'; C_WHITE=$'\033[97m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_CYAN=""; C_BLUE=""
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_WHITE=""
fi

cleanup() { [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT
mkdir -p "$STATE_DIR" "$BACKUP_DIR" 2>/dev/null || true

log() {
  local level="$1"; shift
  local line="[$(date '+%F %T')] [$level] $*"
  printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}
info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; log INFO "$*"; }
ok() { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log OK "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log WARN "$*"; }
err() { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log ERROR "$*"; }
pause() { echo; read -r -p "Press Enter to continue..." _ || true; }
need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root: sudo -E bash $0"
    return 1
  fi
}
command_exists() { command -v "$1" >/dev/null 2>&1; }
valid_panel_dir() {
  [[ -d "$PANEL_DIR" && -f "$PANEL_DIR/artisan" && -f "$PANEL_DIR/composer.json" ]]
}
detect_web_user() {
  if id www-data >/dev/null 2>&1; then printf '%s' "www-data"
  elif id nginx >/dev/null 2>&1; then printf '%s' "nginx"
  elif id apache >/dev/null 2>&1; then printf '%s' "apache"
  else return 1; fi
}
detect_blueprint() {
  valid_panel_dir && [[ -f "$PANEL_DIR/blueprint.sh" && -f "$PANEL_DIR/.blueprintrc" ]]
}
panel_version() {
  if valid_panel_dir && command_exists php; then
    (cd "$PANEL_DIR" && php artisan --version 2>/dev/null | sed 's/^Laravel Framework //') || true
  else
    printf '%s' "Unknown"
  fi
}
blueprint_version() {
  if [[ -f "$PANEL_DIR/blueprint.sh" ]]; then
    grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/blueprint.sh" 2>/dev/null | head -n1 || true
  fi
}
choose_panel_dir() {
  local candidate
  read -r -p "Pterodactyl directory [$PANEL_DIR]: " candidate || true
  candidate="${candidate:-$PANEL_DIR}"
  if [[ ! -d "$candidate" ]]; then err "Directory does not exist: $candidate"; return 1; fi
  PANEL_DIR="$(cd "$candidate" && pwd)"
  if ! valid_panel_dir; then
    err "This does not look like a Pterodactyl panel (artisan/composer.json missing)."
    return 1
  fi
  export PTERODACTYL_DIRECTORY="$PANEL_DIR"
  ok "Panel directory: $PANEL_DIR"
}
make_backup() {
  valid_panel_dir || { err "Panel directory invalid."; return 1; }
  local stamp archive
  stamp="$(date '+%Y%m%d-%H%M%S')"
  archive="$BACKUP_DIR/panel-blueprint-$stamp.tar.gz"
  info "Creating backup: $archive"
  tar -czf "$archive" -C "$PANEL_DIR" \
    --ignore-failed-read \
    .blueprintrc blueprint.sh blueprint release.zip \
    resources public app routes 2>/dev/null || {
      rm -f "$archive"
      err "Backup failed. No changes were made."
      return 1
    }
  chmod 600 "$archive"
  ok "Backup created: $archive"
}
install_dependencies() {
  need_root || return 1
  if ! command_exists apt-get; then
    err "Automatic dependency setup currently supports Debian/Ubuntu (apt)."
    return 1
  fi
  info "Installing system dependencies..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git gnupg unzip wget zip
  install -d -m 0755 /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/nodesource.gpg ]]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    chmod 0644 /etc/apt/keyrings/nodesource.gpg
  fi
  printf '%s\n' \
    'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  if ! command_exists yarn; then npm install --global yarn; fi
  ok "Dependencies ready. Node: $(node --version), npm: $(npm --version), Yarn: $(yarn --version)"
}
install_blueprint() {
  need_root || return 1
  choose_panel_dir || return 1
  if detect_blueprint; then
    warn "Blueprint files already exist. Use Reinstall or Update from the installed menu."
    return 1
  fi
  local webuser ownership
  webuser="$(detect_web_user)" || { err "Could not identify web user (www-data/nginx/apache)."; return 1; }
  ownership="$webuser:$webuser"
  echo
  warn "This installs the latest Blueprint release into: $PANEL_DIR"
  warn "A backup of relevant panel files will be created first."
  read -r -p "Continue? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { info "Cancelled."; return 0; }
  make_backup || return 1
  install_dependencies || return 1

  TMP_DIR="$(mktemp -d)"
  info "Downloading latest official Blueprint release..."
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  unzip -t "$TMP_DIR/release.zip" >/dev/null
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip)
  (cd "$PANEL_DIR" && yarn install)

  if [[ ! -f "$PANEL_DIR/.blueprintrc" ]]; then
    cat > "$PANEL_DIR/.blueprintrc" <<EOF
WEBUSER="$webuser";
OWNERSHIP="$ownership";
USERSHELL="/bin/bash";
EOF
  else
    warn ".blueprintrc already exists; leaving its custom settings unchanged."
  fi
  [[ -f "$PANEL_DIR/blueprint.sh" ]] || { err "blueprint.sh was not found after extraction."; return 1; }
  chmod +x "$PANEL_DIR/blueprint.sh"
  info "Running Blueprint's own setup script..."
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  chown -R "$ownership" "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
  if detect_blueprint; then ok "Blueprint files and configuration detected."; else err "Post-install verification failed. Review log and Blueprint output."; return 1; fi
}
update_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed."; return 1; }
  warn "Update will download the latest release and may replace Blueprint files."
  read -r -p "Create backup and continue? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  TMP_DIR="$(mktemp -d)"
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  unzip -t "$TMP_DIR/release.zip" >/dev/null
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint update procedure completed. Check the output above."
}
reinstall_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed; choose Install."; return 1; }
  warn "Reinstall replaces files from the latest release. Existing custom configuration is preserved."
  read -r -p "Continue after backup? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  TMP_DIR="$(mktemp -d)"
  install_dependencies || return 1
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  unzip -t "$TMP_DIR/release.zip" >/dev/null
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Reinstall procedure completed. Check the output above."
}
blueprint_info() {
  echo
  printf '%s\n' "Blueprint directory : $PANEL_DIR"
  printf 'Blueprint detected  : '
  detect_blueprint && echo "YES" || echo "NO"
  printf 'Blueprint script    : '
  [[ -f "$PANEL_DIR/blueprint.sh" ]] && echo "Present" || echo "Missing"
  printf 'Blueprint config    : '
  [[ -f "$PANEL_DIR/.blueprintrc" ]] && echo "Present" || echo "Missing"
  printf 'Panel version       : %s\n' "$(panel_version)"
  printf 'Blueprint version   : %s\n' "$(blueprint_version)"
  printf 'Node.js             : %s\n' "$(node --version 2>/dev/null || echo Missing)"
  printf 'Yarn                : %s\n' "$(yarn --version 2>/dev/null || echo Missing)"
  echo
}
uninstall_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not detected."; return 1; }
  warn "Blueprint does not provide a generic safe file-only uninstall in this manager."
  warn "Removing its files manually can break extensions or panel customizations."
  echo "A backup can be created, but automatic uninstall is disabled until an official"
  echo "uninstall procedure is confirmed for the installed Blueprint release."
  read -r -p "Create a safety backup now? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] && make_backup
}
blueprint_menu() {
  while true; do
    clear 2>/dev/null || true
    echo
    printf '%s╔══════════════════════════════════╗%s\n' "$C_CYAN" "$C_RESET"
    printf '%s║        CONTROL PANEL UI          ║%s\n' "$C_CYAN" "$C_RESET"
    printf '%s╚══════════════════════════════════╝%s\n' "$C_CYAN" "$C_RESET"
    echo
    printf '       %sBLUEPRINT PANEL%s\n' "$C_BOLD" "$C_RESET"
    if detect_blueprint; then
      printf '       Status : %s● ONLINE%s\n\n' "$C_GREEN" "$C_RESET"
      echo "       [1] Reinstall"
      echo "       [2] Update"
      echo "       [3] Info"
      echo "       [4] Version"
      echo "       [5] Uninstall"
    else
      printf '       Status : %s● OFFLINE%s\n\n' "$C_RED" "$C_RESET"
      echo "       [1] Install"
    fi
    echo
    echo "       [0] Back"
    echo
    read -r -p "       ➤ Select : " choice || return
    if detect_blueprint; then
      case "$choice" in
        1) reinstall_blueprint; pause ;;
        2) update_blueprint; pause ;;
        3) blueprint_info; pause ;;
        4) printf 'Blueprint version: %s\nPanel version: %s\n' "$(blueprint_version)" "$(panel_version)"; pause ;;
        5) uninstall_blueprint; pause ;;
        0) return ;;
        *) warn "Invalid option."; pause ;;
      esac
    else
      case "$choice" in
        1) install_blueprint; pause ;;
        0) return ;;
        *) warn "Invalid option."; pause ;;
      esac
    fi
  done
}
placeholder_menu() {
  local title="$1"
  clear 2>/dev/null || true
  echo "╔══════════════════════════════════╗"
  printf '║ %-32s ║\n' "$title"
  echo "╚══════════════════════════════════╝"
  echo
  warn "This section is not implemented yet; no fake install actions are shown."
  pause
}
show_logo() {
  printf '%s' "$C_CYAN"
  cat <<'LOGO'
________   _________ ______ _   _ _______ _____ ____  _   _   _    _ _    _ ____
 |  ____\ \ / /__   __|  ____| \ | |__   __|_   _/ __ \| \ | | | |  | | |  | |  _ \
 | |__   \ V /   | |  | |__  |  \| |  | |    | || |  | |  \| | | |__| | |  | | |_) |
 |  __|   > <    | |  |  __| | . ` |  | |    | || |  | | . ` | |  __  | |  | |  _ <
 | |____ / . \   | |  | |____| |\  |  | |   _| || |__| | |\  | | |  | | |__| | |_) |
 |______/_/ \_\  |_|  |______|_| \_|  |_|  |_____\____/|_| \_| |_|  |_|\____/|____/
LOGO
  printf '%s' "$C_RESET"
}
main_menu() {
  while true; do
    clear 2>/dev/null || true
    show_logo
    echo
        printf '%s%s%s\n' "$C_BOLD$C_CYAN"       "PTERODACTYL EXTENSION MANAGER" "$C_RESET"
                                            echo     "Manage • Customize • Extend"
    echo
    echo "┌──────────────────────────────────┐"
    printf "│  Version       : %-16s│\n" "$APP_VERSION"
    printf "│  Made by       : %-16s│\n" "$AUTHOR"
    printf "│  Panel Version : %-16s│\n" "1.x.x"
    echo "└──────────────────────────────────┘"
    echo
    echo "© 2026 Extension Hub • All Rights Reserved"
    echo
    printf '%s%s%s\n' "$C_BOLD$C_CYAN" "MAIN MENU" "$C_RESET"
    echo
    echo " [01] Blueprint"
    echo " [02] Themes"
    echo " [03] Extensions"
    printf ' [04] Zerix Theme %s(Coming Soon)%s\n' "$C_YELLOW" "$C_RESET"
    echo
    echo " [00] EXIT"
    echo
    read -r -p "Select an option [00-04]: " choice || exit 0
    case "$choice" in
      1|01) blueprint_menu ;;
      2|02) placeholder_menu "THEMES" ;;
      3|03) placeholder_menu "EXTENSIONS" ;;
      4|04) clear 2>/dev/null || true; warn "Zerix Theme is coming soon."; pause ;;
      0|00) echo "Goodbye."; exit 0 ;;
      h|H) echo "Choose 01 Blueprint, 02 Themes, 03 Extensions, 04 Zerix Theme, or 00 Exit."; pause ;;
      *) warn "Invalid option."; pause ;;
    esac
  done
}

case "${1:-}" in
  blueprint)
    case "${2:-}" in
      status) detect_blueprint && echo "ONLINE" || echo "OFFLINE" ;;
      install) install_blueprint ;;
      update) update_blueprint ;;
      version) echo "Blueprint: $(blueprint_version)"; echo "Panel: $(panel_version)" ;;
      info) blueprint_info ;;
      *) blueprint_menu ;;
    esac
    ;;
  help|-h|--help)
    echo "Usage: extension-hub [blueprint [status|install|update|version|info]]"
    ;;
  *) main_menu ;;
esac
