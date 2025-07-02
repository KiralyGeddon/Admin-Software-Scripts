#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source $HOME/AdminSysTools/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: changer_droits
# Cette fonction permet de modifier les permissions d'un fichier ou d'un répertoire.
# Elle offre la possibilité de choisir entre des permissions numériques (ex: 755)
# et des permissions symboliques (ex: +x, u+rwx).
#=============================================================================
changer_droits() {
    print_step "Changement des droits (permissions) d'un fichier ou répertoire..."

    # Demande le chemin du fichier ou répertoire.
    local path
    path=$(get_input "Veuillez entrer le chemin complet du fichier ou du répertoire (ex: /var/www/html/index.html ou /opt/monapp):")

    # Vérifie si le chemin est vide.
    if [[ -z "$path" ]]; then
        print_error "Chemin vide. Annulation du changement de droits."
        return 1
    fi

    # Vérifie si le fichier ou répertoire existe.
    if [[ ! -e "$path" ]]; then
        print_error "Le chemin '$path' n'existe pas."
        return 1
    fi

    # Demande le type de modification (numérique ou symbolique).
    local permission_type
    permission_type=$(whiptail --menu "Choisissez le type de permissions à appliquer :" 10 60 2 \
        "numeric" "Permissions numériques (ex: 755, 644)" \
        "symbolic" "Permissions symboliques (ex: u+rwx, o-w)" 3>&1 1>&2 2>&3)

    if [[ -z "$permission_type" ]]; then
        print_step "Changement de droits annulé."
        return 1
    fi

    local permissions
    if [[ "$permission_type" == "numeric" ]]; then
        permissions=$(get_input "Entrez les permissions numériques (ex: 755 pour rwxr-xr-x):")
        # Vérification simple pour s'assurer que c'est un nombre à 3 ou 4 chiffres.
        if ! [[ "$permissions" =~ ^[0-7]{3,4}$ ]]; then
            print_error "Format de permissions numériques invalide. Ex: 755 ou 0755."
            return 1
        fi
    elif [[ "$permission_type" == "symbolic" ]]; then
        permissions=$(get_input "Entrez les permissions symboliques (ex: u+rwx, o-w, +x, a=rw):")
        if [[ -z "$permissions" ]]; then
            print_error "Permissions symboliques vides. Annulation."
            return 1
        fi
    fi

    # Demande si la modification doit être récursive pour les répertoires.
    local recursive_option=""
    if [[ -d "$path" ]]; then # Vérifie si c'est un répertoire.
        if whiptail --yesno "Est-ce que '$path' est un répertoire ? Appliquer les permissions de manière récursive (à tous les sous-fichiers/répertoires) ?" 8 70; then
            recursive_option="-R" # Ajoute l'option récursive.
        fi
    fi

    print_step "Application des permissions '$permissions' à '$path' $recursive_option..."

    # Exécute la commande 'chmod'.
    if sudo chmod "$recursive_option" "$permissions" "$path" &>/dev/null; then
        print_success "Les permissions de '$path' ont été changées en '$permissions' avec succès."
        return 0
    else
        print_error "Échec du changement de permissions pour '$path'."
        return 1
    fi
}

# Lance la fonction au démarrage du script.
changer_droits