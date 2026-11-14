#!/usr/bin/env bash
# Extension Hub v1.1 - Ziro Edition / NexyonCloud
# Safe printf usage: all variable content is printed as data, never as a format string.
set -Eeuo pipefail
IFS=$'\n\t'

APP_NAME="Extension Hub"
APP_VERSION="v1.1"
AUTHOR="Ziro"
PANEL_DIR="${PTERODACTYL_DIRECTORY:-/var/www/pterodactyl}"
EXT_GITHUB_RAW="${EXT_GITHUB_RAW:-https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main/extensions}"
LOG_FILE="${EXTENSION_HUB_LOG:-/var/log/extension-hub.log}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/extension-hub}"
TMP_DIR=""

# ---------- terminal colors ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[38;5;45m'
    C_BLUE=$'\033[38;5;39m'
    C_GREEN=$'\033[38;5;82m'
    C_YELLOW=$'\033[38;5;220m'
    C_RED=$'\033[38;5;203m'
    C_WHITE=$'\033[97m'
    C_PURPLE=$'\033[38;5;135m'
    C_GRAY=$'\033[38;5;240m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_CYAN=""; C_BLUE=""
    C_GREEN=""; C_YELLOW=""; C_RED=""; C_WHITE=""; C_PURPLE=""; C_GRAY=""
fi

# ---------- output / logging ----------
log_message() {
    local level="$1"
    shift
    {
        printf '[%s] [%s] ' "$(date '+%F %T')" "$level"
        printf '%s\n' "$*"
    } >> "$LOG_FILE" 2>/dev/null || true
}

info() { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; log_message INFO "$*"; }
success() { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log_message OK "$*"; }
warning() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log_message WARN "$*"; }
error() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log_message ERROR "$*"; }
pause_screen() { printf '\n'; read -r -p "Press Enter to continue..." _ || true; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
need_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Run this tool as root: sudo bash extension-hub.sh"
        return 1
    fi
}
valid_panel_dir() {
    [[ -d "$PANEL_DIR" && -f "$PANEL_DIR/artisan" && -f "$PANEL_DIR/composer.json" ]]
}
cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}
trap cleanup EXIT

# ---------- Pterodactyl / Blueprint detection ----------
panel_version() {
    if valid_panel_dir && command_exists php; then
        (cd "$PANEL_DIR" && php artisan --version 2>/dev/null) || printf '%s' "Unknown"
    else
        printf '%s' "Unknown"
    fi
}

blueprint_installed() {
    valid_panel_dir &&
    [[ -f "$PANEL_DIR/blueprint.sh" ]] &&
    [[ -f "$PANEL_DIR/.blueprintrc" ]] &&
    { [[ -x /usr/local/bin/blueprint ]] || command_exists blueprint; }
}

blueprint_version() {
    if blueprint_installed; then
        (cd "$PANEL_DIR" && blueprint -version 2>&1) || true
    else
        printf '%s' "Not installed"
    fi
}

# Run a real Laravel bootstrap check before modifying the panel. This catches
# provider/container errors such as a missing TrashBinRepository class.
panel_laravel_check() {
    valid_panel_dir || { error "Pterodactyl panel not found: $PANEL_DIR"; return 1; }
    command_exists php || { error "PHP CLI is missing."; return 1; }

    local check_log status
    check_log="$(mktemp /tmp/extension-hub-artisan.XXXXXX.log)"
    if (cd "$PANEL_DIR" && php artisan list --no-ansi) >"$check_log" 2>&1; then
        status=0
    else
        status=$?
    fi

    if [[ "$status" -ne 0 ]] ||
       grep -Eqi 'Target class .* does not exist|Class .* does not exist|ReflectionException|BindingResolutionException' "$check_log"; then
        error "Laravel bootstrap check failed. Hub will not claim a successful install."
        if grep -Eqi 'TrashBinRepository|sagatrashbin' "$check_log"; then
            warning "Detected the sagatrashbin / TrashBinRepository missing-class error."
        fi
        sed -n '1,35p' "$check_log"
        warning "Full diagnostic log: $check_log"
        return 1
    fi

    rm -f "$check_log"
    return 0
}

# ---------- Blueprint installation ----------
install_blueprint() {
    need_root || return 1
    valid_panel_dir || { error "Panel directory is invalid: $PANEL_DIR"; return 1; }
    panel_laravel_check || return 1

    if blueprint_installed; then
        warning "Blueprint is already installed."
        read -r -p "Run the official Blueprint repair command now? [y/N]: " answer || return 0
        [[ "$answer" =~ ^[Yy]$ ]] || return 0
        (cd "$PANEL_DIR" && blueprint -rerun-install) || {
            error "Blueprint repair command failed."
            return 1
        }
        panel_laravel_check || return 1
        success "Blueprint repair completed."
        return 0
    fi

    command_exists apt-get || { error "This installer supports Debian/Ubuntu (apt-get)."; return 1; }
    warning "Blueprint will modify files inside: $PANEL_DIR"
    warning "Take a full panel + database backup before continuing."
    read -r -p "Continue with Blueprint installation? [y/N]: " answer || return 0
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    TMP_DIR="$(mktemp -d)"
    info "Installing system prerequisites..."
    apt-get update || { error "apt-get update failed."; return 1; }
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git gnupg unzip wget zip ||
        { error "Could not install Blueprint prerequisites."; return 1; }

    info "Configuring Node.js 22 repository..."
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key |
        gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg ||
        { error "Could not configure the NodeSource signing key."; return 1; }
    chmod 0644 /etc/apt/keyrings/nodesource.gpg
    printf '%s\n' \
        'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main' \
        > /etc/apt/sources.list.d/nodesource.list
    apt-get update || { error "apt-get update failed after adding NodeSource."; return 1; }
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs ||
        { error "Node.js installation failed."; return 1; }
    command_exists node && command_exists npm || { error "Node.js/npm installation failed."; return 1; }

    info "Installing Yarn..."
    npm install --global yarn || { error "Yarn installation failed."; return 1; }
    command_exists yarn || { error "Yarn installation failed."; return 1; }

    info "Downloading official Blueprint release..."
    curl -fL --retry 3 --retry-delay 2 \
        "https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip" \
        -o "$TMP_DIR/release.zip"
    unzip -tq "$TMP_DIR/release.zip" >/dev/null ||
        { error "The downloaded Blueprint release is not a valid ZIP."; return 1; }

    info "Extracting Blueprint into the panel..."
    unzip -o "$TMP_DIR/release.zip" -d "$PANEL_DIR" ||
        { error "Could not extract the Blueprint release into the panel."; return 1; }
    [[ -f "$PANEL_DIR/blueprint.sh" ]] ||
        { error "Official release did not contain blueprint.sh."; return 1; }

    info "Installing panel Yarn dependencies (may take several minutes)..."
    (cd "$PANEL_DIR" && yarn install) ||
        { error "yarn install failed; Blueprint setup was not started."; return 1; }

    if [[ ! -f "$PANEL_DIR/.blueprintrc" ]]; then
        cat > "$PANEL_DIR/.blueprintrc" <<'BLUEPRINT_RC'
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
BLUEPRINT_RC
    else
        info "Existing .blueprintrc preserved."
    fi

    chmod +x "$PANEL_DIR/blueprint.sh" ||
        { error "Could not make blueprint.sh executable."; return 1; }
    info "Running official Blueprint setup script..."
    local setup_log setup_status
    setup_log="$(mktemp /tmp/extension-hub-blueprint.XXXXXX.log)"
    if (cd "$PANEL_DIR" && bash ./blueprint.sh) >"$setup_log" 2>&1; then
        setup_status=0
    else
        setup_status=$?
    fi
    cat "$setup_log"

    if [[ "$setup_status" -ne 0 ]] ||
       grep -Eqi 'Target class .* does not exist|Class .* does not exist|ReflectionException|BindingResolutionException' "$setup_log"; then
        error "Blueprint setup did not complete cleanly. See: $setup_log"
        return 1
    fi

    if ! blueprint_installed; then
        error "Setup returned, but Blueprint CLI/files could not be verified."
        warning "Setup log: $setup_log"
        return 1
    fi

    panel_laravel_check || { warning "Setup log: $setup_log"; return 1; }
    rm -f "$setup_log"
    success "Blueprint installed and verified."
}

blueprint_menu() {
    while true; do
        clear 2>/dev/null || true
        printf '%s\n' "${C_CYAN}╔══════════════════════════════════════════════╗${C_RESET}"
        printf '%s\n' "${C_CYAN}║              BLUEPRINT MANAGER              ║${C_RESET}"
        printf '%s\n' "${C_CYAN}╚══════════════════════════════════════════════╝${C_RESET}"
        if blueprint_installed; then
            printf '%s\n\n' "Status: ${C_GREEN}● INSTALLED${C_RESET}"
            printf '%s\n' " [1] Repair / Re-run setup"
            printf '%s\n' " [2] Update Blueprint"
            printf '%s\n' " [3] Blueprint information"
            printf '%s\n' " [4] Blueprint version"
        else
            printf '%s\n\n' "Status: ${C_RED}○ NOT INSTALLED${C_RESET}"
            printf '%s\n' " [1] Install Blueprint"
        fi
        printf '%s\n\n' " [0] Back"
        read -r -p "Select: " choice || return 0
        case "$choice" in
            1) install_blueprint || warning "Blueprint operation failed."; pause_screen ;;
            2)
                if blueprint_installed; then
                    need_root && panel_laravel_check &&
                        (cd "$PANEL_DIR" && blueprint -upgrade) &&
                        success "Blueprint upgrade command completed." ||
                        error "Blueprint update failed."
                else
                    error "Blueprint is not installed."
                fi
                pause_screen
                ;;
            3)
                if blueprint_installed; then (cd "$PANEL_DIR" && blueprint -info) || true
                else error "Blueprint is not installed."; fi
                pause_screen
                ;;
            4) printf '\n%s\n' "$(blueprint_version)"; pause_screen ;;
            0) return 0 ;;
            *) warning "Invalid option."; sleep 1 ;;
        esac
    done
}

# ---------- Extension catalogue ----------
EXTENSIONS=(
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

# Query Blueprint for installed metadata. Fallback checks cover common filesystem
# layouts; a missing package archive alone is NOT treated as installed.
extension_is_installed() {
    local name="$1" query_output=""
    if command_exists blueprint && valid_panel_dir; then
        query_output="$(cd "$PANEL_DIR" && blueprint -query "$name" 2>&1)" || query_output=""
        if [[ -n "$query_output" ]] &&
           ! grep -Eqi 'not installed|not found|does not exist|unknown extension|no extension' <<< "$query_output" &&
           grep -Fqi "$name" <<< "$query_output"; then
            return 0
        fi
    fi

    [[ -d "$PANEL_DIR/.blueprint/extensions/$name" ]] && return 0
    [[ -d "$PANEL_DIR/app/Extensions/$name" ]] && return 0
    [[ -f "$PANEL_DIR/app/Extensions/$name.php" ]] && return 0
    [[ -d "$PANEL_DIR/extensions/$name" ]] && return 0
    return 1
}

install_extension() {
    local name="$1" package="$PANEL_DIR/${1}.blueprint" temp_package install_log status
    need_root || return 1
    valid_panel_dir || { error "Panel directory not found: $PANEL_DIR"; return 1; }
    blueprint_installed || { error "Install Blueprint first."; return 1; }
    panel_laravel_check || return 1

    TMP_DIR="$(mktemp -d)"
    temp_package="$TMP_DIR/${name}.blueprint"
    install_log="$TMP_DIR/${name}-install.log"

    info "Downloading ${name}.blueprint from Extension Hub GitHub repository..."
    if ! curl -fL --retry 3 --retry-delay 2 "${EXT_GITHUB_RAW}/${name}.blueprint" -o "$temp_package"; then
        error "Download failed: ${EXT_GITHUB_RAW}/${name}.blueprint"
        return 1
    fi
    [[ -s "$temp_package" ]] && unzip -tq "$temp_package" >/dev/null 2>&1 ||
        { error "Downloaded file is empty or is not a valid Blueprint package."; return 1; }

    if [[ -e "$package" ]]; then
        warning "Removing stale package file: $package"
        rm -f -- "$package"
    fi
    install -m 0644 "$temp_package" "$package"

    info "Running official Blueprint install command for ${name}..."
    if (cd "$PANEL_DIR" && blueprint -install "$name") >"$install_log" 2>&1; then
        status=0
    else
        status=$?
    fi
    cat "$install_log"
    rm -f -- "$package"

    if [[ "$status" -ne 0 ]] ||
       grep -Eqi 'Target class .* does not exist|Class .* does not exist|ReflectionException|BindingResolutionException' "$install_log"; then
        error "Blueprint did not install ${name} cleanly. Log: $install_log"
        return 1
    fi

    panel_laravel_check || { error "Post-install Laravel check failed. Log: $install_log"; return 1; }
    success "Blueprint command completed for ${name}."
    return 0
}

remove_extension() {
    local name="$1"
    need_root || return 1
    valid_panel_dir || { error "Panel directory not found: $PANEL_DIR"; return 1; }
    blueprint_installed || { error "Blueprint is not installed."; return 1; }
    panel_laravel_check || return 1
    warning "This will remove extension: $name"
    read -r -p "Confirm removal? [y/N]: " answer || return 0
    [[ "$answer" =~ ^[Yy]$ ]] || return 0
    (cd "$PANEL_DIR" && blueprint -remove "$name") || {
        error "Blueprint could not remove ${name}."
        return 1
    }
    panel_laravel_check || return 1
    success "Removed ${name}."
}

extension_menu() {
    local choice name id item
    while true; do
        clear 2>/dev/null || true
        printf '%s\n' "${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
        printf '%s\n' "${C_CYAN}║                    BLUEPRINT EXTENSIONS                         ║${C_RESET}"
        printf '%s\n\n' "${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"

        for item in "${EXTENSIONS[@]}"; do
            IFS='|' read -r id name <<< "$item"
            if extension_is_installed "$name"; then
                printf '%s\n' " ${C_GREEN}●${C_RESET} $(printf '%-2s' "$id")  $name"
            else
                printf '%s\n' " ${C_RED}○${C_RESET} $(printf '%-2s' "$id")  $name"
            fi
        done

        printf '\n%s\n' " [I] Install by ID/name"
        printf '%s\n' " [R] Remove by ID/name"
        printf '%s\n' " [0] Back"
        read -r -p "Select: " choice || return 0
        case "$choice" in
            0) return 0 ;;
            [Ii])
                read -r -p "Enter extension ID or exact name: " choice || continue
                name=""
                for item in "${EXTENSIONS[@]}"; do
                    IFS='|' read -r id item_name <<< "$item"
                    if [[ "$choice" == "$id" || "$choice" == "$item_name" ]]; then
                        name="$item_name"
                        break
                    fi
                done
                if [[ -z "$name" ]]; then error "Unknown extension ID/name."
                else install_extension "$name" || warning "Install failed for $name."; fi
                pause_screen
                ;;
            [Rr])
                read -r -p "Enter extension ID or exact name: " choice || continue
                name=""
                for item in "${EXTENSIONS[@]}"; do
                    IFS='|' read -r id item_name <<< "$item"
                    if [[ "$choice" == "$id" || "$choice" == "$item_name" ]]; then
                        name="$item_name"
                        break
                    fi
                done
                if [[ -z "$name" ]]; then error "Unknown extension ID/name."
                else remove_extension "$name" || warning "Remove failed for $name."; fi
                pause_screen
                ;;
            *) warning "Choose I, R, or 0."; sleep 1 ;;
        esac
    done
}

# ---------- system tools ----------
system_info() {
    clear 2>/dev/null || true
    printf '%s\n\n' "${C_CYAN}SYSTEM INFORMATION${C_RESET}"
    printf 'Hostname : %s\n' "$(hostname 2>/dev/null || echo unknown)"
    printf 'OS       : %s\n' "$( . /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}" )"
    printf 'Kernel   : %s\n' "$(uname -r)"
    printf 'Uptime   : %s\n' "$(uptime -p 2>/dev/null || echo unknown)"
    printf 'CPU      : %s%%\n' "$(top -bn1 2>/dev/null | awk -F'[, ]+' '/Cpu\\(s\\)/ {for(i=1;i<=NF;i++) if($i=="id") {print 100-$(i-1); exit}}' | cut -d. -f1)"
    printf 'Memory   : %s\n' "$(free -h 2>/dev/null | awk '/Mem:/ {print $3 " used / " $2}')"
    printf 'Disk /   : %s\n' "$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 ")"}')"
    printf 'Panel    : %s\n' "$PANEL_DIR"
    printf 'Panel ver: %s\n' "$(panel_version)"
    printf 'Blueprint: %s\n' "$(blueprint_installed && echo Installed || echo Not-installed)"
    pause_screen
}

view_logs() {
    clear 2>/dev/null || true
    if [[ -f "$LOG_FILE" ]]; then tail -n 60 "$LOG_FILE"; else warning "No Extension Hub log exists yet."; fi
    pause_screen
}

create_panel_backup() {
    need_root || return 1
    valid_panel_dir || { error "Panel directory not found: $PANEL_DIR"; return 1; }
    install -d -m 0750 "$BACKUP_DIR"
    local archive="$BACKUP_DIR/panel-files-$(date +%Y%m%d-%H%M%S).tar.gz"
    warning "This archives panel files only; it does NOT back up the database."
    read -r -p "Create panel-files archive? [y/N]: " answer || return 0
    [[ "$answer" =~ ^[Yy]$ ]] || return 0
    tar -czf "$archive" -C "$(dirname "$PANEL_DIR")" "$(basename "$PANEL_DIR")" ||
        { error "Panel files backup failed."; return 1; }
    success "Panel files backup saved: $archive"
}

backup_menu() {
    clear 2>/dev/null || true
    printf '%s\n\n' "${C_CYAN}BACKUP MANAGER${C_RESET}"
    if [[ -d "$BACKUP_DIR" ]]; then ls -lh "$BACKUP_DIR"; else warning "No backup directory yet."; fi
    create_panel_backup || warning "Backup operation failed."
    pause_screen
}

main_menu() {
    local choice
    while true; do
        clear 2>/dev/null || true
        printf '%s\n' "${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
        printf '%s\n' "${C_CYAN}║                    E X T E N S I O N   H U B                     ║${C_RESET}"
        printf '%s\n' "${C_CYAN}║                   Z I R O   E D I T I O N                         ║${C_RESET}"
        printf '%s\n\n' "${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
        printf '%s\n' " ${C_GREEN}1.${C_RESET} Panel / Blueprint Manager"
        printf '%s\n' " ${C_GREEN}2.${C_RESET} Blueprint Extensions"
        printf '%s\n' " ${C_GREEN}3.${C_RESET} System Information"
        printf '%s\n' " ${C_GREEN}4.${C_RESET} Panel Files Backup"
        printf '%s\n' " ${C_GREEN}5.${C_RESET} View Extension Hub Logs"
        printf '%s\n' " ${C_RED}0.${C_RESET} Exit"
        printf '\n%s\n' "Panel path: $PANEL_DIR"
        if blueprint_installed; then
            printf '%s\n\n' "Blueprint: ${C_GREEN}INSTALLED${C_RESET}"
        else
            printf '%s\n\n' "Blueprint: ${C_YELLOW}NOT DETECTED${C_RESET}"
        fi
        read -r -p "Select an option: " choice || return 0
        case "$choice" in
            1) blueprint_menu ;;
            2) extension_menu ;;
            3) system_info ;;
            4) backup_menu ;;
            5) view_logs ;;
            0) printf '%s\n' "Goodbye."; return 0 ;;
            *) warning "Invalid option."; sleep 1 ;;
        esac
    done
}

case "${1:-}" in
    --help|-h|help)
        printf '%s\n' "Usage: sudo bash extension-hub.sh"
        printf '%s\n' "Optional: PTERODACTYL_DIRECTORY=/path/to/panel"
        ;;
    *)
        main_menu
        ;;
esac
