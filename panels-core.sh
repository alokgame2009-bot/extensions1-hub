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

        # Colorful Menu Box
        printf "${C_GRAY}╭──────────────────────────────┬──────────────────────────────╮${C_RESET}\n"
        
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}1${C_WHITE}]${C_RESET} ${C_CYAN}Pterodactyl v1${C_RESET}       ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}7${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}2${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}8${C_WHITE}]${C_RESET} ${C_CYAN}CtrlPanel${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}3${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}9${C_WHITE}]${C_RESET} ${C_CYAN}Heliactyl${C_RESET}            ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}4${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}10${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}5${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                  ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}11${C_WHITE}]${C_RESET} ${C_GRAY}soon${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        printf "${C_GRAY}│${C_RESET} ${C_WHITE}[${C_GREEN}6${C_WHITE}]${C_RESET} ${C_CYAN}Paymenter${C_RESET}            ${C_GRAY}│${C_RESET} ${C_WHITE}[${C_RED}0${C_WHITE}]${C_RESET}  ${C_RED}Exit${C_RESET}                 ${C_GRAY}│${C_RESET}\n"
        
        printf "${C_GRAY}╰──────────────────────────────┴──────────────────────────────╯${C_RESET}\n\n"

        read -r -p " ${C_GREEN}λ${C_RESET} Select Module [1-11]: " choice || return
        
        case "$choice" in
            1) playtely_panel_menu ;;
            2|3|5|7|10|11) 
                clear
                printf "\n ${C_GRAY}:: Coming Soon${C_RESET}\n\n"
                warn "This module is not implemented yet."
                pause 
                ;;
            4) playtely_theme_menu ;;
            6) clear; printf "${C_PURPLE}--- Paymenter ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            8) clear; printf "${C_CYAN}--- CtrlPanel ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            9) clear; printf "${C_CYAN}--- Heliactyl ---${C_RESET}\n\n"; warn "Coming soon."; pause ;;
            0) return ;;
            *) warn "Invalid option."; sleep 1 ;;
        esac
    done
}

# ==========================================
# THEME MENU (Screenshot Style without Hyper V1)
# ==========================================
playtely_theme_menu() {
    while true; do
        clear 2>/dev/null || true
        
        # Top Box (Cyan Border, Pink Text, Centered)
        printf "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
        printf "${C_CYAN}║${C_RESET}                         ${C_PINK}CONTROL PANEL UI${C_RESET}                          ${C_CYAN}║${C_RESET}\n"
        printf "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
        
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
                    printf "\n${C_GREEN}╔══════════════════════════════════════════════╗${C_RESET}\n"
                    printf "${C_GREEN}║          INSTALLATION COMPLETE               ║${C_RESET}\n"
                    printf "${C_GREEN}╚══════════════════════════════════════════════╝${C_RESET}\n"
                    printf "${C_WHITE}Panel: ${C_CYAN}https://$DOMAIN${C_RESET}\n"
                fi
                pause 
                ;;
            2) 
                while true; do
                    clear
                    printf "${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
                    printf "${C_CYAN}║${C_RESET} ${C_WHITE}❖${C_RESET} ${C_BOLD}PTERODACTYL SERVER MANAGEMENT SYSTEM${C_RESET}                     ${C_CYAN}║${C_RESET}\n"
                    printf "${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}\n\n"
                    
                    printf " ${C_YELLOW}▶${C_RESET} ${C_BOLD}Current Module:${C_RESET} ${C_YELLOW}USER MANAGEMENT${C_RESET}\n"
                    printf " ${C_BLUE}%s${C_RESET}\n\n" "$(printf '─%.0s' $(seq 1 60))"
                    
                    printf "${C_CYAN}::${C_RESET} ${C_BOLD}AVAILABLE ACTIONS${C_RESET}\n\n"
                    printf "  ${C_GREEN}[1]${C_RESET} ${C_WHITE}Custom User Create${C_RESET}\n"
                    printf "  ${C_GREEN}[2]${C_RESET} ${C_WHITE}Auto Create Admin User${C_RESET}\n"
                    printf "  ${C_RED}[0]${C_RESET} ${C_WHITE}Back to Panel Menu${C_RESET}\n\n"
                    printf " ${C_BLUE}%s${C_RESET}\n\n" "$(printf '─%.0s' $(seq 1 60))"
                    
                    read -r -p " λ Choose option: " u_choice
                    
                    case "$u_choice" in
                        1) printf "\n ${C_YELLOW}[ ⏳ ]${C_RESET} Launching manual user creation...\n"; sleep 1; create_user_manual; break ;;
                        2) printf "\n ${C_YELLOW}[ ⏳ ]${C_RESET} Launching auto admin creation...\n"; sleep 1; create_user_auto; break ;;
                        0) break ;;
                        *) warn "Invalid option."; sleep 1 ;;
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
