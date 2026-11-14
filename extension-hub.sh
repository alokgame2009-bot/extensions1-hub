#!/usr/bin/env bash
# Extension Hub v1.2 - Fixed & Restored
set -Eeuo pipefail

APP_NAME="Extension Hub"
APP_VERSION="v1.2"
AUTHOR="Ziro"
LOG_FILE="/var/log/extension-hub.log"
TMP_DIR=""
BASE_URL="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
EXT_GITHUB_RAW="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main/extensions"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/extension-hub}"

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
need_root() { [[ "$EUID" -eq 0 ]] || { err "Run as root."; return 1; }; }
valid_panel_dir() { [[ -d "$PANEL_DIR" && -f "$PANEL_DIR/artisan" && -f "$PANEL_DIR/composer.json" ]]; }

detect_blueprint() {
    valid_panel_dir && [[ -f "$PANEL_DIR/blueprint.sh" && -f "$PANEL_DIR/.blueprintrc" ]] &&
    { [[ -x /usr/local/bin/blueprint ]] || command_exists blueprint; }
}
blueprint_version() { [[ -f "$PANEL_DIR/blueprint.sh" ]] && grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/blueprint.sh" | head -n1 || echo ""; }
panel_version() { valid_panel_dir && command_exists php && (cd "$PANEL_DIR" && php artisan --version 2>/dev/null | sed 's/^Laravel Framework //') || echo "Unknown"; }

# ==========================================
# SYSTEM STATS (SAFE VERSION)
# ==========================================
get_cpu_usage() { 
    local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu=$(echo "$cpu" | tr -d '\n' | tr -d ' ')
    printf "%.0f" "${cpu:-0}"
}
get_ram_usage() { 
    local ram=$(free -m 2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    ram=$(echo "$ram" | tr -d '\n' | tr -d ' ')
    printf "%.0f" "${ram:-0}"
}
get_network_status() { 
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then 
        printf "${C_GREEN}CONNECTED${C_RESET}"
    else 
        printf "${C_RED}DISCONNECTED${C_RESET}"
    fi
}
get_uptime() { 
    local up=$(uptime -p 2>/dev/null | sed 's/up //')
    echo "$up" | tr -d '\n'
}
get_disk_usage() { 
    local disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}')
    echo "$disk" | tr -d '\n'
}
get_current_user() { echo "${USER:-root}"; }

# ==========================================
# REAL EXTENSION LOGIC
# ==========================================
install_ext() {
    local ext_id="$1" ext_name="$2"
    need_root || return 1
    valid_panel_dir || { err "Panel not found."; return 1; }
    command_exists blueprint || { err "Install Blueprint first."; return 1; }
    panel_artisan_health_check || return 1

    local package_file="$PANEL_DIR/${ext_name}.blueprint"
    local download_tmp="$(mktemp "$PANEL_DIR/.${ext_name}.XXXXXX")"

    info "Downloading ${ext_name}.blueprint..."
    if ! curl -fL --retry 3 "${EXT_GITHUB_RAW}/${ext_name}.blueprint" -o "$download_tmp"; then
        rm -f "$download_tmp"
        err "Download failed."
        return 1
    fi
    if [[ ! -s "$download_tmp" ]]; then
        rm -f "$download_tmp"
        err "Downloaded file is empty."
        return 1
    fi
    mv "$download_tmp" "$package_file"
    info "Installing $ext_name..."
    if (cd "$PANEL_DIR" && blueprint -install "$ext_name"); then
        rm -f "$package_file"
        ok "Installed $ext_name successfully."
        return 0
    fi
    rm -f "$package_file"
    err "Installation failed."
    return 1
}

remove_ext() {
    local ext_id="$1" ext_name="$2"
    need_root || return 1
    valid_panel_dir || { err "Panel not found."; return 1; }
    command_exists blueprint || { err "Blueprint CLI not installed."; return 1; }
    if (cd "$PANEL_DIR" && blueprint -remove "$ext_name"); then
        ok "Removed $ext_name."
        return 0
    fi
    err "Removal failed."
    return 1
}

extension_is_installed() {
    local name="$1" root="$PANEL_DIR"
    [[ -d "$root/.blueprint/extensions/$name" ]] && return 0
    [[ -d "$root/app/Extensions/$name" ]] && return 0
    [[ -f "$root/app/Extensions/$name.php" ]] && return 0
    [[ -d "$root/extensions/$name" ]] && return 0
    return 1
}

# ==========================================
# EXTENSIONS GRID MENU (PURANA WALA)
# ==========================================
playtely_extensions_menu() {
    local extensions=(
        "1|adminauditlogs" "2|huxregister" "3|loader" "4|lyrdyannounce"
        "5|mclogs" "6|mcplugins" "7|mctools" "8|minecraftplayermanager"
        "9|playerlisting" "10|resourcealerts" "11|resourcemanager" "12|serverbackgrounds"
        "13|serversplitter" "14|simplefavicons" "15|snowflakes" "16|sociallogin"
        "17|startupchanger" "18|subdomains" "19|tawkto" "20|versionchanger"
        "21|pteromonaco" "22|urldownloader" "23|consolelogs" "24|laravellogs"
        "25|vanillatweaks" "26|modrinthbrowser" "27|nopagination" "28|activitypurges"
        "29|redirect" "30|simplefooters" "31|paneladdressoverride" "32|shownodeids"
        "33|votifiertester" "34|sidebar" "35|translations" "36|monacoeditor"
        "37|minecraftpluginmanager" "38|subdomainmanager" "39|serverimporter" "40|pstatistics"
        "41|pullfiles" "42|serverpropsmanager" "43|motdmaker" "44|servericonimporter"
        "45|sagaautosuspension" "46|sagaminecraftmodpackin" "47|blueannouncements" "48|trashbin"
        "49|eggchanger" "50|mysqlautobackup" "51|configeditor" "52|customserversort"
        "53|databaseimportexport" "54|minecraftmodmanager" "55|serverid" "56|stats"
        "57|vminfo" "58|customcss" "59|autobackups" "60|node"
        "61|mcp" "62|mcplayer" "63|pterodactylramburst" "64|pterodactylpanelban"
        "65|pterodactylupburst" "66|pterodactylbackup"
    )
    declare -a selected_extensions=()

    while true; do
        clear 2>/dev/null || true
        printf "${C_CYAN}================================================================${C_RESET}\n"
        printf "${C_CYAN}|                  ${C_PINK}Ziro.dev CONTROL HUB${C_RESET}                    ${C_CYAN}|${C_RESET}\n"
        printf "${C_CYAN}================================================================${C_RESET}\n\n"

        local half=$(( (${#extensions[@]} + 1) / 2 ))
        for ((i=0; i<half; i++)); do
            IFS='|' read -r id1 name1 <<< "${extensions[$i]}"
            local right_index=$((i + half))
            local sel1="[-]"; local col1="${C_GRAY}"
            for s in "${selected_extensions[@]}"; do 
                if [[ "$s" == "$id1" ]]; then sel1="[+]"; col1="${C_GREEN}"; fi
            done
            local status1="O"; local status_col1="${C_RED}"
            if extension_is_installed "$name1"; then status1="●"; status_col1="${C_GREEN}"; fi
            printf " ${col1}%s${C_RESET} ${C_CYAN}%-2s${C_RESET} ${C_WHITE}%-22s${C_RESET} ${status_col1}%s${C_RESET}" "$sel1" "$id1" "$name1" "$status1"

            if [ "$right_index" -lt "${#extensions[@]}" ]; then
                IFS='|' read -r id2 name2 <<< "${extensions[$right_index]}"
                local sel2="[-]"; local col2="${C_GRAY}"
                for s in "${selected_extensions[@]}"; do 
                    if [[ "$s" == "$id2" ]]; then sel2="[+]"; col2="${C_GREEN}"; fi
                done
                local status2="O"; local status_col2="${C_RED}"
                if extension_is_installed "$name2"; then status2="●"; status_col2="${C_GREEN}"; fi
                printf "   ${col2}%s${C_RESET} ${C_CYAN}%-2s${C_RESET} ${C_WHITE}%-22s${C_RESET} ${status_col2}%s${C_RESET}" "$sel2" "$id2" "$name2" "$status2"
            fi
            echo ""
        done
        echo ""

        printf " ${C_BLUE}----------------------------------------------------------------${C_RESET}\n"
        printf " ${C_WHITE}SELECTED: ${C_YELLOW}%d${C_WHITE} items${C_RESET}\n" "${#selected_extensions[@]}"
        printf " ${C_GREEN}[i] Install  ${C_RED}[r] Remove  ${C_BLUE}[a] Select All  ${C_WHITE}[c] Clear  ${C_RED}[0] Exit${C_RESET}\n\n"
        read -r -p " ${C_GREEN}Select ID(s) or Action:${C_RESET} " input

        case "$input" in
            0|"exit") return ;;
            "a"|"A") selected_extensions=(); for ext in "${extensions[@]}"; do IFS='|' read -r id _ <<< "$ext"; selected_extensions+=("$id"); done ;;
            "c"|"C") selected_extensions=() ;;
            "i"|"I")
                if [ ${#selected_extensions[@]} -eq 0 ]; then echo -e "\n${C_RED}Error: No extensions selected!${C_RESET}"; sleep 1
                else
                    for sel in "${selected_extensions[@]}"; do
                        for ext in "${extensions[@]}"; do
                            IFS='|' read -r id name <<< "$ext"
                            if [ "$id" == "$sel" ]; then install_ext "$id" "$name"; fi
                        done
                    done
                    echo -e "\n${C_GREEN}Done!${C_RESET}"; pause
                fi
                ;;
            "r"|"R")
                if [ ${#selected_extensions[@]} -eq 0 ]; then echo -e "\n${C_RED}Error: No extensions selected!${C_RESET}"; sleep 1
                else
                    for sel in "${selected_extensions[@]}"; do
                        for ext in "${extensions[@]}"; do
                            IFS='|' read -r id name <<< "$ext"
                            if [ "$id" == "$sel" ]; then remove_ext "$id" "$name"; fi
                        done
                    done
                    echo -e "\n${C_GREEN}Done!${C_RESET}"; pause
                fi
                ;;
            *)
                for num in $input; do
                    local found=0
                    for ext in "${extensions[@]}"; do
                        IFS='|' read -r id _ <<< "$ext"
                        if [ "$id" == "$num" ]; then
                            found=1
                            local exists=0
                            for s in "${selected_extensions[@]}"; do [[ "$s" == "$num" ]] && exists=1; done
                            if [ "$exists" -eq 0 ]; then selected_extensions+=("$num")
                            else
                                local new_sel=()
                                for s in "${selected_extensions[@]}"; do [[ "$s" != "$num" ]] && new_sel+=("$s"); done
                                selected_extensions=("${new_sel[@]}")
                            fi
                            break
                        fi
                    done
                    if [ "$found" -eq 0 ]; then echo -e "\n${C_RED}Invalid ID: $num${C_RESET}"; sleep 1; fi
                done
                ;;
        esac
    done
}

# ==========================================
# THEME MENU (Jo aapne manga)
# ==========================================
playtely_theme_menu() {
    while true; do
        clear 2>/dev/null || true
        printf "${C_CYAN}================================================================${C_RESET}\n"
        printf "${C_CYAN}|                      ${C_PINK}CONTROL PANEL UI${C_RESET}                      ${C_CYAN}|${C_RESET}\n"
        printf "${C_CYAN}================================================================${C_RESET}\n\n"
        
        if detect_blueprint; then printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_GREEN}● ONLINE${C_RESET}\n\n"
        else printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_RED}O OFFLINE${C_RESET}\n\n"; fi
        
        printf "  ${C_GREEN}[1]${C_RESET} ${C_CYAN}Blueprint${C_RESET}\n"
        printf "  ${C_GREEN}[2]${C_RESET} ${C_CYAN}Theme${C_RESET}\n"
        printf "  ${C_GREEN}[3]${C_RESET} ${C_CYAN}Extensions${C_RESET}\n\n"
        printf "  ${C_RED}[0]${C_RESET} ${C_RED}Exit${C_RESET}\n\n"
        
        read -r -p " ${C_GREEN}Select Option :${C_RESET} " t_choice || return
        
        case "$t_choice" in
            1) 
                while true; do
                    clear 2>/dev/null || true
                    printf "${C_CYAN}================================================================${C_RESET}\n"
                    printf "${C_CYAN}|                      ${C_PINK}CONTROL PANEL UI${C_RESET}                      ${C_CYAN}|${C_RESET}\n"
                    printf "${C_CYAN}================================================================${C_RESET}\n\n"
                    printf " ${C_CYAN}BLUEPRINT PANEL${C_RESET}\n"
                    if detect_blueprint; then
                        printf " ${C_CYAN}Status :${C_RESET} ${C_GREEN}● ONLINE${C_RESET}\n\n"
                        printf " ${C_GREEN}[1]${C_RESET} ${C_CYAN}Repair${C_RESET}\n"
                        printf " ${C_GREEN}[2]${C_RESET} ${C_CYAN}Update${C_RESET}\n"
                        printf " ${C_GREEN}[3]${C_RESET} ${C_CYAN}Info${C_RESET}\n"
                        printf " ${C_GREEN}[4]${C_RESET} ${C_CYAN}Version${C_RESET}\n"
                        printf " ${C_RED}[5]${C_RESET} ${C_RED}Uninstall${C_RESET}\n"
                        printf " ${C_RED}[0]${C_RESET} ${C_RED}Back${C_RESET}\n\n"
                        read -r -p " ${C_GREEN}Select :${C_RESET} " bp_choice || break
                        case "$bp_choice" in
                            1) install_blueprint; pause ;;
                            2) (cd "$PANEL_DIR" && blueprint -upgrade) || err "Update failed."; pause ;;
                            3) (cd "$PANEL_DIR" && blueprint -info) || err "CLI not found."; pause ;;
                            4) printf '\nBlueprint: %s\nPanel: %s\n' "$(blueprint_version)" "$(panel_version)"; pause ;;
                            5) warn "Uninstall disabled for safety."; pause ;;
                            0) break ;;
                            *) warn "Invalid option."; sleep 1 ;;
                        esac
                    else
                        printf " ${C_CYAN}Status :${C_RESET} ${C_RED}O OFFLINE${C_RESET}\n\n"
                        printf " ${C_GREEN}[1]${C_RESET} ${C_CYAN}Install${C_RESET}\n"
                        printf " ${C_RED}[0]${C_RESET} ${C_RED}Back${C_RESET}\n\n"
                        read -r -p " ${C_GREEN}Select :${C_RESET} " bp_choice || break
                        case "$bp_choice" in
                            1) install_blueprint; pause ;;
                            0) break ;;
                            *) warn "Invalid option."; sleep 1 ;;
                        esac
                    fi
                done
                ;;
            2) clear; printf "  ${C_CYAN}--- Theme Management ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            3) playtely_extensions_menu ;; 
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

menu_panel() { playtely_theme_menu; }

# ==========================================
# UI & DRAWING (SAFE ECHO VERSION)
# ==========================================
center_line() { local text="$1"; local cols=$(tput cols 2>/dev/null || echo 80); local clean_text=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g'); local len=${#clean_text}; local padding=$(( (cols - len) / 2 )); [[ "$padding" -lt 0 ]] && padding=0; printf "%${padding}s%s\n" "" "$text"; }

draw_top_bar() {
    local user up disk ram cpu
    user=$(get_current_user)
    up=$(get_uptime)
    disk=$(get_disk_usage)
    ram=$(get_ram_usage)
    cpu=$(get_cpu_usage)
    
    echo -e "  [${C_WHITE}${user}${C_RESET}] [${C_WHITE}${up}${C_RESET}] [${C_WHITE}${disk}${C_RESET}] [${C_WHITE}RAM ${ram}%${C_RESET}] [${C_WHITE}CPU ${cpu}%${C_RESET}]"
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
    center_line "${C_YELLOW}Z I R O   E D I T I O N${C_RESET}"
    center_line "${C_GRAY}Powered by NexyonCloud${C_RESET}"
    echo ""
}

draw_ui() {
    clear 2>/dev/null || true
    draw_top_bar
    local cols=$(tput cols 2>/dev/null || echo 80)
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '=%.0s' $(seq 1 $cols))"
    show_logo
    printf " ${C_WHITE}* ${C_BOLD}SYSTEM STATUS${C_RESET}\n"
    printf "   ${C_DIM}CPU:${C_RESET} ${C_CYAN}%s%%${C_RESET}  |  " "$(get_cpu_usage)"
    printf "${C_DIM}RAM:${C_RESET} ${C_CYAN}%s%%${C_RESET}  |  " "$(get_ram_usage)"
    printf "${C_DIM}Net:${C_RESET} %s\n\n" "$(get_network_status)"
    printf " ${C_CYAN}:: ${C_BOLD}DEPLOYMENT & SERVICES${C_RESET}\n"
    printf "  +-- ${C_WHITE}[${C_YELLOW}1${C_WHITE}]${C_RESET} %-20s  " "Panel"; printf "+-- ${C_WHITE}[${C_YELLOW}5${C_WHITE}]${C_RESET} %-20s\n" "System"
    printf "  +-- ${C_WHITE}[${C_YELLOW}2${C_WHITE}]${C_RESET} %-20s  " "Wings"; printf "+-- ${C_WHITE}[${C_YELLOW}6${C_WHITE}]${C_RESET} %-20s\n" "Container"
    printf "  +-- ${C_WHITE}[${C_YELLOW}3${C_WHITE}]${C_RESET} %-20s  " "Toolbox"; printf "+-- ${C_WHITE}[${C_YELLOW}7${C_WHITE}]${C_RESET} %-20s\n" "Backup"
    printf "  +-- ${C_WHITE}[${C_YELLOW}4${C_WHITE}]${C_RESET} %-20s  " "Theme"; printf "+-- ${C_WHITE}[${C_YELLOW}8${C_WHITE}]${C_RESET} %-20s\n" "About"
    echo ""
    printf " ${C_PURPLE}:: ${C_BOLD}MAINTENANCE & TOOLS${C_RESET}\n"
    printf "  +-- ${C_WHITE}[${C_YELLOW}9${C_WHITE}]${C_RESET} %-30s " "New Models"
    printf "${C_RED}[${C_BOLD}0${C_RESET}${C_RED}] SHUTDOWN${C_RESET}\n"
    printf "  +-- ${C_WHITE}[${C_YELLOW}10${C_WHITE}]${C_RESET} %-30s\n" "Help"
    echo ""
    printf "${C_BLUE}%s${C_RESET}\n" "$(printf '=%.0s' $(seq 1 $cols))"
}

menu_wings() { clear; printf "${C_CYAN}=== WINGS NODE MANAGER ===${C_RESET}\n\n"; warn "Not implemented yet."; pause; }
menu_toolbox() { clear; printf "${C_CYAN}=== TOOLBOX ===${C_RESET}\n\n1. System Check\n2. View Logs\n0. Back\n\n"; read -r -p "Select: " ch; case "$ch" in 1) system_check; pause;; 2) view_logs; pause;; esac; }
menu_system() { clear; printf "${C_CYAN}=== SYSTEM INFO ===${C_RESET}\n\nOS: %s\nUptime: %s\nMemory: %s\nDisk: %s\n" "$(uname -sr)" "$(uptime -p)" "$(free -h | awk '/Mem:/ {print $3 " / " $2}')" "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"; pause; }
menu_container() { clear; printf "${C_CYAN}=== CONTAINERS ===${C_RESET}\n\n"; if command_exists docker; then docker ps --format "table {{.Names}}\t{{.Status}}"; else warn "Docker not installed."; fi; pause; }
make_backup() {
    need_root || return 1
    valid_panel_dir || { err "Panel not found."; return 1; }
    install -d -m 0750 "$BACKUP_DIR"
    local archive="$BACKUP_DIR/panel-files-$(date +%Y%m%d-%H%M%S).tar.gz"
    warn "Backing up panel files only (not database)."
    tar -czf "$archive" -C "$(dirname "$PANEL_DIR")" "$(basename "$PANEL_DIR")" || return 1
    ok "Backup saved: $archive"
}
menu_backup() {
    clear
    printf "${C_CYAN}=== BACKUP MANAGER ===${C_RESET}\n\n"
    ls -lh "$BACKUP_DIR" 2>/dev/null || warn "No backups found."
    echo
    read -r -p "Create panel files backup? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then make_backup || err "Backup failed."; fi
    pause
}
menu_about() { clear; printf "${C_CYAN}=== ABOUT ===${C_RESET}\n\nExtension Hub %s\nAuthor: %s\nBlueprint: %s\n" "$APP_VERSION" "$AUTHOR" "$(detect_blueprint && echo "ONLINE" || echo "OFFLINE")"; pause; }
menu_new_models() { clear; printf "${C_CYAN}=== NEW MODELS ===${C_RESET}\n\nCustom space.\n\n"; pause; }
menu_help() { clear; printf "${C_CYAN}=== HELP ===${C_RESET}\n\n1. Panel\n2. Wings\n3. Toolbox\n4. Theme\n5. System\n6. Container\n7. Backup\n8. About\n9. New Models\n10. Help\n"; pause; }
system_check() { echo "=== SYSTEM CHECK ==="; printf 'Root: %s\nPanel: %s\nBlueprint: %s\nNode: %s\n' "$([[ $EUID -eq 0 ]] && echo YES || echo NO)" "$PANEL_DIR" "$(detect_blueprint && echo YES || echo NO)" "$(node --version 2>/dev/null || echo Missing)"; }
view_logs() { if [ -f "$LOG_FILE" ]; then tail -n 20 "$LOG_FILE"; else warn "No logs found."; fi; }

main_menu() {
    while true; do
        draw_ui
        read -r -p " -> Enter Option (0-10): " choice || exit 0
        case "$choice" in
            1) menu_panel ;;
            2) menu_wings ;;
            3) menu_toolbox ;;
            4) playtely_theme_menu ;;
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
