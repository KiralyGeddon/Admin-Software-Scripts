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
    if ! command -v docker &> /dev/null
    then
        whiptail --title "Docker non détecté" --yesno "Docker n'est pas installé sur votre système. Souhaitez-vous l'installer maintenant ?" 10 60
        if [ $? -eq 0 ]; then
            print_step "Installation de Docker..."
            # Assumer que install_docker.sh est dans ./scripts/
            bash scripts/install_docker.sh
            if [ $? -eq 0 ]; then
                print_success "Docker installé avec succès !"
                sleep 2
            else
                print_error "Échec de l'installation de Docker."
                sleep 3
                return 1
            fi
        else
            echo -e "${YELLOW}Installation de Docker annulée. Impossible de continuer sans Docker.${RESET}"
            sleep 3
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
            1) logiciel="portainer" && installer "Portainer" && bash logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            2) logiciel="glpi" && installer "GLPI (Gestion de parc)" && bash logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            3) logiciel="zabbix" && installer "Zabbix (Supervision)" && bash logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            4) logiciel="nagios" && installer "Nagios (Supervision)" && bash logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            5) logiciel="xivo" && installer "XiVO (VOIP)" && bash logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;\
            6) #clear
               echo -e "${YELLOW}👋 Merci d'avoir utilisé ce menu, à bientôt !${RESET}"
               exit 0 ;;\
            *) print_error "Option invalide$" ;;\
        esac
    done
}

# Appel du menu principal au démarrage du script
menu_principal