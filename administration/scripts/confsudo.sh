#!/bin/bash

#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }



#=============================================================================
# Fonction: configurer_sudo
# Cette fonction offre des options pour la gestion de sudo:
# 1. Ajout d'un utilisateur au groupe sudo.
# 2. Configuration d'un utilisateur pour qu'il n'ait pas à entrer son mot de passe pour sudo.
# 3. Lancement de 'visudo' pour une édition manuelle sécurisée du fichier sudoers.
#=============================================================================
configurer_sudo() {
    print_step "Configuration des droits sudo..."

    local choice
    choice=$(whiptail --menu "Choisissez une option de configuration Sudo :" 15 70 5 \
        "1" "➕ Ajouter un utilisateur au groupe sudo" \
        "2" "🔑 Configurer un utilisateur pour NOPASSWD (pas de mot de passe pour sudo)" \
        "3" "📝 Modifier le fichier sudoers avec visudo (pour experts)" \
        "4" "↩️ Retour au menu précédent" 3>&1 1>&2 2>&3)

    if [[ -z "$choice" ]]; then
        print_step "Configuration Sudo annulée."
        return 1
    fi

    case "$choice" in
        1)
            # Ajout d'un utilisateur au groupe sudo.
            print_step "Ajout d'un utilisateur au groupe sudo..."
            local users_to_add
            # Récupère la liste de tous les utilisateurs humains, comme dans deluser.sh
            users_to_add=$(getent passwd | awk -F: '($3 >= 1000) {print $1}' | grep -vE '^(nobody|systemd-resolve|syslog|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|libuuid|systemd-timesync|messagebus|_apt|uuidd|systemd-network|systemd-coredump)$' | tr '\n' ' ')

            if [[ -z "$users_to_add" ]]; then
                print_error "Aucun utilisateur régulier trouvé à ajouter au groupe sudo."
                whiptail --msgbox "Aucun utilisateur à ajouter. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
                configurer_sudo # Revenir au menu sudo
                return 1
            fi

            local selected_user
            selected_user=$(whiptail --title "Ajouter au groupe sudo" \
                --menu "Choisissez l'utilisateur à ajouter au groupe sudo :" 20 70 10 \
                $users_to_add \
                3>&1 1>&2 2>&3)

            if [[ -z "$selected_user" ]]; then
                print_step "Sélection de l'utilisateur annulée. Aucune modification."
                whiptail --msgbox "Opération annulée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
                configurer_sudo # Revenir au menu sudo
                return 1
            fi

            # Vérifie si l'utilisateur est déjà dans le groupe sudo.
            if groups "$selected_user" | grep -qw "sudo"; then
                print_warning "L'utilisateur '$selected_user' est déjà membre du groupe sudo."
            else
                print_step "Ajout de l'utilisateur '$selected_user' au groupe sudo..."
                # 'usermod -aG sudo' : ajoute l'utilisateur au groupe 'sudo' (-a pour append, -G pour group).
                if sudo usermod -aG sudo "$selected_user" &>/dev/null; then
                    print_success "L'utilisateur '$selected_user' a été ajouté au groupe sudo."
                    print_step "Il devra se déconnecter et se reconnecter pour que les changements prennent effet."
                else
                    print_error "Échec de l'ajout de l'utilisateur '$selected_user' au groupe sudo."
                fi
            fi
            whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
        2)
            # Configurer un utilisateur pour NOPASSWD.
            print_step "Configuration de NOPASSWD pour un utilisateur..."
            whiptail --msgbox "AVERTISSEMENT: Configurer NOPASSWD réduit la sécurité du système car l'utilisateur n'aura pas à entrer son mot de passe pour les commandes sudo." 10 70

            local users_to_nopasswd
            users_to_nopasswd=$(getent passwd | awk -F: '($3 >= 1000) {print $1}' | grep -vE '^(nobody|systemd-resolve|syslog|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|libuuid|systemd-timesync|messagebus|_apt|uuidd|systemd-network|systemd-coredump)$' | tr '\n' ' ')

            if [[ -z "$users_to_nopasswd" ]]; then
                print_error "Aucun utilisateur régulier trouvé à configurer pour NOPASSWD."
                whiptail --msgbox "Aucun utilisateur à configurer. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
                configurer_sudo # Revenir au menu sudo
                return 1
            fi

            local selected_user_nopasswd
            selected_user_nopasswd=$(whiptail --title "Configurer NOPASSWD" \
                --menu "Choisissez l'utilisateur pour lequel configurer NOPASSWD :" 20 70 10 \
                $users_to_nopasswd \
                3>&1 1>&2 2>&3)

            if [[ -z "$selected_user_nopasswd" ]]; then
                print_step "Sélection de l'utilisateur annulée. Aucune modification NOPASSWD."
                whiptail --msgbox "Opération annulée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
                configurer_sudo # Revenir au menu sudo
                return 1
            fi

            # Vérifie si l'utilisateur est déjà configuré NOPASSWD.
            # On cherche la ligne dans sudoers.d/<user> ou dans /etc/sudoers
            if sudo grep -q "$selected_user_nopasswd ALL=(ALL) NOPASSWD: ALL" /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
                print_warning "L'utilisateur '$selected_user_nopasswd' est déjà configuré pour NOPASSWD."
                whiptail --msgbox "L'utilisateur '$selected_user_nopasswd' est déjà configuré pour NOPASSWD. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
                configurer_sudo
                return 0
            fi

            if whiptail --yesno "Voulez-vous que l'utilisateur '$selected_user_nopasswd' puisse exécuter des commandes sudo SANS MOT DE PASSE ?" 8 70; then
                print_step "Configuration de NOPASSWD pour '$selected_user_nopasswd'..."
                # Créer un fichier de configuration spécifique pour cet utilisateur dans /etc/sudoers.d/
                local sudoers_d_file="/etc/sudoers.d/$selected_user_nopasswd"
                # Assurez-vous que le répertoire existe
                sudo mkdir -p /etc/sudoers.d &>/dev/null

                # Ajoute la ligne de configuration NOPASSWD.
                # Utilise 'tee' avec 'sudo' pour écrire dans le fichier.
                # 'visudo -cf' vérifie la syntaxe après modification.
                if echo "$selected_user_nopasswd ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_d_file" &>/dev/null && \
                   sudo chmod 0440 "$sudoers_d_file" &>/dev/null && \
                   sudo visudo -cf "$sudoers_d_file" &>/dev/null; then
                    print_success "L'utilisateur '$selected_user_nopasswd' peut maintenant utiliser sudo sans mot de passe."
                    print_step "Pour des raisons de sécurité, envisagez de limiter les commandes NOPASSWD si possible."
                else
                    print_error "Échec de la configuration de NOPASSWD pour l'utilisateur '$selected_user_nopasswd'."
                fi
            else
                print_step "Configuration NOPASSWD annulée pour l'utilisateur '$selected_user_nopasswd'."
            fi
            whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
        3)
            # Lancement de visudo.
            print_step "Lancement de 'visudo' pour une édition manuelle du fichier sudoers..."
            whiptail --msgbox "ATTENTION: Vous êtes sur le point de modifier le fichier sudoers.\n\nUne erreur dans ce fichier peut rendre votre système inutilisable et vous empêcher d'utiliser sudo.\n\n'visudo' effectue une vérification de syntaxe." 15 70

            if whiptail --yesno "Voulez-vous continuer et modifier le fichier sudoers avec 'visudo' ?" 8 60; then
                print_step "Lancement de 'visudo'..."
                if sudo visudo; then
                    print_success "Le fichier sudoers a été modifié avec succès (ou n'a pas été modifié en cas d'annulation)."
                    print_step "Veuillez vérifier vos modifications et tester les droits si nécessaire."
                else
                    print_error "Échec de l'édition du fichier sudoers ou modifications non sauvegardées. Vérifiez les erreurs de syntaxe."
                fi
            else
                print_step "Modification du fichier sudoers annulée."
            fi
            whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
        4)
            return 0 # Retourne au menu précédent (menu_administration.sh).
            ;;
        *)
            print_error "Option invalide."
            whiptail --msgbox "Option invalide. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
    esac
}

# Lance la fonction au démarrage du script.
configurer_sudo