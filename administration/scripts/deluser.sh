#!/bin/bash

#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }


#=============================================================================
# Fonction: supprimer_utilisateur
# Cette fonction gère la suppression d'un utilisateur du système.
# Elle affiche une liste des utilisateurs existants pour permettre la sélection.
#=============================================================================
supprimer_utilisateur() {
    print_step "Suppression d'un utilisateur existant..."

    # Récupère la liste de tous les utilisateurs humains (UID >= 1000 et shell valide).
    # On exclut 'root' et les utilisateurs système par défaut.
    local users_list_for_whiptail="" # Initialisation d'une chaîne vide pour la liste formatée

    # getent passwd | awk -F: '($3 >= 1000) {print $1}' : Cette commande liste les utilisateurs avec un UID supérieur ou égal à 1000 (utilisateurs réguliers)
    # grep -vE ... : exclut les utilisateurs système communs qui ne devraient pas être supprimés par cette fonction.
    # Tant que la boucle lit un utilisateur, il est ajouté à la chaîne 'users_list_for_whiptail' au format 'tag item'.
    while IFS= read -r user; do # Lit chaque ligne (utilisateur) séparément
        # Ajoute l'utilisateur deux fois : une fois comme "tag" et une fois comme "item".
        # C'est le format attendu par whiptail --menu pour afficher chaque élément sur une ligne distincte.
        users_list_for_whiptail+="$user \"\" "
    done < <(getent passwd | awk -F: '($3 >= 1000) {print $1}' | grep -vE '^(nobody|systemd-resolve|syslog|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|libuuid|systemd-timesync|messagebus|_apt|uuidd|systemd-network|systemd-coredump)$')

    # Supprime le dernier espace superflu si la liste n'est pas vide
    users_list_for_whiptail=$(echo "$users_list_for_whiptail" | sed 's/ *$//')

    # Vérifie si des utilisateurs ont été trouvés pour la suppression.
    if [[ -z "$users_list_for_whiptail" ]]; then
        print_error "Aucun utilisateur régulier trouvé sur le système pour la suppression."
        return 1
    fi

    local username_to_delete
    # Affiche un menu Whiptail avec la liste des utilisateurs.
    # La variable 'users_list_for_whiptail' contient maintenant les utilisateurs au format 'tag item tag item ...'
    # ce qui permet à whiptail de les afficher correctement, un par ligne.
    username_to_delete=$(whiptail --title "Sélectionner un utilisateur à supprimer" \
        --menu "Choisissez l'utilisateur à supprimer :" 20 70 10 \
        $users_list_for_whiptail \
        3>&1 1>&2 2>&3)

    # Vérifie si l'utilisateur a annulé la sélection.
    if [[ -z "$username_to_delete" ]]; then
        print_step "Sélection de l'utilisateur annulée. Suppression non effectuée."
        return 1
    fi

    # Vérifie si l'utilisateur à supprimer est l'utilisateur actuel.
    if [[ "$username_to_delete" == "$(whoami)" ]]; then
        print_error "Vous ne pouvez pas supprimer votre propre compte utilisateur."
        whiptail --msgbox "Vous ne pouvez pas supprimer votre propre compte utilisateur." 8 90
        return 1
    fi

    # Vérifie si l'utilisateur existe avant de tenter de le supprimer (double-vérification).
    if ! id -u "$username_to_delete" &>/dev/null; then
        print_error "L'utilisateur '$username_to_delete' n'existe pas ou n'est pas un utilisateur régulier géré ici."
        return 1
    fi

    # Demande confirmation avant de supprimer l'utilisateur et son répertoire personnel.
    if whiptail --yesno "Êtes-vous sûr de vouloir supprimer l'utilisateur '$username_to_delete' et son répertoire personnel ?" 8 60; then
        print_step "Suppression de l'utilisateur '$username_to_delete'..."
        # 'sudo userdel -r "$username_to_delete"' : supprime l'utilisateur et son répertoire personnel (-r).
        # '&>/dev/null' : Redirige la sortie standard et d'erreur vers /dev/null pour éviter l'affichage de messages de userdel.
        if sudo userdel -r "$username_to_delete" &>/dev/null; then
            print_success "L'utilisateur '$username_to_delete' a été supprimé avec succès."
            return 0
        else
            print_error "Échec de la suppression de l'utilisateur '$username_to_delete'. Vérifiez les permissions ou si l'utilisateur est connecté."
            return 1
        fi
    else
        print_step "Suppression de l'utilisateur annulée."
        return 1 # Annulation par l'utilisateur.
    fi
}

# Lance la fonction au démarrage du script.
supprimer_utilisateur