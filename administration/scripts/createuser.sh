#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
# C'est essentiel pour utiliser les fonctions comme 'print_step', 'print_success', 'print_error', et 'get_input'.
source $HOME/AdminSysTools/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: créer_utilisateur
# Cette fonction gère la création d'un nouvel utilisateur sur le système.
#=============================================================================
creer_utilisateur() {
    print_step "Création d'un nouvel utilisateur..."

    # Demande à l'utilisateur d'entrer le nom du nouvel utilisateur.
    # 'get_input' est une fonction personnalisée qui gère la saisie utilisateur.
    local username
    username=$(get_input "Veuillez entrer le nom d'utilisateur du nouvel utilisateur:")

    # Vérifie si le nom d'utilisateur est vide.
    if [[ -z "$username" ]]; then
        print_error "Nom d'utilisateur vide. Annulation de la création d'utilisateur."
        return 1 # Retourne 1 pour indiquer un échec.
    fi

    # Vérifie si l'utilisateur existe déjà sur le système.
    # 'id -u' tente d'obtenir l'UID (User ID) de l'utilisateur. S'il n'existe pas, 'id -u' échoue.
    if id -u "$username" &>/dev/null; then
        print_error "L'utilisateur '$username' existe déjà."
        return 1 # Retourne 1 car l'utilisateur ne peut pas être créé.
    fi

    # Demande à l'utilisateur de définir le mot de passe du nouvel utilisateur.
    # 'get_input_password' est une fonction personnalisée pour une saisie sécurisée du mot de passe.
    local password
    password=$(get_input_password "Veuillez entrer le mot de passe pour '$username':")

    # Demande la confirmation du mot de passe.
    local password_confirm
    password_confirm=$(get_input_password "Veuillez confirmer le mot de passe:")

    # Vérifie si les deux mots de passe correspondent.
    if [[ "$password" != "$password_confirm" ]]; then
        print_error "Les mots de passe ne correspondent pas. Annulation de la création d'utilisateur."
        return 1 # Retourne 1 pour indiquer un échec.
    fi

    # Affiche un message de progression pour la création de l'utilisateur.
    print_step "Ajout de l'utilisateur '$username' au système..."

    # Ajoute l'utilisateur au système.
    # 'sudo useradd -m "$username"' : crée l'utilisateur et son répertoire personnel (-m).
    # 'echo "$username:$password" | sudo chpasswd' : définit le mot de passe pour le nouvel utilisateur.
    # '&>/dev/null' redirige toutes les sorties (standard et erreur) vers /dev/null pour les rendre silencieuses.
    if sudo useradd -m "$username" &>/dev/null && echo "$username:$password" | sudo chpasswd &>/dev/null; then
        print_success "L'utilisateur '$username' a été créé avec succès."
        
        # Demande si l'utilisateur souhaite ajouter le nouvel utilisateur au groupe sudo.
        if whiptail --yesno "Voulez-vous ajouter l'utilisateur '$username' au groupe sudo?" 8 60; then
            print_step "Ajout de '$username' au groupe sudo..."
            # Ajoute l'utilisateur au groupe 'sudo'.
            if sudo usermod -aG sudo "$username" &>/dev/null; then
                print_success "L'utilisateur '$username' a été ajouté au groupe sudo."
            else
                print_error "Échec de l'ajout de '$username' au groupe sudo."
                # Note: Ce n'est pas un échec critique pour la création de l'utilisateur, donc on ne retourne pas 1 ici.
            fi
        fi
        return 0 # Retourne 0 pour indiquer le succès.
    else
        print_error "Échec de la création de l'utilisateur '$username'."
        return 1 # Retourne 1 pour indiquer un échec.
    fi
}

# Lance la fonction principale au démarrage du script.
creer_utilisateur