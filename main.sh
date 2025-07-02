#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
# Le '.' est un raccourci pour la commande 'source'.
# Le script s'arrête si la bibliothèque n'est pas trouvée.
source $HOME/AdminSysTools/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Fonction pour vérifier et préparer l'accès sudo de l'utilisateur.
# MODIFICATION : Cette fonction est adaptée pour permettre l'exécution par root et les utilisateurs sudoers.
check_and_prepare_sudo_access() {
    local current_user
    current_user=$(whoami) # Récupère le nom de l'utilisateur actuel.

    # Vérifie si l'utilisateur est root. Si oui, affiche un message et continue.
    if [[ "$current_user" == "root" ]]; then
        print_success "Le script est exécuté en tant que root. C'est permis."
        return 0 # Succès, car root a tous les privilèges.
    fi

    # Si l'utilisateur n'est pas root, vérifie s'il appartient au groupe sudo.
    if groups "$current_user" | grep -qw "sudo"; then
        print_success "L'utilisateur '$current_user' appartient bien au groupe sudo."
        return 0 # Succès.
    else
        # Si l'utilisateur n'est ni root ni sudoer.
        print_error "L'utilisateur '$current_user' n'appartient pas au groupe sudo."
        # Demande à l'utilisateur s'il veut ajouter les droits sudo.
        if whiptail --yesno "L'utilisateur '$current_user' n'est pas sudoer.\n\nVoulez-vous que le script génère une commande pour que root puisse ajouter les droits sudo ?" 12 60; then
            whiptail --msgbox "Connectez-vous en tant que root et exécutez cette commande :\n\nusermod -aG sudo $current_user\n\nPuis redémarrez votre machine et relancez le script." 15 70
            echo "Commande à exécuter en root : usermod -aG sudo $current_user"
            return 1 # Indique un échec, car une action manuelle est requise.
        else
            whiptail --msgbox "Vous devez ajouter manuellement l'utilisateur '$current_user' au groupe sudo :\n\nusermod -aG sudo $current_user\n\nPuis redémarrez votre machine et relancez le script." 12 70
            return 1 # Indique un échec.
        fi
    fi
}


#=============================================================================
# Affiche une "intro"
#=============================================================================
display_header() {
    local current_user
    current_user=$(whoami)
    # Tableau de chaînes de caractères pour l'art ASCII.
    local header_lines=(
        ""
        ""
        ""
        ""
        "╔═══════════════════════════════════════════════════════════════════════╗"
        "║                                                                       ║"
        "║  █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗    ███████╗██╗   ██╗███████╗ ║"
        "║ ██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║    ██╔════╝╚██╗ ██╔╝██╔════╝ ║"
        "║ ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║    ███████╗ ╚████╔╝ ███████╗ ║"
        "║ ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║    ╚════██║  ╚██╔╝  ╚════██║ ║"
        "║ ██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║    ███████║   ██║   ███████║ ║"
        "║ ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝    ╚══════╝   ╚═╝   ╚══════╝ ║"
        "║             ████████╗ ██████╗  ██████╗ ██╗     ███████╗               ║"
        "║             ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝               ║"
        "║                ██║   ██║   ██║██║   ██║██║     ███████╗               ║"
        "║                ██║   ██║   ██║██║   ██║██║     ╚════██║               ║"
        "║                ██║   ╚██████╔╝╚██████╔╝███████╗███████║               ║"
        "║                ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝               ║"
        "║                                                                       ║"
        "╚═══════════════════════════════════════════════════════════════════════╝"
        ""
        "                       Bonjour ${YELLOW}${BOLD}'$current_user'${RESET}"
        ""
        "${CYAN}Ceci est un outil d'administration système et d'installation automatique${RESET}"
        "            ${CYAN}  de logiciels via Docker et DockerCompose${RESET}"
        ""
        ""
        "             ========================================="
        "                    Projet Formation - TSSR 0325"
        "             ========================================="
        ""
        " Contributeurs : "
        "      Edo-ops [https://github.com/edo-ops] - Conception de la tramme"
        "      Nounoursss93 [https://github.com/Nounoursss93] - Menu 'Logiciel'"
        "      Midas-ivar [https://github.com/Midas-ivar] - Visionneur de log"
        "      KiralyGeddon [https://github.com/KiralyGeddon] - Developpement"
        "                     du reste des scripts et du design"
        ""         
        "            ${RED}Sans oublier les IA ChatGPT - ClaudeAI - Gemini${RESET}"
        ""
        ""
    )

    clear # Efface l'écran du terminal.

    # Parcourt chaque ligne du tableau d'art ASCII.
    for line in "${header_lines[@]}"; do
        # Applique des couleurs spécifiques en fonction du contenu de la ligne.
        if [[ "$line" == *"TSSR"* ]]; then
            echo -e "${CYAN}${BOLD}$line${RESET}" # Cyan gras pour la ligne TSSR.
        elif [[ "$line" == *"===="* ]]; then
            echo -e "${YELLOW}$line${RESET}" # Jaune pour les lignes de séparateur.
        else
            echo -e "${GREEN}$line${RESET}" # Vert pour les autres lignes (l'art ASCII principal).
        fi
        sleep 0.05 # Petite pause pour un effet d'animation visuel.
    done

    sleep 3 # Pause finale après l'affichage de l'en-tête.
}


# Fonction pour effectuer une mise à jour système.
maj(){
    print_step "Démarrage de la mise à jour du système..."
    
    local apt_command=""
    if [[ "$(whoami)" == "root" ]]; then
        apt_command="apt update -y && apt upgrade -y"
    else
        apt_command="sudo apt update -y && sudo apt upgrade -y"
    fi

    # Exécute la mise à jour en arrière-plan.
    # Redirige la sortie vers un fichier temporaire pour le débogage si nécessaire,
    # ou directement vers /dev/null si vous voulez absolument aucun log.
    # Pour un silence complet: $apt_command > /dev/null 2>&1 &
    # Pour capturer les erreurs pour un potentiel affichage plus tard:
    # ($apt_command) &> apt_update_log.txt &
    
    # Let's keep it silent for the user experience, but we could redirect to a file for better debugging if needed.
    (eval "$apt_command") > /dev/null 2>&1 &
    local apt_pid=$! # Capture le PID du processus apt.

    # Affiche une barre de progression pendant que la mise à jour est en cours, surveillant le PID.
    # No fixed duration needed, it will end when the PID stops.
    progress_bar "Mise à jour du système en cours..." "" "$apt_pid"
    
    # Wait for the background process to truly finish, in case the progress bar finished early
    # (e.g., if the process became a zombie or something unexpected).
    # This also captures the exit status.
    wait "$apt_pid"
    local apt_status=$? # Récupère le code de sortie de la commande apt.

    if [ $apt_status -eq 0 ]; then
        print_success "Mise à jour du système effectuée avec succès !"
        return 0 # Indique le succès.
    else
        print_error "Échec de la mise à jour du système. Code de sortie: $apt_status"
        # You could also show a message box with whiptail here, or display apt_update_log.txt
        return 1 # Indique l'échec.
    fi
}


# =============================================================================
# Fonction pour afficher le contenu d’un fichier de log
# =============================================================================
display_log_content() {
    local log_path="$1"
    local log_name="$2"

    print_step "Affichage de '$log_name'..."

    local temp_file
    temp_file=$(mktemp)
    if cat "$log_path" > "$temp_file" 2>/dev/null; then
        exec 3>&1
        whiptail --title "Contenu de : $log_name" --textbox "$temp_file" 25 150 --scrolltext 2>&1 1>&3
        exec 3>&-
        print_success "Consultation de '$log_name' terminée."
    else
        whiptail --title "Erreur" --msgbox "Impossible de lire le fichier de log '$log_name'.\nVérifiez les permissions." 8 60
    fi

    rm -f "$temp_file"
}

# =============================================================================
# FONCTION ÉTENDUE : Consulter les fichiers de log du système
# Affiche une liste de fichiers de log système et services spécialisés
# =============================================================================
view_logs() {
    print_step "Chargement de la visionneuse de logs..."

    # Détermine la commande de lecture (avec ou sans sudo)
    local read_command
    if [[ "$(whoami)" == "root" ]]; then
        read_command="cat"
    else
        read_command="sudo cat"
    fi

    # Fonction pour afficher un sous-menu de logs spécialisés
    show_specialized_logs() {
        local category="$1"
        local -a log_paths=()
        local -a log_descriptions=()

        case "$category" in
            "docker")
                log_paths=(
                    "/var/log/docker.log"
                    "/var/lib/docker/containers/*/containerd-shim.log"
                    "/var/log/syslog"
                )
                log_descriptions=(
                    "Docker - Log principal"
                    "Docker - Logs conteneurs"
                    "Syslog - Recherche Docker"
                )
                ;;
            "glpi")
                log_paths=(
                    "/var/log/apache2/access.log"
                    "/var/log/apache2/error.log"
                    "/var/log/mysql/error.log"
                    "/var/log/php*.log"
                )
                log_descriptions=(
                    "GLPI - Accès Apache"
                    "GLPI - Erreurs Apache"
                    "GLPI - Erreurs MySQL"
                    "GLPI - Erreurs PHP"
                )
                ;;
            "zabbix")
                log_paths=(
                    "/var/log/zabbix/zabbix_server.log"
                    "/var/log/zabbix/zabbix_agentd.log"
                    "/var/log/apache2/zabbix_access.log"
                    "/var/log/mysql/mysql.log"
                )
                log_descriptions=(
                    "Zabbix - Serveur"
                    "Zabbix - Agent"
                    "Zabbix - Accès web"
                    "Zabbix - Base de données"
                )
                ;;
            "nagios")
                log_paths=(
                    "/var/log/nagios3/nagios.log"
                    "/var/log/nagios4/nagios.log"
                    "/var/log/apache2/access.log"
                    "/var/log/apache2/error.log"
                )
                log_descriptions=(
                    "Nagios 3 - Principal"
                    "Nagios 4 - Principal"
                    "Nagios - Accès web"
                    "Nagios - Erreurs web"
                )
                ;;
            "xivo")
                log_paths=(
                    "/var/log/asterisk/messages"
                    "/var/log/asterisk/full"
                    "/var/log/xivo-ctid/xivo-ctid.log"
                    "/var/log/xivo-agid/xivo-agid.log"
                )
                log_descriptions=(
                    "XIVO - Messages Asterisk"
                    "XIVO - Log complet"
                    "XIVO - CTI Daemon"
                    "XIVO - AGI Daemon"
                )
                ;;
        esac

        # Trouve les logs existants
        local existing_logs=()
        local existing_descriptions=()

        for i in "${!log_paths[@]}"; do
            local log_path="${log_paths[i]}"
            if [[ "$log_path" == *"*"* ]]; then
                # Gestion des wildcards
                local found_logs
                found_logs=$(find "$(dirname "$log_path")" -name "$(basename "$log_path")" 2>/dev/null | head -5)
                if [[ -n "$found_logs" ]]; then
                    while IFS= read -r found_log; do
                        if [[ -f "$found_log" && -r "$found_log" ]]; then
                            existing_logs+=("$found_log")
                            existing_descriptions+=("${log_descriptions[i]} - $(basename "$found_log")")
                        fi
                    done <<< "$found_logs"
                fi
            else
                if [[ -f "$log_path" && -r "$log_path" ]]; then
                    existing_logs+=("$log_path")
                    existing_descriptions+=("${log_descriptions[i]}")
                fi
            fi
        done

        if [ ${#existing_logs[@]} -eq 0 ]; then
            whiptail --title "Aucun log trouvé" --msgbox "Aucun fichier de log n'a été trouvé pour cette catégorie." 8 60
            return 1
        fi

        # Prépare le menu
        local menu_items=()
        for i in "${!existing_logs[@]}"; do
            menu_items+=("$((i + 1))" "${existing_descriptions[i]}")
        done

        # Affiche le menu de sélection
        local choice
        exec 3>&1
        choice=$(whiptail --title "Logs - $(echo "$category" | tr '[:lower:]' '[:upper:]')" --menu "Choisissez un fichier de log :" 20 78 12 "${menu_items[@]}" 2>&1 1>&3)
        local exit_status=$?
        exec 3>&-

        if [ $exit_status -ne 0 ]; then
            return 0
        fi

        local selected_log_path="${existing_logs[$((choice - 1))]}"
        local selected_log_name=$(basename "$selected_log_path")

        display_log_content "$selected_log_path" "$selected_log_name"
    }

    while true; do
        local main_choice
        exec 3>&1
        main_choice=$(whiptail --title "Visionneuse de Logs" --menu "Sélectionnez une catégorie de logs :" 22 78 14 \
            "1" "🐳 Docker (Portainer)" \
            "2" "🎯 GLPI (Gestion de parc)" \
            "3" "📊 Zabbix (Supervision)" \
            "4" "👁️  Nagios (Supervision)" \
            "5" "📞 XIVO (VoIP)" \
            "6" "📋 Logs système standard" \
            "7" "↩️  Retour au menu principal" \
            2>&1 1>&3)
        local exit_status=$?
        exec 3>&-

        if [ $exit_status -ne 0 ]; then
            return 0
        fi

        case "$main_choice" in
            "1") show_specialized_logs "docker" ;;
            "2") show_specialized_logs "glpi" ;;
            "3") show_specialized_logs "zabbix" ;;
            "4") show_specialized_logs "nagios" ;;
            "5") show_specialized_logs "xivo" ;;
            "6") 
                local available_logs=()
                while IFS= read -r -d '' log_file; do
                    available_logs+=("$log_file")
                done < <(find /var/log -maxdepth 1 -type f \( -name "*.log" -o -name "syslog" -o -name "auth.log" -o -name "kern.log" -o -name "dpkg.log" \) -print0 2>/dev/null)

                if [ ${#available_logs[@]} -eq 0 ]; then
                    whiptail --title "Aucun log trouvé" --msgbox "Aucun fichier de log système standard n'a été trouvé." 8 60
                    continue
                fi

                local menu_items=()
                for i in "${!available_logs[@]}"; do
                    menu_items+=("$((i + 1))" "$(basename "${available_logs[i]}")")
                done

                local choice
                exec 3>&1
                choice=$(whiptail --title "Logs Système Standard" --menu "Choisissez un fichier de log :" 20 78 12 "${menu_items[@]}" 2>&1 1>&3)
                local exit_status=$?
                exec 3>&-

                if [ $exit_status -eq 0 ]; then
                    local selected_log_path="${available_logs[$((choice - 1))]}"
                    local selected_log_name
                    selected_log_name=$(basename "$selected_log_path")
                    display_log_content "$selected_log_path" "$selected_log_name"
                fi
                ;;
            "7")
                return 0
                ;;
        esac
    done
}

# =============================================================================
# Menu Principal
# =============================================================================
main_menu() {
    while true; do
        echo -e "${BOLD}${CYAN}=========================================${RESET}"
        echo -e "${BOLD}${CYAN}          Menu Principal   ${RESET}"
        echo -e "${BOLD}${CYAN}=========================================${RESET}"
        echo ""
        echo -e "${GREEN}1- ${RESET}🛠️  Outils d'Administration"
        echo -e "${GREEN}2- ${RESET}💾  Installation de logiciels"
        echo -e "${GREEN}3- ${RESET}♻️  Mise à jour du système"
        echo -e "${GREEN}4- ${RESET}👁️  Consulter les logs système"
        echo -e "${GREEN}5- ${RESET}❌  Quitter"
        echo ""
        echo -e "${BOLD}${CYAN}=========================================${RESET}"
        echo -ne "${BOLD}Entrez votre choix : ${RESET}"
        read -r choice < /dev/tty

        if [[ -z "$choice" ]]; then
            print_error "Aucun choix entré. Veuillez sélectionner une option."
            echo "Appuyez sur Entrée pour continuer..."
            read -r < /dev/tty
            continue
        fi

        local result=0
        case "$choice" in
            1)
                chmod +x $HOME/AdminSysTools/administration/menu_administration.sh
                ./administration/menu_administration.sh
                result=$?
                ;;
            2)
                chmod +x $HOME/AdminSysTools/logiciels/menu_logiciels.sh
                ./logiciels/menu_logiciels.sh
                result=$?
                ;;
            3)
                maj || result=$?
                ;;
            4)
                view_logs || result=$?
                ;;
            5)
                print_success "Au revoir et merci d'avoir utilisé le script !"
                exit 0
                ;;
            *)
                print_error "Option invalide. Veuillez choisir une option valide dans le menu."
                echo "Appuyez sur Entrée pour continuer..."
                read -r < /dev/tty
                ;;
        esac

        if [[ "$result" -ne 0 ]]; then
            print_step "Appuyez sur Entrée pour revenir au menu principal..."
            read -r < /dev/tty
        fi
    done
}

# =============================================================================
# Fonction principale
# =============================================================================
main() {
    find $HOME/AdminSysTools -type f -name "*.sh" -exec chmod +x {} \;
    check_whiptail || exit 1
    check_and_prepare_sudo_access || exit 1
    display_header
    main_menu
}

# Lancement du script
main
