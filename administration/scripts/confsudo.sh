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
    choice=$(whiptail --menu "Choisissez une option de configuration Sudo :" 15 100 5 \
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
            local users_list=()
            # Lit les utilisateurs depuis /etc/passwd et filtre ceux avec UID >= 1000 (utilisateurs normaux)
            while IFS=: read -r username _ uid _ _ _ _; do
                if (( uid >= 1000 )) && [[ "$username" != "nobody" ]]; then
                    # Correction ici: utiliser le nom d'utilisateur pour la valeur et la description
                    users_list+=("$username" "$username")
                fi
            done < /etc/passwd

            if [ ${#users_list[@]} -eq 0 ]; then
                print_error "Aucun utilisateur système avec UID >= 1000 trouvé."
                whiptail --msgbox "Aucun utilisateur éligible n'a été trouvé pour l'ajout au groupe sudo." 10 60
                configurer_sudo # Revenir au menu sudo
                return
            fi

            local selected_user
            selected_user=$(whiptail --menu "Sélectionnez l'utilisateur à ajouter au groupe sudo :" 20 78 10 "${users_list[@]}" 3>&1 1>&2 2>&3)

            if [[ -z "$selected_user" ]]; then
                print_step "Ajout d'utilisateur au groupe sudo annulé."
                configurer_sudo # Revenir au menu sudo
                return
            fi

            print_step "Ajout de l'utilisateur '$selected_user' au groupe sudo..."
            if sudo usermod -aG sudo "$selected_user" &>/dev/null; then
                print_success "L'utilisateur '$selected_user' a été ajouté au groupe sudo avec succès."
                print_step "L'utilisateur devra se déconnecter et se reconnecter pour que les changements prennent effet."
            else
                print_error "Échec de l'ajout de l'utilisateur '$selected_user' au groupe sudo."
            fi
            whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
        2)
            local users_list=()
            # Lit les utilisateurs depuis /etc/passwd et filtre ceux avec UID >= 1000
            while IFS=: read -r username _ uid _ _ _ _; do
                if (( uid >= 1000 )) && [[ "$username" != "nobody" ]]; then
                    # Correction ici: utiliser le nom d'utilisateur pour la valeur et la description
                    users_list+=("$username" "$username")
                fi
            done < /etc/passwd

            if [ ${#users_list[@]} -eq 0 ]; then
                print_error "Aucun utilisateur système avec UID >= 1000 trouvé."
                whiptail --msgbox "Aucun utilisateur éligible n'a été trouvé pour la configuration NOPASSWD." 10 60
                configurer_sudo # Revenir au menu sudo
                return
            fi

            local selected_user_nopasswd
            selected_user_nopasswd=$(whiptail --menu "Sélectionnez l'utilisateur pour NOPASSWD :" 20 78 10 "${users_list[@]}" 3>&1 1>&2 2>&3)

            if [[ -z "$selected_user_nopasswd" ]]; then
                print_step "Configuration NOPASSWD annulée."
                configurer_sudo # Revenir au menu sudo
                return
            fi

            print_step "Configuration de NOPASSWD pour l'utilisateur '$selected_user_nopasswd'..."
            # Création ou modification d'un fichier sudoers dans /etc/sudoers.d
            local sudoers_file="/etc/sudoers.d/90-${selected_user_nopasswd}-nopasswd"
            local sudoers_entry="$selected_user_nopasswd ALL=(ALL) NOPASSWD: ALL"

            # Vérifie si l'entrée existe déjà pour éviter les doublons
            if sudo grep -qxF "$sudoers_entry" /etc/sudoers.d/* 2>/dev/null; then
                print_warning "La configuration NOPASSWD existe déjà pour l'utilisateur '$selected_user_nopasswd'."
            else
                if echo "$sudoers_entry" | sudo tee "$sudoers_file" &>/dev/null; then
                    print_success "NOPASSWD configuré pour '$selected_user_nopasswd'. Il ne lui sera plus demandé de mot de passe pour sudo."
                    sudo chmod 0440 "$sudoers_file" &>/dev/null # Assure les bonnes permissions
                else
                    print_error "Échec de la configuration NOPASSWD pour l'utilisateur '$selected_user_nopasswd'."
                fi
            fi
            whiptail --msgbox "Opération terminée. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
        3)
            whiptail --title "ATTENTION : Modification de Sudoers" --msgbox "\
AVERTISSEMENT: Vous êtes sur le point de modifier le fichier sudoers.

Une erreur dans ce fichier peut rendre votre système inutilisable et vous empêcher d'utiliser sudo.

'visudo' effectue une vérification de syntaxe." 15 70

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
        *).
            print_error "Option invalide."
            whiptail --msgbox "Option invalide. Appuyez sur Entrée pour revenir au menu Sudo." 8 70
            configurer_sudo # Revenir au menu sudo
            ;;
    esac
}

# Lance la fonction au démarrage du script.
configurer_sudo
