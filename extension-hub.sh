#!/usr/bin/env bash
# Extension Hub v5.5 - Main UI & Router (Fully Embedded)
set -Eeuo pipefail

APP_NAME="Extension Hub"
APP_VERSION="v5.5"
AUTHOR="Ziro"
LOG_FILE="/var/log/extension-hub.log"
TMP_DIR=""
BASE_URL="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"

# ---------- colors ----------
if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_CYAN=$'\033[38;5;45m'; C_BLUE=$'\033[38;5;39m'
  C_GREEN=$'\033[38;5;82m'; C_YELLOW=$'\033[38;5;220m'
  C_RED=$'\033[38;5;203m'; C_WHITE=$'\033[97m'
  C_PURPLE=$'\033[38;5;135m'; C_GRAY=$'\033[38;5;240m'
  C_PINK=$'\033[38;5;213m'
  C_BG_BLUE=$'\033[48;5;18m'; C_BG_PURPLE=$'\033[48;5;53m'
  C_BG_GREEN=$'\033[48;5;22m'; C_BG_RED=$'\033[48;5;52m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_CYAN=""; C_BLUE=""
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_WHITE=""; C_PURPLE=""; C_GRAY=""; C_PINK=""
  C_BG_BLUE=""; C_BG_PURPLE=""; C_BG_GREEN=""; C_BG_RED=""
fi

cleanup() { [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

log() { local l="$1"; shift; printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$l" "$*" >> "$LOG_FILE" 2>/dev/null || true; }
info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; log INFO "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log OK "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log WARN "$*"; }
err()  { printf '%s[ERR ]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log ERROR "$*"; }
pause() { echo; read -r -p "Press Enter to continue..." _ || true; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------- Load Core Modules (Blueprint & Panels) ----------
load_modules() {
    local module
    for module in "blueprint-core.sh" "panels-core.sh"; do
        local local_file="/opt/extension-hub/$module"
        if [[ ! -f "$local_file" ]]; then
            if ! curl -fsSL --retry 3 "$BASE_URL/$module" -o "/tmp/$module.tmp"; then
                err "Failed to load $module from GitHub."
                return 1
            fi
            local_file="/tmp/$module.tmp"
        fi
        source "$local_file"
        rm -f "/tmp/$module.tmp"
    done
}

# ==========================================
# THEME MENU (Embedded Here)
# ==========================================
playtely_theme_menu() {
    while true; do
        clear 2>/dev/null || true
        
        # Top Box (Cyan Border, Pink Text)
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET}                       ${C_PINK}CONTROL PANEL UI${C_RESET}                       ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
        
        # Status
        if [[ -d "/var/www/pterodactyl" && -f "/var/www/pterodactyl/artisan" ]]; then
            printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_GREEN}● ONLINE${C_RESET}\n\n"
        else
            printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_RED}○ OFFLINE${C_RESET}\n\n"
        fi
        
        # Menu Options (Green numbers, Blue text)
        printf "  ${C_GREEN}[1]${C_RESET} ${C_CYAN}Blueprint${C_RESET}\n"
        printf "  ${C_GREEN}[2]${C_RESET} ${C_CYAN}Theme${C_RESET}\n"
        printf "  ${C_GREEN}[3]${C_RESET} ${C_CYAN}Extensions${C_RESET}\n\n"
        
        printf "  ${C_RED}[0]${C_RESET} ${C_RED}Exit${C_RESET}\n\n"
        
        # Prompt
        read -r -p " ${C_GREEN}▶ Select Option :${C_RESET} " t_choice || return
        
        case "$t_choice" in
            1) 
                clear
                printf "  ${C_CYAN}--- Blueprint Management ---${C_RESET}\n\n"
                warn "Blueprint installation is handled from Panel -> [1] Pterodactyl v1 -> [1] Install."
                pause 
                ;;
            2) 
                clear
                printf "  ${C_CYAN}--- Theme Management ---${C_RESET}\n\n"
                warn "Theme manager coming soon."
                pause 
                ;;
            3) 
                clear
                printf "  ${C_CYAN}--- Extensions ---${C_RESET}\n\n"
                warn "Extensions manager coming soon."
                pause 
                ;;
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

# ---------- System Stats ----------
get_cpu_usage() {
    local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    printf "%.0f" "${cpu:-0}"
}
get_ram_usage() { free -m 2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}' || echo "0"; }
get_network_status() { if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then printf "${C_GREEN}● CONNECTED${C_RESET}"; else printf "${C_RED}● DISCONNECTED${C_RESET}"; fi; }
get_uptime() { uptime -p 2>/dev/null | sed 's/up //; s/ weeks/ weeks,/; s/ days/ days,/' || echo "Unknown"; }
get_disk_usage() { df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%"; }
get_current_user() { echo "${USER:-root}"; }

# ---------- UI ----------
center_line() {
    local text="$1"; local cols=$(tput cols 2>/dev/null || echo 80)
    local clean_text=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#clean_text}; local padding=$(( (cols - len) / 2 ))
    [[ "$padding" -lt 0 ]] && padding=0
    printf "%${padding}s%s\n" "" "$text"
}

draw_top_bar() {
    local user=$(get_current_user); local up=$(get_uptime); local disk=$(get_disk_usage)
    local ram=$(get_ram_usage); local cpu=$(get_cpu_usage)
    local p1="${C_BG_BLUE}${C_WHITE}  ${user} ${C_RESET}"
    local p2="${C_BG_PURPLE}${C_WHITE}  ${up} ${C_RESET}"
    local p3="${C_BG_GREEN}${C_WHITE}  ${disk} ${C_RESET}"
    local p4="${C_BG_RED}${C_WHITE}  RAM ${ram}% ${C_RESET}"
    local p5="${C_BG_GREEN}${C_WHITE} CPU ${cpu}% ${C_RESET}"
    printf "  %s  %s  %s  %s  %s\n" "$p1" "$p2" "$p3" "$p4" "$p5"
}

show_logo() {
    printf "${C_CYAN}"
    while IFS= read -r line; do center_line "$line"; done <<'LOGO'
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
    draw_top_bar
    local cols=$(tput cols 2>/dev/null || echo 80)
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 $cols))"
    show_logo

    printf " ${C_WHITE}●${C_RESET} ${C_BOLD}SYSTEM STATUS${C_RESET}\n"
    printf "   ${C_DIM}CPU Usage:${C_RESET} ${C_CYAN}%s%%${C_RESET}     " "$(get_cpu_usage)"
    printf "${C_DIM}RAM Usage:${C_RESET} ${C_CYAN}%s%%${C_RESET}     " "$(get_ram_usage)"
    printf "${C_DIM}Network:${C_RESET} %s\n\n" "$(get_network_status)"

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
    
    printf " ${C_PURPLE}::${C_RESET} ${C_BOLD}MAINTENANCE & TOOLS${C_RESET}\n"
    printf "  ├── ${C_WHITE}[${C_YELLOW}9${C_WHITE}]${C_RESET} %-30s " "New Models (Custom)"
    printf "${C_RED}[${C_BOLD}0${C_RESET}${C_RED}] SHUTDOWN SYSTEM${C_RESET}\n"
    printf "  └── ${C_WHITE}[${C_YELLOW}10${C_WHITE}]${C_RESET} %-30s\n" "Help & Docs"
    echo ""
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 $cols))"
}

menu_wings() { clear; printf "${C_CYAN}=== WINGS NODE MANAGER ===${C_RESET}\n\n"; warn "Wings management is not implemented yet."; pause; }
menu_toolbox() { clear; printf "${C_CYAN}=== TOOLBOX ===${C_RESET}\n\n1. System Check\n2. View Logs\n0. Back\n\n"; read -r -p "Select: " ch; case "$ch" in 1) system_check; pause;; 2) view_logs; pause;; esac; }
menu_system() { clear; printf "${C_CYAN}=== SYSTEM INFO ===${C_RESET}\n\nOS: %s\nUptime: %s\nMemory: %s\nDisk: %s\n" "$(uname -sr)" "$(uptime -p)" "$(free -h | awk '/Mem:/ {print $3 " / " $2}')" "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"; pause; }
menu_container() { clear; printf "${C_CYAN}=== CONTAINERS ===${C_RESET}\n\n"; if command_exists docker; then docker ps --format "table {{.Names}}\t{{.Status}}"; else warn "Docker not installed."; fi; pause; }
menu_backup() { clear; printf "${C_CYAN}=== BACKUP MANAGER ===${C_RESET}\n\n"; ls -lh "$BACKUP_DIR" 2>/dev/null || warn "No backups found."; echo; read -r -p "Create new backup? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && { need_root && make_backup && ok "Done."; }; pause; }
menu_about() { clear; printf "${C_CYAN}=== ABOUT ===${C_RESET}\n\nExtension Hub %s\nAuthor: %s\nBlueprint: %s\n" "$APP_VERSION" "$AUTHOR" "$(detect_blueprint && echo "ONLINE" || echo "OFFLINE")"; pause; }
menu_new_models() { clear; printf "${C_CYAN}=== NEW MODELS (CUSTOM) ===${C_RESET}\n\nYahan aap apna custom code likh sakte hain.\n\n"; pause; }
menu_help() { clear; printf "${C_CYAN}=== HELP ===${C_RESET}\n\n1. Panel: Install/Manage Blueprint.\n2. Wings: Daemon nodes.\n3. Toolbox: System check.\n4. Theme: UI themes.\n5. System: Hardware info.\n6. Container: Docker.\n7. Backup: Backups.\n8. About: Info.\n9. New Models: Custom.\n10. Help.\n"; pause; }
system_check() { echo "=== SYSTEM CHECK ==="; printf 'Root: %s\nPanel: %s\nBlueprint: %s\nNode: %s\n' "$([[ $EUID -eq 0 ]] && echo YES || echo NO)" "$PANEL_DIR" "$(detect_blueprint && echo YES || echo NO)" "$(node --version 2>/dev/null || echo Missing)"; }
view_logs() { if [ -f "$LOG_FILE" ]; then tail -n 20 "$LOG_FILE"; else warn "No logs found."; fi; }

# ==========================================
# MAIN LOOP
# ==========================================
main_menu() {
    load_modules || exit 1
    while true; do
        draw_ui
        read -r -p " ➔ Enter Option (0-10): " choice || exit 0
        case "$choice" in
            1) menu_panel ;;
            2) menu_wings ;;
            3) menu_toolbox ;;
            4) playtely_theme_menu ;; # <--- Yahan Theme Menu Call Ho Raha Hai
            5) menu_system ;;
            6) menu_container ;;
            7) menu_backup ;;
            8) menu_about ;;
            9) menu_new_models ;;
            10) menu_help ;;
            0) clear; echo "Shutting down..."; exit 0 ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
  help|-h|--help) echo "Usage: extension-hub" ;;
  *) main_menu ;;
esac
