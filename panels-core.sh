#!/usr/bin/env bash
# panels-core.sh - Server Panel Manager UI

menu_panel() {
    while true; do
        clear 2>/dev/null || true
        
        # Top Header Bar
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET} ${C_WHITE}❖${C_RESET} ${C_BOLD}SERVER PANEL MANAGER${C_RESET} ${C_DIM}v15.0${C_RESET}                          $(date +%H:%M) ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
        
        # System Status
        local up=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Unknown")
        local load=$(cat /proc/loadavg | awk '{print $1}')
        printf " ${C_CYAN}SYSTEM STATUS${C_RESET}\n"
        printf "  ${C_GRAY}└─${C_RESET} ${C_DIM}Uptime${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "$up"
        printf "  ${C_GRAY}└─${C_RESET} ${C_DIM}Load${C_RESET}   : ${C_WHITE}%s${C_RESET}\n\n" "$load"
        
        printf " ${C_BLUE}%s${C_RESET}\n\n" "$(printf '─%.0s' $(seq 1 60))"

        # Available Deployments Header
        printf " ${C_YELLOW}▶${C_RESET} ${C_BOLD}${C_YELLOW}AVAILABLE DEPLOYMENTS${C_RESET}\n\n"

        # Menu Box
        printf "${C_GRAY}╭──────────────────────────────┬──────────────────────────────╮${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}1${C_WHITE}]${C_RESET} ${C_CYAN}Pterodactyl v1${C_RESET}       ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}7${C_WHITE}]${C_RESET} ${C_CYAN}Pterodactyl v2${C_RESET}       ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}2${C_WHITE}]${C_RESET} ${C_GRAY}NovaStudio (soon)${C_RESET}     ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}8${C_WHITE}]${C_RESET} ${C_CYAN}CtrlPanel${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}3${C_WHITE}]${C_RESET} ${C_GRAY}Ptro old (soon)${C_RESET}       ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}9${C_WHITE}]${C_RESET} ${C_CYAN}Heliactyl${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}4${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}10${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}5${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}11${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}6${C_WHITE}]${C_RESET} ${C_CYAN}Paymenter${C_RESET}            ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_RED}0${C_WHITE}]${C_RESET}  ${C_RED}Exit${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}╰──────────────────────────────┴──────────────────────────────╯${C_RESET}\n\n"

        # User Input
        read -r -p " λ Select Module [1-11]: " choice || return
        
        case "$choice" in
            1) blueprint_submenu ;;
            2|3|4|5) clear; printf "${C_YELLOW}--- Coming Soon ---${C_RESET}\n\n"; warn "Not implemented."; pause ;;
            6) clear; printf "${C_PURPLE}--- Paymenter ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            7) clear; printf "${C_CYAN}--- Pterodactyl v2 ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            8) clear; printf "${C_CYAN}--- CtrlPanel ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            9) clear; printf "${C_CYAN}--- Heliactyl ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            10|11) clear; printf "${C_YELLOW}--- Coming Soon ---${C_RESET}\n\n"; warn "Not implemented."; pause ;;
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

blueprint_submenu() {
    clear
    printf "${C_CYAN}--- Pterodactyl v1 (Blueprint Manager) ---${C_RESET}\n\n"
    if detect_blueprint; then
        printf " ${C_GREEN}● Status: ONLINE${C_RESET} (v%s)\n\n" "$(blueprint_version)"
        printf "1. Reinstall Blueprint\n2. Update Blueprint\n3. Panel Info\n4. Uninstall Blueprint\n0. Back\n\n"
        read -r -p "Select: " sub_ch
        case "$sub_ch" in
            1) reinstall_blueprint; pause ;;
            2) update_blueprint; pause ;;
            3) blueprint_info; pause ;;
            4) uninstall_blueprint; pause ;;
        esac
    else
        printf " ${C_RED}● Status: OFFLINE${C_RESET}\n\n"
        printf "1. Install Pterodactyl v1 (Blueprint)\n0. Back\n\n"
        read -r -p "Select: " sub_ch
        case "$sub_ch" in
            1) install_blueprint; pause ;;
        esac
    fi
}
