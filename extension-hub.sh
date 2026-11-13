#!/usr/bin/env bash
# Extension Hub v5.0 - Masterpiece Edition (Photo 2 Finish)
# Made by Ziro | Powered by NexyonCloud
set -Eeuo pipefail

APP_NAME="Extension Hub"
APP_VERSION="v5.0"
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
  C_PURPLE=$'\033[38;5;135m'; C_PINK=$'\033[38;5;213m'
  C_GRAY=$'\033[38;5;240m'
  # Background colors for the pills
  C_BG_BLUE=$'\033[48;5;18m'; C_BG_PURPLE=$'\033[48;5;53m'
  C_BG_GREEN=$'\033[48;5;22m'; C_BG_RED=$'\033[48;5;52m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_CYAN=""; C_BLUE=""
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_WHITE=""; C_PURPLE=""; C_PINK=""; C_GRAY=""
  C_BG_BLUE=""; C_BG_PURPLE=""; C_BG_GREEN=""; C_BG_RED=""
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
log() { local l="$1"; shift; printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$l" "$*" >> "$LOG_FILE" 2>/dev/null || true; }
info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; log INFO "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log OK "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log WARN "$*"; }
err()  { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log ERROR "$*"; }
pause() { echo; read -r -p "Press Enter to continue..." _ || true; }

# ---------- helpers ----------
need_root() { [[ "$EUID" -eq 0 ]] || { err "Run as root: sudo -E bash $0"; return 1; }; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
valid_panel_dir() { [[ -d "$PANEL_DIR" && -f "$PANEL_DIR/artisan" && -f "$PANEL_DIR/composer.json" ]]; }
detect_web_user() { id www-data >/dev/null 2>&1 && echo "www-data" || (id nginx >/dev/null 2>&1 && echo "nginx" || echo "apache"); }
detect_blueprint() { valid_panel_dir && [[ -f "$PANEL_DIR/blueprint.sh" && -f "$PANEL_DIR/.blueprintrc" ]]; }
panel_version() { valid_panel_dir && command_exists php && (cd "$PANEL_DIR" && php artisan --version 2>/dev/null | sed 's/^Laravel Framework //') || echo "Unknown"; }
blueprint_version() { [[ -f "$PANEL_DIR/blueprint.sh" ]] && grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/blueprint.sh" | head -n1 || echo ""; }

# ---------- System Stats for UI ----------
get_cpu_usage() {
    local cpu
    cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    printf "%.0f" "${cpu:-0}"
}
get_ram_usage() {
    free -m 2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}' || echo "0"
}
get_network_status() {
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then printf "${C_GREEN}● CONNECTED${C_RESET}"; else printf "${C_RED}● DISCONNECTED${C_RESET}"; fi
}
get_uptime() {
    # Short format for top bar (e.g., 5 days, 1 hour)
    uptime -p 2>/dev/null | sed 's/up //; s/ weeks/ weeks,/; s/ days/ days,/' || echo "Unknown"
}
get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%"
}
get_current_user() {
    echo "${USER:-root}"
}

# ==========================================
# UI & DISPLAY
# ==========================================

center_line() {
    local text="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    # Strip ANSI color codes to calculate actual string length
    local clean_text=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#clean_text}
    local padding=$(( (cols - len) / 2 ))
    if [ "$padding" -lt 0 ]; then padding=0; fi
    printf "%${padding}s%s\n" "" "$text"
}

# Draw Top Bar (Photo 2 Style Pills)
draw_top_bar() {
    local user=$(get_current_user)
    local up=$(get_uptime)
    local disk=$(get_disk_usage)
    local ram=$(get_ram_usage)
    local cpu=$(get_cpu_usage)
    
    # Building the pill strings
    local p1="${C_BG_BLUE}${C_WHITE}  ${user} ${C_RESET}"
    local p2="${C_BG_PURPLE}${C_WHITE}  ${up} ${C_RESET}"
    local p3="${C_BG_GREEN}${C_WHITE}  ${disk} ${C_RESET}"
    local p4="${C_BG_RED}${C_WHITE}  RAM ${ram}% ${C_RESET}"
    local p5="${C_BG_GREEN}${C_WHITE} CPU ${cpu}% ${C_RESET}"
    
    # Print with spacing
    printf "  %s  %s  %s  %s  %s\n" "$p1" "$p2" "$p3" "$p4" "$p5"
}

# Draw 3D Block Logo (Photo 2 Style)
show_logo() {
    local line
    printf "${C_CYAN}"
    while IFS= read -r line; do
        center_line "$line"
    done <<'LOGO'
███████╗██╗  ██╗████████╗███████╗███╗   ██╗███████╗██╗ ██████╗ ███╗   ██╗    ██╗  ██╗██╗   ██╗██████╗ 
██╔════╝╚██╗██╔╝╚══██╔══╝██╔════╝████╗  ██║██╔════╝██║██╔═══██╗████╗  ██║    ██║  ██║██║   ██║██╔══██╗
█████╗   ╚███╔╝    ██║   █████╗  ██╔██╗ ██║███████╗██║██║   ██║██╔██╗ ██║    ███████║██║   ██║██████╔╝
██╔══╝   ██╔██╗    ██║   ██╔══╝  ██║╚██╗██║╚════██║██║██║   ██║██║╚██╗██║    ██╔══██║██║   ██║██╔══██╗
███████╗██╔╝ ██╗   ██║   ███████╗██║ ╚████║███████║██║╚██████╔╝██║ ╚████║    ██║  ██║╚██████╔╝██████╔╝
╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
LOGO
    printf "${C_RESET}\n"
center_line "${C_YELLOW}Z I R O   E D I T I O N   —   O B S I D I A N   N E X T   G E N${C_RESET}"
center_line "${C_GRAY}Powered by NexyonCloud${C_RESET}"
    echo ""
}

draw_ui() {
    clear 2>/dev/null || true
    
    # Top Bar
    draw_top_bar
    local cols=$(tput cols 2>/dev/null || echo 80)
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 $cols))"
    
    # Logo
    show_logo

    # System Status
    printf " ${C_WHITE}●${C_RESET} ${C_BOLD}SYSTEM STATUS${C_RESET}\n"
    printf "   ${C_DIM}CPU Usage:${C_RESET} ${C_CYAN}%s%%${C_RESET}     " "$(get_cpu_usage)"
    printf "${C_DIM}RAM Usage:${C_RESET} ${C_CYAN}%s%%${C_RESET}     " "$(get_ram_usage)"
    printf "${C_DIM}Network:${C_RESET} %s\n\n" "$(get_network_status)"

    # DEPLOYMENT & SERVICES Section
    printf " ${C_CYAN}::${C_RESET} ${C_BOLD}DEPLOYMENT & SERVICES${C_RESET}\n"
    printf "  ├── ${C_WHITE}[${C_YELLOW}1${C_WHITE}]${C_RESET} %-20s  " "Panel"
    printf "├── ${C_WHITE}[${C_YELLOW}5${C_WHITE}]${C_RESET} %-20s\n" "System"
    printf "  ├── ${C_WHITE}[${C_YELLOW}2${C_WHITE}]${C_RESET} %-20s  " "Wings"
    printf "├── ${C_WHITE}[${C_YELLOW}6${C_WHITE}]${C_RESET} %-20s\n" "Container"
    printf "  ├── ${C_WHITE}[${C_YELLOW}3${C_WHITE}]${C_RESET} %-20s  " "Toolbox"
    printf "├── ${C_WHITE}[${C_YELLOW}7${C_WHITE}]${C_RESET} %-20s\n" "Backup"
    printf "  └── ${C_WHITE}[${C_YELLOW}4${C_WHITE}]${C_RESET} %-20s  " "Theme"
    printf "└── ${C_WHITE}[${C_YELLOW}8${C_WHITE}]${C_RESET} %-20s\n" "About"
    echo ""
    
    # MAINTENANCE & TOOLS Section
    printf " ${C_PURPLE}::${C_RESET} ${C_BOLD}MAINTENANCE & TOOLS${C_RESET}\n"
    printf "  ├── ${C_WHITE}[${C_YELLOW}9${C_WHITE}]${C_RESET} %-30s " "New Models (Custom)"
    printf "${C_RED}[${C_BOLD}0${C_RESET}${C_RED}] SHUTDOWN SYSTEM${C_RESET}\n"
    printf "  └── ${C_WHITE}[${C_YELLOW}10${C_WHITE}]${C_RESET} %-30s\n" "Help & Docs"
    echo ""
    
    # Bottom separator
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 $cols))"
}

# ==========================================
# MENU ACTIONS
# ==========================================

menu_panel() {
    clear
    printf "${C_CYAN}=== PANEL MANAGER ===${C_RESET}\n\n"
    if detect_blueprint; then
        printf " ${C_GREEN}● Status: ONLINE${C_RESET} (Blueprint v%s)\n\n" "$(blueprint_version)"
        printf "1. Reinstall Panel\n2. Update Panel\n3. Panel Info\n4. Uninstall Blueprint\n0. Back\n\n"
        read -r -p "Select: " ch
        case "$ch" in
            1) reinstall_blueprint; pause ;;
            2) update_blueprint; pause ;;
            3) blueprint_info; pause ;;
            4) uninstall_blueprint; pause ;;
        esac
    else
        printf " ${C_RED}● Status: OFFLINE${C_RESET} (Blueprint not found)\n\n"
        printf "1. Install Panel (Blueprint)\n0. Back\n\n"
        read -r -p "Select: " ch
        case "$ch" in
            1) install_blueprint; pause ;;
        esac
    fi
}

menu_wings() {
    clear
    printf "${C_CYAN}=== WINGS NODE MANAGER ===${C_RESET}\n\n"
    warn "Wings management is not implemented yet."
    pause
}

menu_toolbox() {
    clear
    printf "${C_CYAN}=== TOOLBOX ===${C_RESET}\n\n"
    printf "1. System Check\n2. View Logs\n3. Clear Cache\n0. Back\n\n"
    read -r -p "Select: " ch
    case "$ch" in
        1) system_check; pause ;;
        2) view_logs; pause ;;
        3) warn "Cache clear not implemented."; pause ;;
    esac
}

menu_theme() {
    clear
    printf "${C_CYAN}=== THEMES ===${C_RESET}\n\n"
    warn "Theme manager coming soon."
    pause
}

menu_system() {
    clear
    printf "${C_CYAN}=== SYSTEM INFO ===${C_RESET}\n\n"
    printf "OS: %s\n" "$(uname -sr)"
    printf "Uptime: %s\n" "$(uptime -p)"
    printf "Memory: %s\n" "$(free -h | awk '/Mem:/ {print $3 " / " $2}')"
    printf "Disk: %s\n" "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
    pause
}

menu_container() {
    clear
    printf "${C_CYAN}=== CONTAINERS ===${C_RESET}\n\n"
    if command_exists docker; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        warn "Docker is not installed."
    fi
    pause
}

menu_backup() {
    clear
    printf "${C_CYAN}=== BACKUP MANAGER ===${C_RESET}\n\n"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lh "$BACKUP_DIR" 2>/dev/null || true
    else
        warn "No backups found."
    fi
    echo
    read -r -p "Create new backup? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        need_root && make_backup && ok "Backup completed."
    fi
    pause
}

menu_about() {
    clear
    printf "${C_CYAN}=== ABOUT ===${C_RESET}\n\n"
    printf "Extension Hub %s\n" "$APP_VERSION"
    printf "Author: %s\n" "$AUTHOR"
    printf "Blueprint Status: %s\n" "$(detect_blueprint && echo "ONLINE" || echo "OFFLINE")"
    pause
}

menu_new_models() {
    clear
    printf "${C_CYAN}=== NEW MODELS (CUSTOM) ===${C_RESET}\n\n"
    printf "Yahan aap apna khud ka banaya hua chisa add kar sakte hain.\n"
    printf "Aap is function (menu_new_models) ke andar apna code likh sakte hain.\n\n"
    pause
}

menu_help() {
    clear
    printf "${C_CYAN}=== HELP & DOCS ===${C_RESET}\n\n"
    printf "1. Panel: Manage Pterodactyl Panel & Blueprint.\n"
    printf "2. Wings: Manage Daemon Nodes.\n"
    printf "3. Toolbox: System checks & Logs.\n"
    printf "4. Theme: Change UI Themes.\n"
    printf "5. System: View Hardware Info.\n"
    printf "6. Container: View Docker containers.\n"
    printf "7. Backup: Create and view backups.\n"
    printf "8. About: Information about this tool.\n"
    printf "9. New Models: Your custom space.\n"
    printf "10. Help: This menu.\n"
    pause
}

# ==========================================
# CORE LOGIC (Blueprint & System)
# ==========================================

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
  echo
  warn "This installs Blueprint into: $PANEL_DIR"
  read -r -p "Continue? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return 0
  
  make_backup || return 1
  install_dependencies || return 1
  
  TMP_DIR="$(mktemp -d)"
  info "Downloading latest Blueprint..."
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint installed successfully."
}

update_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed."; return 1; }
  read -r -p "Create backup and continue? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  TMP_DIR="$(mktemp -d)"
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint update completed."
}

reinstall_blueprint() {
  need_root || return 1
  detect_blueprint || { err "Blueprint is not installed."; return 1; }
  read -r -p "Continue after backup? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || return 0
  make_backup || return 1
  TMP_DIR="$(mktemp -d)"
  install_dependencies || return 1
  curl -fL --retry 3 "$BLUEPRINT_RELEASE_URL" -o "$TMP_DIR/release.zip"
  cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
  (cd "$PANEL_DIR" && unzip -o release.zip && yarn install)
  chmod +x "$PANEL_DIR/blueprint.sh"
  (cd "$PANEL_DIR" && bash ./blueprint.sh)
  ok "Blueprint reinstall completed."
}

blueprint_info() {
  echo
  printf '%s\n' "Blueprint directory : $PANEL_DIR"
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

system_check() {
    echo "=== SYSTEM CHECK ==="
    printf 'Root User    : %s\n' "$([[ $EUID -eq 0 ]] && echo YES || echo NO)"
    printf 'Panel Dir    : %s\n' "$PANEL_DIR"
    printf 'Panel Valid  : %s\n' "$(valid_panel_dir && echo YES || echo NO)"
    printf 'Blueprint    : %s\n' "$(detect_blueprint && echo YES || echo NO)"
    printf 'Node.js      : %s\n' "$(node --version 2>/dev/null || echo Missing)"
    printf 'Yarn         : %s\n' "$(yarn --version 2>/dev/null || echo Missing)"
}

view_logs() {
    if [ -f "$LOG_FILE" ]; then tail -n 20 "$LOG_FILE"; else warn "No logs found."; fi
}

# ==========================================
# MAIN LOOP
# ==========================================

main_menu() {
    while true; do
        draw_ui
        read -r -p " ➔ Enter Option (0-10): " choice || exit 0
        
        case "$choice" in
            1) menu_panel ;;
            2) menu_wings ;;
            3) menu_toolbox ;;
            4) menu_theme ;;
            5) menu_system ;;
            6) menu_container ;;
            7) menu_backup ;;
            8) menu_about ;;
            9) menu_new_models ;;
            10) menu_help ;;
            0) clear; echo "Shutting down..."; exit 0 ;;
            *) warn "Invalid option. Please select 0-10."; sleep 1 ;;
        esac
    done
}

# ==========================================
# ENTRY POINT
# ==========================================
case "${1:-}" in
  help|-h|--help)
    echo "Usage: extension-hub"
    ;;
  *) main_menu ;;
esac
