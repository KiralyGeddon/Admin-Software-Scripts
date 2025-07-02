#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source ../../librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: configurer_ssh
# Cette fonction permet de configurer le serveur SSH (OpenSSH).
# Elle offre des options pour changer le port, désactiver l'authentification par mot de passe, etc.
#=============================================================================
configurer_ssh() {
    print_step "Configuration du serveur OpenSSH..."

    # Vérifie si le paquet OpenSSH-server est installé.
    if ! dpkg -s openssh-server &>/dev/null; then
        print_step "Le paquet 'openssh-server' n'est pas installé. Tentative d'installation..."
        if sudo apt update -y &>/dev/null && sudo apt install -y openssh-server &>/dev/null; then
            print_success "'openssh-server' a été installé avec succès."
        else
            print_error "Échec de l'installation de 'openssh-server'. Veuillez l'installer manuellement et relancer le script."
            return 1
        fi
    fi

    # Chemin du fichier de configuration SSH.
    local ssh_config_file="/etc/ssh/sshd_config"

    # Vérifie si le fichier de configuration existe.
    if [[ ! -f "$ssh_config_file" ]]; then
        print_error "Le fichier de configuration SSH '$ssh_config_file' est introuvable."
        return 1
    fi

    local choice
    choice=$(whiptail --menu "Choisissez une option de configuration SSH :" 15 70 5 \
        "1" "Changer le port SSH (par défaut 22)" \
        "2" "Désactiver l'authentification par mot de passe (recommandé pour la sécurité)" \
        "3" "Activer/Désactiver la connexion root" \
        "4" "Redémarrer le service SSH" \
        "5" "Retour au menu précédent" 3>&1 1>&2 2>&3)

    if [[ -z "$choice" ]]; then
        print_step "Configuration SSH annulée."
        return 1
    fi

    case "$choice" in
        1)
            local new_port
            new_port=$(get_input "Entrez le nouveau port SSH (ex: 2222). Laissez vide pour annuler:")
            if [[ -z "$new_port" ]]; then
                print_step "Changement de port annulé."
                return 1
            fi
            # Vérifie si le port est un nombre valide.
            if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 )) || (( new_port > 65535 )); then
                print_error "Port invalide. Doit être un nombre entre 1 et 65535."
                return 1
            fi

            print_step "Changement du port SSH à '$new_port' dans '$ssh_config_file'..."
            # Utilise 'sed' pour commenter l'ancienne ligne 'Port' et ajouter la nouvelle.
            if sudo sed -i "/^#Port /c\Port $new_port" "$ssh_config_file" && \
               sudo sed -i "/^Port [0-9]\+/s/^Port/#Port/" "$ssh_config_file"; then
                # On ajoute la nouvelle ligne Port à la fin du fichier pour s'assurer qu'elle est active.
                echo "Port $new_port" | sudo tee -a "$ssh_config_file" &>/dev/null
                print_success "Le port SSH a été changé en '$new_port'."
                print_step "N'oubliez pas de redémarrer le service SSH (option 4) pour appliquer le changement."
            else
                print_error "Échec du changement du port SSH."
            fi
            ;;
        2)
            if whiptail --yesno "Désactiver l'authentification par mot de passe SSH? (Recommandé pour la sécurité, utiliser des clés SSH)." 8 70; then
                print_step "Désactivation de l'authentification par mot de passe..."
                # Modifie la ligne 'PasswordAuthentication' à 'no'.
                if sudo sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' "$ssh_config_file"; then
                    print_success "Authentification par mot de passe désactivée."
                    print_step "Assurez-vous d'avoir configuré l'authentification par clés SSH avant de redémarrer le service!"
                    print_step "N'oubliez pas de redémarrer le service SSH (option 4) pour appliquer le changement."
                else
                    print_error "Échec de la désactivation de l'authentification par mot de passe."
                fi
            else
                print_step "Désactivation de l'authentification par mot de passe annulée."
            fi
            ;;
        3)
            local current_permit_root=$(grep -E '^\s*PermitRootLogin' "$ssh_config_file" | awk '{print $2}')
            local new_state
            if [[ "$current_permit_root" == "yes" || -z "$current_permit_root" ]]; then # Assume yes if not explicitly set
                new_state="no"
                if whiptail --yesno "La connexion root directe est actuellement autorisée (ou par défaut). Voulez-vous la DÉSACTIVER (recommandé) ?" 8 70; then
                    print_step "Désactivation de la connexion root directe..."
                    if sudo sed -i 's/^#\?PermitRootLogin yes/PermitRootLogin no/' "$ssh_config_file"; then
                        print_success "Connexion root directe désactivée."
                    else
                        print_error "Échec de la désactivation de la connexion root directe."
                    fi
                fi
            else # current_permit_root is 'no' or 'prohibit-password'
                new_state="yes"
                if whiptail --yesno "La connexion root directe est actuellement DÉSACTIVÉE. Voulez-vous la RÉACTIVER (déconseillé pour la sécurité) ?" 8 70; then
                    print_step "Activation de la connexion root directe..."
                    if sudo sed -i 's/^#\?PermitRootLogin no/PermitRootLogin yes/' "$ssh_config_file"; then
                        print_success "Connexion root directe activée."
                        print_warning "L'activation de la connexion root directe est une faille de sécurité majeure."
                    else
                        print_error "Échec de l'activation de la connexion root directe."
                    fi
                fi
            fi
            print_step "N'oubliez pas de redémarrer le service SSH (option 4) pour appliquer le changement."
            ;;
        4)
            print_step "Redémarrage du service SSH..."
            # Redémarre le service SSH pour appliquer les modifications.
            if sudo systemctl restart ssh &>/dev/null; then
                print_success "Service SSH redémarré avec succès."
            else
                print_error "Échec du redémarrage du service SSH. Vérifiez les logs pour plus d'informations (sudo systemctl status ssh)."
            fi
            ;;
        5)
            return 0 # Retourne au menu précédent.
            ;;
        *)
            print_error "Option invalide."
            ;;
    esac
    # Redemande à l'utilisateur s'il veut continuer à configurer SSH ou revenir au menu.
    whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu de configuration SSH." 8 70
    # La boucle 'while true' dans 'configurer_ssh' fait qu'on reste dans ce menu jusqu'à ce que l'utilisateur choisisse 5.
    configurer_ssh # Rappelle la fonction pour réafficher le menu SSH.
}

# Lance la fonction au démarrage du script.
configurer_ssh