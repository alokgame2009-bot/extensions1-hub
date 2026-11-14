#!/usr/bin/env bash
# Extension Hub v3.1 - Fixed
set -Eeuo

APP_NAME="Extension Hub"
APP_VERSION="v3.1"
AUTHOR="Ziro"
LOG_FILE="/var/log/extension-hub.log"
TMP_DIR=""
BASE_URL="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main"
PANEL_DIR="/var/www/pterodactyl"
EXT_GITHUB_RAW="https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main/extensions"

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
detect_blueprint() { valid_panel_dir && [[ -f "$PANEL_DIR/blueprint.sh" && -f "$PANEL_DIR/.blueprintrc" ]]; }
blueprint_version() { [[ -f "$PANEL_DIR/blueprint.sh" ]] && grep -Eio '([0-9]+\.){1,3}[0-9]+' "$PANEL_DIR/blueprint.sh" | head -n1 || echo "Unknown"; }
panel_version() { valid_panel_dir && command_exists php && (cd "$PANEL_DIR" && php artisan --version 2>/dev/null | sed 's/^Laravel Framework //') || echo "Unknown"; }

# ==========================================
# AUTO FIX SAGATRASHBIN ISSUE
# ==========================================
fix_sagatrashbin() {
    if [[ ! -d "$PANEL_DIR" ]]; then return 0; fi
    info "Checking for broken extensions (sagatrashbin)..."
    
    find "$PANEL_DIR" -type d -iname "*sagatrashbin*" -exec rm -rf {} + 2>/dev/null || true
    find "$PANEL_DIR" -type f -iname "*sagatrashbin*" -delete 2>/dev/null || true
    grep -r "sagatrashbin" "$PANEL_DIR" --include="*.php" -l 2>/dev/null | xargs rm -f 2>/dev/null || true
    
    cd "$PANEL_DIR" || return 1
    composer dump-autoload --no-scripts -q 2>/dev/null || true
    
    for f in routes/api-client.php routes/api-application.php routes/web-client.php; do
        [[ -f "$f" ]] || { echo "<?php" > "$f"; chown www-data:www-data "$f"; chmod 644 "$f"; }
    done
    php artisan package:discover >/dev/null 2>&1 || true
    php artisan clear-compiled >/dev/null 2>&1 || true
    
    rm -rf "$PANEL_DIR/bootstrap/cache/"*.php 2>/dev/null || true
    rm -rf "$PANEL_DIR/storage/framework/cache/data/"* 2>/dev/null || true
    rm -rf "$PANEL_DIR/storage/framework/views/"* 2>/dev/null || true
    
    php artisan tinker --execute="
        try { DB::table('extensions')->where('name', 'sagatrashbin')->delete(); } catch(\Exception \$e) {}
        try { DB::table('blueprint_extensions')->where('name', 'sagatrashbin')->delete(); } catch(\Exception \$e) {}
    " 2>/dev/null || true
    
    ok "Auto-fix completed."
}

# ==========================================
# SYSTEM STATS FUNCTIONS
# ==========================================
get_cpu_usage() { local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'); printf "%.0f" "${cpu:-0}"; }
get_ram_usage() { free -m 2>/dev/null | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}' || echo "0"; }
get_network_status() { if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then printf "${C_GREEN}CONNECTED${C_RESET}"; else printf "${C_RED}DISCONNECTED${C_RESET}"; fi; }
get_uptime() { uptime -p 2>/dev/null | sed 's/up //; s/ weeks/ weeks,/; s/ days/ days,/' || echo "Unknown"; }
get_disk_usage() { df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "0%"; }
get_current_user() { echo "${USER:-root}"; }

# ==========================================
# REAL BLUEPRINT OPERATIONS
# ==========================================
install_blueprint() {
    need_root || return 1
    
    if detect_blueprint; then
        warn "Blueprint already installed. Reinstalling..."
        read -r -p "Reinstall? [y/N]: " answer
        [[ "$answer" =~ ^[Yy]$ ]] || return 0
    else
        echo; warn "This will install Blueprint Framework into: $PANEL_DIR"
        read -r -p "Continue? [y/N]: " answer
        [[ "$answer" =~ ^[Yy]$ ]] || return 0
    fi
    
    info "Fixing Node.js repository conflict..."
    rm -f /etc/apt/keyrings/nodesource.gpg /usr/share/keyrings/nodesource.gpg /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
    chmod 644 /etc/apt/keyrings/nodesource.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' > /etc/apt/sources.list.d/nodesource.list
    
    info "Step 1/5: Installing dependencies..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl git unzip wget zip
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
    if ! command -v yarn >/dev/null 2>&1; then npm install --global yarn >/dev/null 2>&1; fi
    ok "Dependencies installed."
    
    info "Step 2/5: Downloading Blueprint..."
    TMP_DIR="$(mktemp -d)"
    if ! curl -fL --retry 3 "https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip" -o "$TMP_DIR/release.zip"; then err "Download failed."; return 1; fi
    
    info "Step 3/5: Extracting files..."
    cd "$PANEL_DIR" || return 1
    cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
    unzip -o release.zip >/dev/null
    rm -f release.zip
    
    info "Step 4/5: Installing Yarn packages..."
    yarn install --silent >/dev/null 2>&1 || yarn install
    
    info "Step 5/5: Running setup..."
    chmod +x "$PANEL_DIR/blueprint.sh"
    cd "$PANEL_DIR" && bash ./blueprint.sh
    
    chown -R www-data:www-data "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    
    if [[ -f "$PANEL_DIR/app/BlueprintFramework/BlueprintServiceProvider.php" ]]; then
        if ! grep -q "BlueprintFramework" "$PANEL_DIR/config/app.php" 2>/dev/null; then
            sed -i "/App\\\\Providers\\\\AppServiceProvider::class,/a \        App\\\\BlueprintFramework\\\\BlueprintServiceProvider::class," "$PANEL_DIR/config/app.php" 2>/dev/null || true
        fi
    fi
    
    composer dump-autoload --no-scripts -q 2>/dev/null || true
    php artisan package:discover >/dev/null 2>&1 || true
    php artisan clear-compiled >/dev/null 2>&1 || true
    rm -rf "$PANEL_DIR/bootstrap/cache/"*.php 2>/dev/null || true
    
    fix_sagatrashbin
    
    if php artisan list 2>/dev/null | grep -q "blueprint:install"; then
        ok "Blueprint installed and registered successfully!"
    else
        err "Blueprint CLI still not registered."
    fi
}

update_blueprint() {
    need_root || return 1
    detect_blueprint || { err "Blueprint not installed."; return 1; }
    
    warn "This will update Blueprint to the latest version."
    read -r -p "Continue? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0
    
    info "Downloading latest Blueprint..."
    TMP_DIR="$(mktemp -d)"
    if ! curl -fL --retry 3 "https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip" -o "$TMP_DIR/release.zip"; then err "Download failed."; return 1; fi
    
    info "Extracting..."
    cd "$PANEL_DIR" || return 1
    cp -f "$TMP_DIR/release.zip" "$PANEL_DIR/release.zip"
    unzip -o release.zip >/dev/null
    rm -f release.zip
    
    info "Installing Yarn packages..."
    yarn install --silent >/dev/null 2>&1 || yarn install
    
    info "Running setup..."
    chmod +x "$PANEL_DIR/blueprint.sh"
    cd "$PANEL_DIR" && bash ./blueprint.sh
    
    chown -R www-data:www-data "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    composer dump-autoload --no-scripts -q 2>/dev/null || true
    php artisan package:discover >/dev/null 2>&1 || true
    php artisan clear-compiled >/dev/null 2>&1 || true
    
    ok "Blueprint updated successfully!"
    blueprint_version
}

uninstall_blueprint() {
    need_root || return 1
    detect_blueprint || { err "Blueprint not installed."; return 1; }
    
    warn "WARNING: This will remove Blueprint files from $PANEL_DIR"
    warn "Panel will remain intact but Blueprint will stop working."
    read -r -p "Type 'yes' to confirm uninstall: " answer
    [[ "$answer" == "yes" ]] || { info "Cancelled."; return 0; }
    
    info "Removing Blueprint files..."
    rm -f "$PANEL_DIR/blueprint.sh" "$PANEL_DIR/.blueprintrc" "$PANEL_DIR/release.zip"
    rm -rf "$PANEL_DIR/app/BlueprintFramework"
    rm -rf "$PANEL_DIR/.blueprint"
    
    if grep -q "BlueprintFramework" "$PANEL_DIR/config/app.php" 2>/dev/null; then
        sed -i '/BlueprintFramework/d' "$PANEL_DIR/config/app.php" 2>/dev/null || true
    fi
    
    composer dump-autoload --no-scripts -q 2>/dev/null || true
    php artisan package:discover >/dev/null 2>&1 || true
    php artisan clear-compiled >/dev/null 2>&1 || true
    rm -rf "$PANEL_DIR/bootstrap/cache/"*.php 2>/dev/null || true
    
    ok "Blueprint uninstalled successfully."
}

blueprint_info_menu() {
    clear
    printf "${C_CYAN}================================================${C_RESET}\n"
    printf "${C_CYAN}           BLUEPRINT INFO${C_RESET}\n"
    printf "${C_CYAN}================================================${C_RESET}\n\n"
    
    printf "Panel Directory : %s\n" "$PANEL_DIR"
    printf "Blueprint File  : %s\n" "$([[ -f "$PANEL_DIR/blueprint.sh" ]] && echo "EXISTS" || echo "MISSING")"
    printf "Config File     : %s\n" "$([[ -f "$PANEL_DIR/.blueprintrc" ]] && echo "EXISTS" || echo "MISSING")"
    printf "CLI Registered  : %s\n" "$(php artisan list 2>/dev/null | grep -q "blueprint:install" && echo "YES" || echo "NO")"
    printf "Blueprint Ver   : %s\n" "$(blueprint_version)"
    printf "Panel Ver       : %s\n" "$(panel_version)"
    printf "Node.js         : %s\n" "$(node --version 2>/dev/null || echo "Missing")"
    printf "Yarn            : %s\n" "$(yarn --version 2>/dev/null || echo "Missing")"
    printf "PHP             : %s\n" "$(php --version 2>/dev/null | head -n1 || echo "Missing")"
    printf "Composer        : %s\n" "$(composer --version 2>/dev/null || echo "Missing")"
    echo
    pause
}

# ==========================================
# REAL EXTENSION LOGIC
# ==========================================
install_ext() {
    local ext_id="$1" ext_name="$2"
    local file_name="${ext_name}.blueprint"
    local download_url="${EXT_GITHUB_RAW}/${file_name}"
    local tmp_file="/tmp/${file_name}"
    
    info "Installing Extension: $ext_name (ID: $ext_id)"
    
    if [[ ! -d "$PANEL_DIR" ]]; then 
        err "Panel directory not found."
        return 1
    fi
    
    if ! curl -fsSL --retry 3 "$download_url" -o "$tmp_file"; then 
        err "Failed to download $file_name from GitHub."
        return 1
    fi
    
    cd "$PANEL_DIR" || return 1
    
    fix_sagatrashbin
    
    if ! php artisan list 2>/dev/null | grep -q "blueprint:install"; then
        err "Blueprint CLI register nahi hai. Pehle [1] Blueprint -> Reinstall karein."
        return 1
    fi
    
    if php artisan blueprint:install "$tmp_file" > /tmp/install_ext.log 2>&1; then
        ok "Installed $ext_name successfully."
    else
        if grep -q "sagatrashbin" /tmp/install_ext.log; then
            warn "Detected sagatrashbin issue. Running Deep Fix..."
            fix_sagatrashbin
            if php artisan blueprint:install "$tmp_file" >> /tmp/install_ext.log 2>&1; then
                ok "Installed $ext_name successfully (after fix)."
            else
                err "Failed to install $ext_name even after fix."
            fi
        else
            err "Failed to install $ext_name."
            cat /tmp/install_ext.log | head -10
        fi
    fi
    
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
    
    rm -f "$tmp_file"
    rm -f /tmp/install_ext.log
}

remove_ext() {
    local ext_id="$1" ext_name="$2"
    info "Removing Extension: $ext_name (ID: $ext_id)"
    if [[ ! -d "$PANEL_DIR" ]]; then err "Panel directory not found."; return 1; fi
    cd "$PANEL_DIR" || return 1
    
    if ! php artisan list 2>/dev/null | grep -q "blueprint:remove"; then
        err "Blueprint CLI register nahi hai."
        return 1
    fi
    
    if php artisan blueprint:remove "$ext_name"; then 
        ok "Removed $ext_name successfully."
    else 
        err "Failed to remove $ext_name."
    fi
    
    php artisan view:clear >/dev/null 2>&1 || true
    php artisan config:clear >/dev/null 2>&1 || true
    php artisan cache:clear >/dev/null 2>&1 || true
}

# ==========================================
# EXTENSIONS GRID MENU
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
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET}                     ${C_PINK}Ziro.dev CONTROL HUB${C_RESET}                     ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}\n\n"

        local half=$(( (${#extensions[@]} + 1) / 2 ))
        for ((i=0; i<half; i++)); do
            IFS='|' read -r id1 name1 <<< "${extensions[$i]}"
            local right_index=$((i + half))
            
            local sel1="[-]"; local col1="${C_GRAY}"
            for s in "${selected_extensions[@]}"; do 
                if [[ "$s" == "$id1" ]]; then sel1="[+]"; col1="${C_GREEN}"; fi
            done
            
            local status1="○"; local status_col1="${C_RED}"
            if [[ -d "$PANEL_DIR/extensions/$name1" ]] || \
               [[ -f "$PANEL_DIR/extensions/$name1.blueprint" ]] || \
               [[ -d "$PANEL_DIR/app/Extensions/$name1" ]] || \
               [[ -f "$PANEL_DIR/app/Extensions/$name1.php" ]] || \
               [[ -d "$PANEL_DIR/.blueprint/extensions/$name1" ]]; then
                status1="●"; status_col1="${C_GREEN}"
            fi
            
            printf " ${col1}%s${C_RESET} ${C_CYAN}%-2s${C_RESET} ${C_WHITE}%-22s${C_RESET} ${status_col1}%s${C_RESET}" "$sel1" "$id1" "$name1" "$status1"
            
            if [ "$right_index" -lt "${#extensions[@]}" ]; then
                IFS='|' read -r id2 name2 <<< "${extensions[$right_index]}"
                local sel2="[-]"; local col2="${C_GRAY}"
                for s in "${selected_extensions[@]}"; do 
                    if [[ "$s" == "$id2" ]]; then sel2="[+]"; col2="${C_GREEN}"; fi
                done
                
                local status2="○"; local status_col2="${C_RED}"
                if [[ -d "$PANEL_DIR/extensions/$name2" ]] || \
                   [[ -f "$PANEL_DIR/extensions/$name2.blueprint" ]] || \
                   [[ -d "$PANEL_DIR/app/Extensions/$name2" ]] || \
                   [[ -f "$PANEL_DIR/app/Extensions/$name2.php" ]] || \
                   [[ -d "$PANEL_DIR/.blueprint/extensions/$name2" ]]; then
                    status2="●"; status_col2="${C_GREEN}"
                fi
                
                printf "   ${col2}%s${C_RESET} ${C_CYAN}%-2s${C_RESET} ${C_WHITE}%-22s${C_RESET} ${status_col2}%s${C_RESET}" "$sel2" "$id2" "$name2" "$status2"
            fi
            echo ""
        done
        echo ""

        printf " ${C_BLUE}%s${C_RESET}\n" "$(printf '─%.0s' $(seq 1 80))"
        printf " ${C_WHITE}SELECTED: ${C_YELLOW}%d${C_WHITE} items${C_RESET}\n" "${#selected_extensions[@]}"
        printf " ${C_GREEN}[i] Install  ${C_RED}[r] Remove  ${C_BLUE}[a] Select All  ${C_WHITE}[c] Clear  ${C_RED}[0] Exit${C_RESET}\n\n"
        read -r -p " 👉 ${C_GREEN}Select ID(s) or Action:${C_RESET} " input

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
                            if [ "$id" == "$sel" ]; then install_ext "$id" "$name" || true; fi
                        done
                    done
                    echo -e "\n${C_GREEN}✓ Process completed!${C_RESET}"; pause
                fi
                ;;
            "r"|"R")
                if [ ${#selected_extensions[@]} -eq 0 ]; then echo -e "\n${C_RED}Error: No extensions selected!${C_RESET}"; sleep 1
                else
                    for sel in "${selected_extensions[@]}"; do
                        for ext in "${extensions[@]}"; do
                            IFS='|' read -r id name <<< "$ext"
                            if [ "$id" == "$sel" ]; then remove_ext "$id" "$name" || true; fi
                        done
                    done
                    echo -e "\n${C_GREEN}✓ Process completed!${C_RESET}"; pause
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
# THEME MENU
# ==========================================
playtely_theme_menu() {
    while true; do
        clear 2>/dev/null || true
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET}                       ${C_PINK}CONTROL PANEL UI${C_RESET}                       ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
        
        if detect_blueprint; then printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_GREEN}● ONLINE${C_RESET}\n\n"
        else printf " ${C_CYAN}Blueprint Status :${C_RESET} ${C_RED}○ OFFLINE${C_RESET}\n\n"; fi
        
        printf "  ${C_GREEN}[1]${C_RESET} ${C_CYAN}Blueprint${C_RESET}\n"
        printf "  ${C_GREEN}[2]${C_RESET} ${C_CYAN}Theme${C_RESET}\n"
        printf "  ${C_GREEN}[3]${C_RESET} ${C_CYAN}Extensions${C_RESET}\n\n"
        printf "  ${C_RED}[0]${C_RESET} ${C_RED}Exit${C_RESET}\n\n"
        read -r -p " ${C_GREEN}▶ Select Option :${C_RESET} " t_choice || return
        
        case "$t_choice" in
            1) 
                while true; do
                    clear 2>/dev/null || true
                    printf "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}\n"
                    printf "${C_CYAN}║${C_RESET}                       ${C_PINK}CONTROL PANEL UI${C_RESET}                       ${C_CYAN}║${C_RESET}\n"
                    printf "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
                    printf " ${C_CYAN}BLUEPRINT PANEL${C_RESET}\n"
                    if detect_blueprint; then
                        printf " ${C_CYAN}Status :${C_RESET} ${C_GREEN}● ONLINE${C_RESET}\n\n"
                        printf " ${C_GREEN}[1]${C_RESET} ${C_CYAN}Reinstall${C_RESET}\n"
                        printf " ${C_GREEN}[2]${C_RESET} ${C_CYAN}Update${C_RESET}\n"
                        printf " ${C_GREEN}[3]${C_RESET} ${C_CYAN}Info${C_RESET}\n"
                        printf " ${C_GREEN}[4]${C_RESET} ${C_CYAN}Version${C_RESET}\n"
                        printf " ${C_RED}[5]${C_RESET} ${C_RED}Uninstall${C_RESET}\n"
                        printf " ${C_RED}[0]${C_RESET} ${C_RED}Back${C_RESET}\n\n"
                        read -r -p " ${C_GREEN}▶ Select :${C_RESET} " bp_choice || break
                        case "$bp_choice" in
                            1) install_blueprint; pause ;;
                            2) update_blueprint; pause ;;
                            3) blueprint_info_menu ;;
                            4) printf '\nBlueprint version: %s\nPanel version: %s\n' "$(blueprint_version)" "$(panel_version)"; pause ;;
                            5) uninstall_blueprint; pause ;;
                            0) break ;;
                            *) warn "Invalid option."; sleep 1 ;;
                        esac
                    else
                        printf " ${C_CYAN}Status :${C_RESET} ${C_RED}● OFFLINE${C_RESET}\n\n"
                        printf " ${C_GREEN}[1]${C_RESET} ${C_CYAN}Install${C_RESET}\n"
                        printf " ${C_RED}[0]${C_RESET} ${C_RED}Back${C_RESET}\n\n"
                        read -r -p " ${C_GREEN}▶ Select :${C_RESET} " bp_choice || break
                        case "$bp_choice" in
                            1) install_blueprint; pause ;;
                            0) break ;;
                            *) warn "Invalid option."; sleep 1 ;;
                        esac
                    fi
                done
                ;;
            2) clear; printf "  ${C_CYAN}--- Theme Management ---${C_RESET}\n\n"; warn "Theme manager coming soon."; pause ;;
            3) playtely_extensions_menu ;; 
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

menu_panel() { playtely_theme_menu; }

# ==========================================
# UI & DRAWING
# ==========================================
center_line() { local text="$1"; local cols=$(tput cols 2>/dev/null || echo 80); local clean_text=$(printf "%s" "$text" | sed 's/\x1b\[[0-9;]*m//g'); local len=${#clean_text}; local padding=$(( (cols - len) / 2 )); [[ "$padding" -lt 0 ]] && padding=0; printf "%${padding}s%s\n" "" "$text"; }

draw_top_bar() {
    local user=$(get_current_user); local up=$(get_uptime); local disk=$(get_disk_usage); local ram=$(get_ram_usage); local cpu=$(get_cpu_usage)
    local p1="${C_BG_BLUE}${C_WHITE} ${user} ${C_RESET}"; local p2="${C_BG_PURPLE}${C_WHITE} ${up} ${C_RESET}"; local p3="${C_BG_GREEN}${C_WHITE} ${disk} ${C_RESET}"; local p4="${C_BG_RED}${C_WHITE} RAM ${ram}% ${C_RESET}"; local p5="${C_BG_GREEN}${C_WHITE} CPU ${cpu}% ${C_RESET}"
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
    printf "  ├── ${C_WHITE}[${C_YELLOW}1${C_WHITE}]${C_RESET} %-20s  " "Panel"; printf "├── ${C_WHITE}[${C_YELLOW}5${C_WHITE}]${C_RESET} %-20s\n" "System"
    printf "  ├── ${C_WHITE}[${C_YELLOW}2${C_WHITE}]${C_RESET} %-20s  " "Wings"; printf "├── ${C_WHITE}[${C_YELLOW}6${C_WHITE}]${C_RESET} %-20s\n" "Container"
    printf "  ├── ${C_WHITE}[${C_YELLOW}3${C_WHITE}]${C_RESET} %-20s  " "Toolbox"; printf "├── ${C_WHITE}[${C_YELLOW}7${C_WHITE}]${C_RESET} %-20s\n" "Backup"
    printf "  └── ${C_WHITE}[${C_YELLOW}4${C_WHITE}]${C_RESET} %-20s  " "Theme"; printf "└── ${C_WHITE}[${C_YELLOW}8${C_WHITE}]${C_RESET} %-20s\n" "About"
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
menu_backup() { clear; printf "${C_CYAN}=== BACKUP MANAGER ===${C_RESET}\n\n"; mkdir -p /var/backups/extension-hub; ls -lh /var/backups/extension-hub; echo; read -r -p "Create panel backup? [y/N]: " ans; if [[ "$ans" =~ ^[Yy]$ ]]; then tar -czf "/var/backups/extension-hub/panel-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$(dirname "$PANEL_DIR")" "$(basename "$PANEL_DIR")" && ok "Backup created." || err "Backup failed."; fi; pause; }
menu_about() { clear; printf "${C_CYAN}=== ABOUT ===${C_RESET}\n\nExtension Hub %s\nAuthor: %s\nBlueprint: %s\n" "$APP_VERSION" "$AUTHOR" "$(detect_blueprint && echo "ONLINE" || echo "OFFLINE")"; pause; }
menu_new_models() { clear; printf "${C_CYAN}=== NEW MODELS (CUSTOM) ===${C_RESET}\n\nYahan aap apna custom code likh sakte hain.\n\n"; pause; }
menu_help() { clear; printf "${C_CYAN}=== HELP ===${C_RESET}\n\n1. Panel: Install/Manage Blueprint.\n2. Wings: Daemon nodes.\n3. Toolbox: System check.\n4. Theme: UI themes.\n5. System: Hardware info.\n6. Container: Docker.\n7. Backup: Backups.\n8. About: Info.\n9. New Models: Custom.\n10. Help.\n"; pause; }
system_check() { echo "=== SYSTEM CHECK ==="; printf 'Root: %s\nPanel: %s\nBlueprint: %s\nNode: %s\n' "$([[ $EUID -eq 0 ]] && echo YES || echo NO)" "$PANEL_DIR" "$(detect_blueprint && echo YES || echo NO)" "$(node --version 2>/dev/null || echo Missing)"; }
view_logs() { if [ -f "$LOG_FILE" ]; then tail -n 20 "$LOG_FILE"; else warn "No logs found."; fi; }

main_menu() {
    while true; do
        draw_ui
        read -r -p " ➔ Enter Option (0-10): " choice || exit 0
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
