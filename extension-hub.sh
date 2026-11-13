#!/usr/bin/env bash
# Extension Hub v1.2 - Pterodactyl Panel manager (UI Overhaul)
# Made by Ziro | Powered by NexyonCloud
set -Eeuo pipefail

APP_NAME="Extension Hub"
APP_VERSION="v1.2"
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

# ---------- cleanup ----------
cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$STATE_DIR" "$BACKUP_DIR" 2>/dev/null || true

# ---------- logging ----------
log() {
  local level="$1"; shift
  local line="[$(date '+%F %T')] [$level] $*"
  printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}
info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; log INFO "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log OK "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log WARN "$*"; }
err()  { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log ERROR "$*"; }

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

# ==========================================
# UI HELPERS (Screenshot Style)
# ==========================================

center_line() {
    local text="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local len=${#text}
    local padding=$(( (cols - len) / 2 ))
    if [ "$padding" -lt 0 ]; then padding=0; fi
    printf "%${padding}s%s\n" "" "$text"
}

show_logo() {
    local line
    printf "${C_BLUE}"
    while IFS= read -r line; do
        center_line "$line"
    done <<'LOGO'
███████╗██╗  ██╗████████╗███████╗███╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗  ██╗  ██╗██╗   ██╗██████╗
██╔════╝╚██╗██╔╝╚══██╔══╝██╔════╝████╗  ██║██╔════╝██║██╔═══██╗████╗  ██║  ██║  ██║██║   ██║██╔══██╗
█████╗   ╚███╔╝    ██║   █████╗  ██╔██╗ ██║███████╗██║██║   ██║██╔██╗ ██║  ███████║██║   ██║██████╔╝
██╔══╝   ██╔██╗    ██║   ██╔══╝  ██║╚██╗██║╚════██║██║██║   ██║██║╚██╗██║  ██╔══██║██║   ██║██╔══██╗
███████╗██╔╝ ██╗   ██║   ███████╗██║ ╚████║███████║██║╚██████╔╝██║ ╚████║  ██║  ██║╚██████╔╝██████╔╝
╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝
LOGO
    printf "${C_RESET}\n"
}

draw_header() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local box_width=60
    if [ "$cols" -lt 70 ]; then box_width=$((cols - 4)); fi
    local padding=$(( (cols - box_width) / 2 ))
    local pad_str
    pad_str=$(printf "%${padding}s" "")
    
    local title="Extension Hub Control Panel"
    local title_len=${#title}
    local space=$(( (box_width - 2 - title_len) / 2 ))
    local left_space
    left_space=$(printf "%${space}s" "")
    local right_space
    right_space=$(printf "%$((box_width - 2 - title_len - space))s" "")

    printf "${C_BLUE}%s╔" "$pad_str"
    for ((i=0; i<box_width-2; i++)); do printf "═"; done
    printf "╗${C_RESET}\n"
    
    printf "${C_BLUE}%s║${C_CYAN}%s${C_BOLD}%s${C_RESET}${C_BLUE}%s║${C_RESET}\n" "$pad_str" "$left_space" "$title" "$right_space"
    
    printf "${C_BLUE}%s╚" "$pad_str"
    for ((i=0; i<box_width-2; i++)); do printf "═"; done
    printf "╝${C_RESET}\n"
}

# Global array for menu items: "ID|Name|Status(0=Red,1=Green)|ActionFunction"
MENU_ITEMS=(
    "01|Blueprint Manager|0|blueprint_menu"
    "02|Panel Info|0|panel_info_menu"
    "03|Themes|0|placeholder_menu_Themes"
    "04|Extensions|0|placeholder_menu_Extensions"
    "05|Zerix Theme|0|coming_soon_Zerix"
    "06|System Check|0|system_check"
    "07|Logs Viewer|0|view_logs"
    "08|Backups|0|backup_menu"
    "09|About|0|about_menu"
    "10|Update Hub|0|update_hub"
    "11|Settings|0|settings_menu"
    "12|Help|0|help_menu"
)

declare -a SELECTED_ITEMS

parse_item() {
    IFS='|' read -r ID NAME STATUS ACTION <<< "$1"
}

draw_menu() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local mid_col=$(( cols / 2 ))
    local half=$(( (${#MENU_ITEMS[@]} + 1) / 2 ))
    
    # Auto-update status for Blueprint
    MENU_ITEMS[0]="01|Blueprint Manager|$([[ $(detect_blueprint && echo 1 || echo 0) -eq 1 ]] && echo 1 || echo 0)|blueprint_menu"

    for ((i=0; i<half; i++)); do
        # Left Column
        parse_item "${MENU_ITEMS[$i]}"
        print_item "$ID" "$NAME" "$STATUS" 2 $((i))
        
        # Right Column
        local right_index=$((i + half))
        if [ "$right_index" -lt "${#MENU_ITEMS[@]}" ]; then
            parse_item "${MENU_ITEMS[$right_index]}"
            print_item "$ID" "$NAME" "$STATUS" $mid_col $((i))
        fi
    done
}

print_item() {
    local id=$1
    local name=$2
    local status=$3
    local x_pos=$4
    local y_pos=$5
    
    tput cup $((11 + y_pos)) $x_pos
    
    local is_selected=0
    for s in "${SELECTED_ITEMS[@]}"; do
        if [ "$s" == "$id" ]; then is_selected=1; break; fi
    done
    
    if [ "$is_selected" -eq 1 ]; then
        printf "${C_YELLOW}%-2s %-26s" "$id" "$name"
    else
        printf "${C_WHITE}%-2s %-26s" "$id" "$name"
    fi
    
    if [ "$status" == "1" ]; then
        printf "${C_GREEN}●${C_RESET}"
    else
        printf "${C_RED}○${C_RESET}"
    fi
}

draw_footer() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local half=$(( (${#MENU_ITEMS[@]} + 1) / 2 ))
    tput cup $((11 + half + 2)) 0
    
    local sel_count=${#SELECTED_ITEMS[@]}
    printf "${C_WHITE}SELECTED: ${C_YELLOW}%d${C_WHITE} items${C_RESET}\n\n" "$sel_count"
    
    printf "${C_GREEN}[1] Run Selected  ${C_RED}[c] Clear  ${C_BLUE}[a] Select All  ${C_WHITE}[0] Exit${C_RESET}\n\n"
    printf "👉 ${C_YELLOW}Select ID(s) or Action: ${C_RESET}"
}

# ==========================================
# MENU ACTIONS
# ==========================================

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

panel_info_menu() {
    clear 2>/dev/null || true
    echo "=== PANEL INFO ==="
    blueprint_info
    pause
}

placeholder_menu_Themes() {
    clear 2>/dev/null || true
    warn "Themes section is not implemented yet."
    pause
}

placeholder_menu_Extensions() {
    clear 2>/dev/null || true
    warn "Extensions section is not implemented yet."
    pause
}

coming_soon_Zerix() {
    clear 2>/dev/null || true
    warn "Zerix Theme is coming soon."
    pause
}

system_check() {
    clear 2>/dev/null || true
    echo "=== SYSTEM CHECK ==="
    printf 'Root User    : %s\n' "$([[ $EUID -eq 0 ]] && echo YES || echo NO)"
    printf 'Panel Dir    : %s\n' "$PANEL_DIR"
    printf 'Panel Valid  : %s\n' "$(valid_panel_dir && echo YES || echo NO)"
    printf 'Blueprint    : %s\n' "$(detect_blueprint && echo YES || echo NO)"
    printf 'Node.js      : %s\n' "$(node --version 2>/dev/null || echo Missing)"
    printf 'Yarn         : %s\n' "$(yarn --version 2>/dev/null || echo Missing)"
    pause
}

view_logs() {
    clear 2>/dev/null || true
    if [ -f "$LOG_FILE" ]; then
        echo "=== LAST 20 LOGS ==="
        tail -n 20 "$LOG_FILE"
    else
        warn "No logs found."
    fi
    pause
}

backup_menu() {
    clear 2>/dev/null || true
    echo "=== BACKUPS ==="
    if [ -d "$BACKUP_DIR" ]; then
        ls -lh "$BACKUP_DIR" 2>/dev/null || true
    else
        warn "No backup directory found."
    fi
    echo
    read -r -p "Create new backup now? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        need_root && make_backup && ok "Backup done."
    fi
    pause
}

about_menu() {
    clear 2>/dev/null || true
    show_logo
    echo "Version: $APP_VERSION"
    echo "Author : $AUTHOR"
    echo "Desc   : Pterodactyl Panel Extension Manager"
    pause
}

update_hub() {
    clear 2>/dev/null || true
    info "Checking for updates..."
    warn "Self-update not implemented yet. Download manually from GitHub."
    pause
}

settings_menu() {
    clear 2>/dev/null || true
    echo "=== SETTINGS ==="
    echo "1. Change Panel Directory"
    echo "0. Back"
    read -r -p "Select: " ch
    if [ "$ch" == "1" ]; then
        choose_panel_dir && ok "Panel directory updated."
    fi
    pause
}

help_menu() {
    clear 2>/dev/null || true
    echo "=== HELP ==="
    echo "Use numbers to select items."
    echo "[1] Run Selected - Runs selected actions"
    echo "[c] Clear - Clears selections"
    echo "[a] Select All - Selects all items"
    echo "[0] Exit - Exits the script"
    pause
}

# ==========================================
# CORE LOGIC (Preserved)
# ==========================================

choose_panel_dir() {
  local candidate
  read -r -p "Pterodactyl directory [$PANEL_DIR]: " candidate || true
  candidate="${candidate:-$PANEL_DIR}"
  if [[ ! -d "$candidate" ]]; then
    err "Directory does not exist: $candidate"
    return 1
  fi
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

# ==========================================
# MAIN MENU LOOP
# ==========================================

main_menu() {
    while true; do
        clear
        show_logo
        draw_header
        
        while true; do
            draw_menu
            draw_footer
            
            read -r input
            
            case "$input" in
                "0"|"exit")
                    clear
                    echo "Goodbye."
                    exit 0
                    ;;
                "a"|"A")
                    SELECTED_ITEMS=()
                    for item in "${MENU_ITEMS[@]}"; do
                        parse_item "$item"
                        SELECTED_ITEMS+=("$ID")
                    done
                    ;;
                "c"|"C")
                    SELECTED_ITEMS=()
                    ;;
                "1")
                    if [ ${#SELECTED_ITEMS[@]} -eq 0 ]; then
                        echo -e "\n${C_RED}Error: No items selected!${C_RESET}"
                        sleep 1
                    else
                        for sel in "${SELECTED_ITEMS[@]}"; do
                            for item in "${MENU_ITEMS[@]}"; do
                                parse_item "$item"
                                if [ "$ID" == "$sel" ]; then
                                    # Call the action function
                                    if declare -f "$ACTION" > /dev/null; then
                                        $ACTION
                                    else
                                        err "Action not found: $ACTION"
                                    fi
                                    break
                                fi
                            done
                        done
                        SELECTED_ITEMS=()
                        # Pause after running actions to let user read
                        echo
                        read -r -p "Press Enter to return to menu..." _
                    fi
                    ;;
                *)
                    for num in $input; do
                        local found=0
                        for item in "${MENU_ITEMS[@]}"; do
                            parse_item "$item"
                            if [ "$ID" == "$num" ]; then
                                found=1
                                local exists=0
                                for s in "${SELECTED_ITEMS[@]}"; do
                                    if [ "$s" == "$num" ]; then exists=1; break; fi
                                done
                                
                                if [ "$exists" -eq 0 ]; then
                                    SELECTED_ITEMS+=("$num")
                                else
                                    local new_sel=()
                                    for s in "${SELECTED_ITEMS[@]}"; do
                                        if [ "$s" != "$num" ]; then new_sel+=("$s"); fi
                                    done
                                    SELECTED_ITEMS=("${new_sel[@]}")
                                fi
                                break
                            fi
                        done
                        if [ "$found" -eq 0 ]; then
                            echo -e "\n${C_RED}Invalid ID: $num${C_RESET}"
                            sleep 1
                        fi
                    done
                    ;;
            esac
        done
    done
}

# ==========================================
# CLI ENTRY POINT
# ==========================================
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
