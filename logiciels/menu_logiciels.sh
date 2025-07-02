#!/bin/bash

#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées en utilisant le chemin absolu.
source "$SCRIPT_DIR/../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }


# Fonction pour installer les logiciels (fictifs ici)
installer() {
    print_step " Préparation de l'installation de : $1${RESET}"
    sleep 1
}

installer1() {
    print_success "  $1 installé avec succès !${RESET}"
    sleep 1.5
}

# Fonction pour vérifier et installer Docker
check_and_install_docker() {
    # Inclusion de la bibliothèque de fonctions partagées, si ce n'est pas déjà fait
    # (Ceci est déjà fait au début du script, mais c'est un rappel au cas où)
    # source "$SCRIPT_DIR/../librairies/lib.sh"

    if ! command -v docker &> /dev/null
    then
        whiptail --title "Docker non détecté" --yesno "Docker n'est pas installé sur votre système. Souhaitez-vous l'installer maintenant ? L'installation sera enregistrée dans les logs." 12 70
        if [ $? -eq 0 ]; then
            print_step "Démarrage de l'installation de Docker..."

            # Define the log file path, consistent with install_docker.sh
            # We need to go up two levels from 'logiciels' to the root, then into 'logs'.
            LOG_FILE="$SCRIPT_DIR/../../logs/AdminSysTools_install_docker.log"

            # Remove previous log if it exists to start fresh
            rm -f "$LOG_FILE"

            # Run install_docker.sh in the background and get its PID
            bash "$SCRIPT_DIR/scripts/install_docker.sh" &
            INSTALL_PID=$!

            # Display progress bar while installation is running
            progress_bar "Installation de Docker en cours... (Voir les détails dans $LOG_FILE)" 0 "$INSTALL_PID"

            # Wait for the background process to finish and get its exit status
            wait "$INSTALL_PID"
            INSTALL_STATUS=$?

            if [ "$INSTALL_STATUS" -eq 0 ]; then
                print_success "Docker installé avec succès ! (Veuillez vous déconnecter/reconnecter pour utiliser Docker sans sudo)"
                whiptail --msgbox "Docker a été installé avec succès !\\n\\nPour pouvoir utiliser Docker sans 'sudo', vous devez vous déconnecter et vous reconnecter à votre session." 12 70
                sleep 2
            else
                print_error "Échec de l'installation de Docker. Veuillez consulter le fichier de log pour plus de détails : $LOG_FILE"
                whiptail --msgbox "L'installation de Docker a échoué !\\n\\nVeuillez consulter le fichier de log pour plus de détails :\\n$LOG_FILE" 15 80
                sleep 3
                return 1 # Indicate failure
            fi
        else
            echo -e "${YELLOW}Installation de Docker annulée. Impossible de continuer sans Docker.${RESET}"
            whiptail --msgbox "Installation de Docker annulée. Certains logiciels peuvent ne pas fonctionner sans Docker." 10 60
            return 1
        fi
    fi
    return 0
}


# Menu principal (maintenant le seul menu)
menu_principal(){
    while true; do
        # Vérifie et installe Docker avant d'afficher le menu d'installation des logiciels
        if ! check_and_install_docker; then
            echo -e "${YELLOW}Impossible de procéder à l'installation des logiciels sans Docker. Veuillez installer Docker pour continuer.${RESET}"
            # Option pour sortir ou re-proposer le menu
            if (whiptail --title "Action Requise" --yesno "Docker n'est pas installé. Souhaitez-vous réessayer d'installer Docker ou quitter le menu ?" 10 60 --yes-button "Réessayer Docker" --no-button "Quitter"); then
                continue # Réessaye l'installation de Docker
            else
                echo -e "${YELLOW}👋 Merci d'avoir utilisé ce menu, à bientôt !${RESET}"
                exit 0 # Quitte le script
            fi
        fi

        CHOIX_PRINCIPAL=$(whiptail --title "🚀 Déploiement Logiciels via Docker" --menu "Sélectionnez un logiciel à installer :" 20 90 7 \
            "1" "📊 Portainer - Interface web Docker" \
            "2" "🖥️ GLPI - Gestion de parc informatique" \
            "3" "📈 Zabbix - Supervision réseau avancée" \
            "4" "📡 Nagios - Monitoring et alertes système" \
            "5" "📞 XiVO - Téléphonie VoIP (simplifié)" \
            "6" "🚪 Quitter" 3>&1 1>&2 2>&3)

        case $CHOIX_PRINCIPAL in
            1) logiciel="portainer" && installer "Portainer" && bash $SCRIPT_DIR/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            2) logiciel="glpi" && installer "GLPI (Gestion de parc)" && bash $SCRIPT_DIR/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            3) logiciel="zabbix" && installer "Zabbix (Supervision)" && bash $SCRIPT_DIR/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            4) logiciel="nagios" && installer "Nagios (Supervision)" && bash $SCRIPT_DIR/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            5) logiciel="xivo" && installer "XiVO (VOIP)" && bash $SCRIPT_DIR/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            6) #clear
               echo -e "${YELLOW}👋 Merci d'avoir utilisé ce menu, à bientôt !${RESET}"
               exit 0 ;;\
            *) print_error "Option invalide$" ;;\
        esac
    done
}

# Appel du menu principal au démarrage du script
menu_principal