#!/bin/bash

# Script écrit par Babak

# Couleurs terminal (facultatif si utilisé sans GUI)
rouge='\e[31m'
vert='\e[32m'
bleu='\e[34m'
jaune='\e[33m'
reset='\e[0m'

# Fonction pour installer les logiciels (fictifs ici)
installer() {
    echo -e "${bleu}🔧 Préparation de l'installation de : $1${reset}"
    sleep 1
}

installer1() {
    echo -e "${vert}✔️  $1 installé avec succès !${reset}"
    sleep 1.5
}

# Fonction pour vérifier et installer Docker
check_and_install_docker() {
    if ! command -v docker &> /dev/null
    then
        whiptail --title "Docker non détecté" --yesno "Docker n'est pas installé sur votre système. Souhaitez-vous l'installer maintenant ?" 10 60
        if [ $? -eq 0 ]; then
            echo -e "${bleu}🔧 Installation de Docker...${reset}"
            bash $HOME/AdminSysTools/logiciels/scripts/install_docker.sh
            if [ $? -eq 0 ]; then
                echo -e "${vert}✔️ Docker installé avec succès !${reset}"
                sleep 2
            else
                echo -e "${rouge}❌ Échec de l'installation de Docker.${reset}"
                sleep 3
                return 1
            fi
        else
            echo -e "${jaune}Installation de Docker annulée. Impossible de continuer sans Docker.${reset}"
            sleep 3
            return 1
        fi
    fi
    return 0
}

# Sous-menu Docker stylé
sous_menu_docker() {
    if ! check_and_install_docker; then
        return # Retourne au menu principal si Docker n'est pas installé
    fi

    CHOIX=$(whiptail --title "🚀 Déploiement Docker Centralisé" --menu "Sélectionnez un logiciel à installer :" 20 90 10 \
        "1" "📊  Portainer     - Interface web Docker" \
        "2" "🖥️  GLPI          - Gestion de parc informatique"   \
        "3" "📈  Zabbix        - Supervision réseau avancée" \
        "4" "📡  Nagios        - Monitoring et alertes système" \
        "5" "📞  XiVO          - Téléphonie IP (VOIP)" \
        "6" "↩️  Retour" 3>&1 1>&2 2>&3)

    case $CHOIX in
        1) logiciel="portainer" && installer "Portainer" && bash $HOME/AdminSysTools/logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;
        2) logiciel="glpi" && installer "GLPI (Gestion de parc)" && bash $HOME/AdminSysTools/logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;
        3) logiciel="zabbix" && installer "Zabbix (Supervision)" && bash $HOME/AdminSysTools/logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;
        4) logiciel="nagios" && installer "Nagios (Supervision)" && bash $HOME/AdminSysTools/logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;
        5) logiciel="xivo" && installer "XiVO (VOIP)" && bash $HOME/AdminSysTools/logiciels/scripts/install_$logiciel.sh && installer1 $logiciel ;;
        6) return ;;
        *) echo -e "${rouge}❌ Option invalide${reset}" ;;
    esac
}

# Menu principal
menu_principal(){
while true; do
    CHOIX_PRINCIPAL=$(whiptail --title "🧭 Menu Principal Administration" --menu "Que souhaitez-vous faire ?" 15 90 5 \
        "1" "🛠️  Installation de logiciels via Docker"   \
        "2" "🚪 Quitter" 3>&1 1>&2 2>&3)

    case $CHOIX_PRINCIPAL in
        1) sous_menu_docker ;;
        2) #clear
           echo -e "${jaune}👋 Merci d'avoir utilisé ce menu, à bientôt.${reset}"
           exit 0 ;;
        *) echo -e "${rouge}❌ Option invalide${reset}" ;;
    esac
done
}

main(){
    # Ensure the install_docker.sh script is executable
    chmod +x $HOME/AdminSysTools/logiciels/scripts/*.sh 2>/dev/null || true
    menu_principal
}

main