#!/usr/bin/env bash
# panels-core.sh - Pterodactyl Panel Manager UI

C_PINK=$'\033[38;5;213m'
C_RESET="${C_RESET:-$'\033[0m'}"
C_BOLD="${C_BOLD:-$'\033[1m'}"
C_DIM="${C_DIM:-$'\033[2m'}"
C_CYAN="${C_CYAN:-$'\033[38;5;45m'}"
C_BLUE="${C_BLUE:-$'\033[38;5;39m'}"
C_GREEN="${C_GREEN:-$'\033[38;5;82m'}"
C_YELLOW="${C_YELLOW:-$'\033[38;5;220m'}"
C_RED="${C_RED:-$'\033[38;5;203m'}"
C_WHITE="${C_WHITE:-$'\033[97m'}"
C_GRAY="${C_GRAY:-$'\033[38;5;240m'}"

menu_panel() {
    while true; do
        clear 2>/dev/null || true
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET} ${C_WHITE}❖${C_RESET} ${C_BOLD}SERVER PANEL MANAGER${C_RESET} ${C_DIM}v15.0${C_RESET}                          $(date +%H:%M) ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
        
        local up=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Unknown")
        local load=$(cat /proc/loadavg | awk '{print $1}')
        printf " ${C_CYAN}SYSTEM STATUS${C_RESET}\n"
        printf "  ${C_GRAY}└─${C_RESET} ${C_DIM}Uptime${C_RESET} : ${C_WHITE}%s${C_RESET}\n" "$up"
        printf "  ${C_GRAY}└─${C_RESET} ${C_DIM}Load${C_RESET}   : ${C_WHITE}%s${C_RESET}\n\n" "$load"
        printf " ${C_BLUE}%s${C_RESET}\n\n" "$(printf '─%.0s' $(seq 1 60))"

        printf " ${C_YELLOW}▶${C_RESET} ${C_BOLD}${C_YELLOW}AVAILABLE DEPLOYMENTS${C_RESET}\n\n"

        printf "${C_GRAY}╭──────────────────────────────┬──────────────────────────────╮${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}1${C_WHITE}]${C_RESET} ${C_CYAN}Pterodactyl v1${C_RESET}       ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}7${C_WHITE}]${C_RESET} ${C_CYAN}Pterodactyl v2${C_RESET}       ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}2${C_WHITE}]${C_RESET} ${C_GRAY}NovaStudio (soon)${C_RESET}     ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}8${C_WHITE}]${C_RESET} ${C_CYAN}CtrlPanel${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}3${C_WHITE}]${C_RESET} ${C_GRAY}Ptro old (soon)${C_RESET}       ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}9${C_WHITE}]${C_RESET} ${C_CYAN}Heliactyl${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}4${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}10${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}5${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}11${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}6${C_WHITE}]${C_RESET} ${C_CYAN}Paymenter${C_RESET}            ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_RED}0${C_WHITE}]${C_RESET}  ${C_RED}Exit${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}╰──────────────────────────────┴──────────────────────────────╯${C_RESET}\n\n"

        read -r -p " λ Select Module [1-11]: " choice || return
        
        case "$choice" in
            1) playtely_panel_menu ;;
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

playtely_panel_menu() {
    while true; do
        clear 2>/dev/null || true
        
        printf "${C_PINK}"
        cat << 'EOF'
 _____  _                     _            _         _ 
|  __ \| |                   | |          | |       | |
| |__) | |_ ___ _ __ ___   __| | __ _  ___| |_ _   _| | 
|  ___/| __/ _ \ '__/ _ \ / _` |/ _` |/ __| __| | | | |
| |    | ||  __/ | | (_) | (_| | (_| | (__| |_| |_| | |
|_|     \__\___|_|  \___/ \__,_|\__,_|\___|\__|\__, |_|
                                                 __/ |  
                                                |___/   
EOF
        printf "${C_RESET}\n"

        if [[ -d "/var/www/pterodactyl" && -f "/var/www/pterodactyl/artisan" ]]; then
            printf "${C_CYAN}┌────────────────────────────────────────────────────────┐${C_RESET}\n"
            printf "${C_CYAN}│${C_RESET} ${C_BOLD}PANEL STATUS:${C_RESET} ${C_GREEN}INSTALLED${C_RESET} ${C_GREEN}✓${C_RESET}                           ${C_CYAN}│${C_RESET}\n"
            printf "${C_CYAN}└────────────────────────────────────────────────────────┘${C_RESET}\n\n"
        else
            printf "${C_CYAN}┌────────────────────────────────────────────────────────┐${C_RESET}\n"
            printf "${C_CYAN}│${C_RESET} ${C_BOLD}PANEL STATUS:${C_RESET} ${C_RED}NOT INSTALLED${C_RESET} ${C_RED}✗${C_RESET}                       ${C_CYAN}│${C_RESET}\n"
            printf "${C_CYAN}└────────────────────────────────────────────────────────┘${C_RESET}\n\n"
        fi

        printf "${C_CYAN}┌────────────────────────────────────────────────────────┐${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_GREEN}[1]${C_RESET} ${C_WHITE}Install${C_RESET}      ${C_DIM}:: (Fresh Install)${C_RESET}               ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_GREEN}[2]${C_RESET} ${C_WHITE}User${C_RESET}         ${C_DIM}:: (Add Admin/User)${C_RESET}              ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_GREEN}[3]${C_RESET} ${C_WHITE}Update${C_RESET}       ${C_DIM}:: (Latest Release)${C_RESET}              ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_RED}[4]${C_RESET} ${C_WHITE}Domin${C_RESET}        ${C_DIM}:: (Chang/domin/ssl)${C_RESET}            ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_RED}[5]${C_RESET} ${C_WHITE}Uninstall${C_RESET}    ${C_DIM}:: (Remove Data)${C_RESET}                 ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_GREEN}[6]${C_RESET} ${C_WHITE}phpmyadmin${C_RESET}   ${C_DIM}:: (phpmyadmin Data)${C_RESET}             ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}├────────────────────────────────────────────────────────┤${C_RESET}\n"
        printf "${C_CYAN}│${C_RESET}  ${C_RED}[0]${C_RESET} ${C_WHITE}Exit System${C_RESET}                                     ${C_CYAN}│${C_RESET}\n"
        printf "${C_CYAN}└────────────────────────────────────────────────────────┘${C_RESET}\n\n"

        read -r -p " λ Select Option: " p_choice || return
        
        local INSTALLER_SCRIPT="/opt/extension-hub/nexyoncloud-installer.sh"
        
        if [[ ! -f "$INSTALLER_SCRIPT" ]]; then
            INSTALLER_SCRIPT="/tmp/nexyoncloud-installer.sh"
            if [[ ! -f "$INSTALLER_SCRIPT" ]]; then
                curl -fsSL "https://raw.githubusercontent.com/alokgame2009-bot/extension-hub/main/nexyoncloud-installer.sh" -o "$INSTALLER_SCRIPT" 2>/dev/null || true
            fi
        fi

        if [[ -f "$INSTALLER_SCRIPT" ]]; then
            source "$INSTALLER_SCRIPT"
        else
            warn "NexyonCloud Installer script not found!"
            pause
            continue
        fi

        case "$p_choice" in
            1) 
                if input_config; then
                    install_deps; database; panel; nginx_config; services; save
                    echo "╔══════════════════════════════════════════════╗"
                    echo "║          INSTALLATION COMPLETE               ║"
                    echo "╚══════════════════════════════════════════════╝"
                    echo "Panel: https://$DOMAIN"
                fi
                pause 
                ;;
            2) 
                # USER MANAGEMENT SCREEN
                while true; do
                    clear
                    echo
                    echo "════════════════════════════════════════════════════════════"
                    echo "              PTERODACTYL SERVER MANAGEMENT SYSTEM"
                    echo "════════════════════════════════════════════════════════════"
                    echo
                    echo "  Current Module: USER MANAGEMENT"
                    echo
                    echo "────────────────────────────────────────────────────────────"
                    echo
                    echo "1) Custom User Create"
                    echo "2) Auto Create Admin User"
                    echo
                    read -r -p "Choose option: " u_choice
                    
                    case "$u_choice" in
                        1) create_user_manual; break ;;
                        2) create_user_auto; break ;;
                        *) echo "Invalid option."; sleep 1 ;;
                    esac
                done
                ;;
            3) update_panel; pause ;;
            4) clear; warn "Domain/SSL management coming soon."; pause ;;
            5) uninstall_panel; pause ;;
            6) clear; warn "phpmyadmin setup coming soon."; pause ;;
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}
