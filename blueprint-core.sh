#!/usr/bin/env bash
# blueprint-core.sh - Core logic for Blueprint Management

PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
BLUEPRINT_RELEASE_URL="https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip"
STATE_DIR="/var/lib/extension-hub"
BACKUP_DIR="$STATE_DIR/backups"

need_root() { [[ "$EUID" -eq 0 ]] || { err "Run as root."; return 1; }; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
valid_panel_dir() { [[ -d "$PANEL_DIR" && -f "$PANEL_DIR/artisan" && -f "$PANEL_DIR/composer.json" ]]; }
detect_web_user() { id www-data >/dev/null 2>&1 && echo "www-data" || (id nginx >/dev/null 2>&1 && echo "nginx" || echo "apache"); }
detect_blueprint() { valid_panel_dir && [[ -f "$PANEL_DIR/blueprint.sh" && -f "$PANEL_DIR/.blueprintrc" ]]; }

panel_version() { 
    valid_panel_dir && command_exists php && (cd "$PANEL_DIR" && php artisan --version 2>/dev/null | sed 's/^Laravel Framework //') || echo "Unknown"
}

blueprint_version() { 
    local ver=""
    if [[ -f "$PANEL_DIR/blueprint.sh" ]]; then
        ver=$(grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/blueprint.sh" | head -n1)
    fi
    if [[ -z "$ver" && -f "$PANEL_DIR/.blueprintrc" ]]; then
        ver=$(grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/.blueprintrc" | head -n1)
    fi
    echo "${ver:-Unknown}"
}

make_backup() {
  valid_panel_dir || { err "Panel directory invalid."; return 1; }
  local stamp archive
  stamp="$(date '+%Y%m%d-%H%M%S')"
  archive="$BACKUP_DIR/panel-blueprint-$stamp.tar.gz"
  info "Creating backup: $archive"
  tar -czf "$archive" -C "$PANEL_DIR" --ignore-failed-read .blueprintrc blueprint.sh blueprint release.zip resources public app routes 2>/dev/null || { rm -f "$archive"; err "Backup failed."; return 1; }
  chmod 600 "$archive"; ok "Backup created: $archive"
}

install_dependencies() {
  need_root || return 1
  if ! command_exists apt-get; then err "Requires Debian/Ubuntu (apt)."; return 1; fi
  info "Installing system dependencies..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git gnupg unzip wget zip
  install -d -m 0755 /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/nodesource.gpg ]]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    chmod 0644 /etc/apt/keyrings/nodesource.gpg
  fi
  printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  if ! command_exists yarn; then npm install --global yarn; fi
  ok "Dependencies ready."
}

install_blueprint() {
  need_root || return 1
  if detect_blueprint; then warn "Blueprint already installed."; return 1; fi
  echo; warn "This installs Blueprint into: $PANEL_DIR"
  read -r -p "Continue? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  install_dependencies || return 1
  TMP_DIR="$(mktemp -d)"; info "Downloading latest Blueprint..."
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"; (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint installed successfully."
}

update_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed."; return 1; }
  read -r -p "Create backup and continue? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  TMP_DIR="$(mktemp -d)"; curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"; (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint update completed."
}

reinstall_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed."; return 1; }
  read -r -p "Continue after backup? [y/N]: " answer; [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1; TMP_DIR="$(mktemp -d)"; install_dependencies || return 1
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"; (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint reinstall completed."
}

blueprint_info() {
  echo; printf '%s\n' "Blueprint directory : $PANEL_DIR"
  printf 'Blueprint detected  : '; detect_blueprint && echo "YES" || echo "NO"
  printf 'Panel version       : %s\n' "$(panel_version)"
  printf 'Blueprint version   : %s\n' "$(blueprint_version)"
  printf 'Node.js             : %s\n' "$(node --version 2>/dev/null || echo Missing)"
  printf 'Yarn                : %s\n' "$(yarn --version 2>/dev/null || echo Missing)"
  echo
}

uninstall_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not detected."; return 1; }
  warn "Automatic uninstall is disabled to prevent breaking your panel."
  read -r -p "Create a safety backup now? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] && make_backup
}
