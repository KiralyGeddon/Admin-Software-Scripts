#!/bin/bash

# =============================================================================
# Bibliothèque de fonctions et variables partagées
# Ce fichier centralise les éléments communs pour les scripts du projet.
# À inclure avec : source ./lib.sh
# =============================================================================

# --- Variables de couleur ---
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# --- Fonctions d'affichage ---
print_step() { echo -e "${CYAN}${BOLD}➤ $1${RESET}"; }
print_success() { echo -e "${GREEN}✓ $1${RESET}"; }
print_error() { echo -e "${RED}✗ Erreur: $1${RESET}" >&2; }

# --- Fonctions d'interface utilisateur (whiptail) ---

# Affiche une barre de progression
# Arguments:
#   $1: message à afficher
#   $2: durée en secondes (si pas de PID)
#   $3: PID du processus à surveiller (optionnel)
progress_bar() {
    local message="$1"
    local duration="${2:-3}" # Default duration is 3 seconds
    local pid_to_monitor="$3" # Optional PID

    local current_progress=0

    { # Start of a command block whose output is redirected to whiptail.
        if [[ -n "$pid_to_monitor" ]]; then
            # Monitor the PID
            while ps -p "$pid_to_monitor" > /dev/null; do
                # Increment progress, but don't exceed 99% until process actually finishes
                current_progress=$((current_progress + 5))
                if (( current_progress > 95 )); then
                    current_progress=95 # Cap at 95% while still running
                fi
                echo "$current_progress"
                sleep 0.5 # Check every 0.5 seconds
            done
            echo "100" # Set to 100% once the process finishes
        else
            # Fixed duration progress bar
            for ((i = 0 ; i <= 100 ; i+=10)); do
                echo "$i"
                sleep "$(bc <<< "scale=2; $duration / 10")"
            done
            echo "100"
        fi
    } | whiptail --gauge "$message" 6 70 0
}


# --- Fonctions Réseau ---

# Vérifie la connectivité Internet en tentant de pinger Google.
check_internet_connectivity() {
    print_step "Vérification de la connectivité Internet..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Connectivité Internet établie."
        return 0
    else
        print_error "Pas de connectivité Internet. Veuillez vérifier votre connexion."
        show_error "Impossible d'établir une connexion Internet."
        return 1
    fi
}

# Fonction pour obtenir l'adresse IP locale de la machine
get_local_ip() {
    # Tente d'obtenir l'IP via hostname -I (plus simple)
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Si hostname -I échoue, essaie avec ip a
    ip=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Dernière tentative avec ifconfig si disponible (déprécié mais utile)
    ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    print_warning "Impossible de déterminer l'adresse IP locale. Veuillez la renseigner manuellement si nécessaire."
    echo "INCONNUE"
    return 1
}

# --- Fonctions de Gestion de Paquets ---

# Vérifie si un paquet est installé et l'installe si nécessaire (pour Debian/Ubuntu).
install_package_if_not_exists() {
    local package_name="$1"
    print_step "Vérification et installation du paquet : $package_name"
    if ! dpkg -s "$package_name" &> /dev/null; then
        echo -e "${YELLOW}Le paquet '$package_name' n'est pas installé. Tentative d'installation...${RESET}"
        if [[ "$(whoami)" == "root" ]]; then
            if ! apt install -y "$package_name" -qq > /dev/null 2>&1; then
                print_error "Échec de l'installation du paquet : $package_name."
                return 1
            fi
        else
            if ! sudo apt install -y "$package_name" -qq > /dev/null 2>&1; then
                print_error "Échec de l'installation du paquet : $package_name."
                return 1
            fi
        fi
        print_success "Le paquet '$package_name' a été installé avec succès."
    else
        print_success "Le paquet '$package_name' est déjà installé."
    fi
    return 0
}

# --- Fonctions Docker ---

# Vérifie si un conteneur Docker existe.
check_docker_container_exists() {
    local container_name="$1"
    if docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; then
        return 0 # Conteneur existe
    else
        return 1 # Conteneur n'existe pas
    fi
}

# Vérifie si un conteneur Docker est en cours d'exécution.
check_docker_container_running() {
    local container_name="$1"
    if docker ps --format '{{.Names}}' | grep -wq "$container_name"; then
        return 0 # Conteneur est en cours d'exécution
    else
        return 1 # Conteneur n'est pas en cours d'exécution
    fi
}

# Arrête et supprime un conteneur Docker.
stop_and_remove_docker_container() {
    local container_name="$1"
    if check_docker_container_exists "$container_name"; then
        print_step "Arrêt et suppression du conteneur Docker : $container_name..."
        if docker stop "$container_name" > /dev/null 2>&1 && docker rm "$container_name" > /dev/null 2>&1; then
            print_success "Conteneur '$container_name' arrêté et supprimé."
            return 0
        else
            print_error "Échec de l'arrêt ou de la suppression du conteneur '$container_name'."
            return 1
        fi
    else
        print_success "Le conteneur '$container_name' n'existe pas, aucune action requise."
        return 0
    fi
}

# Fonction d'affichage d'erreurs avec une boîte de dialogue whiptail.
# Affiche un message d'erreur et met en pause l'exécution jusqu'à ce que l'utilisateur appuie sur OK.
show_error() {
    local error_message="$1" # Récupère le message d'erreur passé en argument.
    echo -e "${RED}✗ Erreur: $error_message${RESET}" >&2 # Affiche l'erreur dans le terminal.
    # Affiche une boîte de message whiptail avec le message d'erreur.
    whiptail --title "Erreur" --msgbox "Une erreur est survenue : $error_message\n\nAppuyez sur OK pour revenir au menu." 12 70
}

# Fonction pour afficher une erreur et demander à l'utilisateur de continuer (avant de retourner au menu).
# Utilisée lorsque l'erreur n'est pas bloquante pour l'ensemble du script mais empêche l'opération courante.
show_error_and_return_to_menu() {
    local error_message="$1" # Récupère le message d'erreur.
    print_error "$error_message" # Affiche l'erreur dans le terminal.
    # Affiche une boîte de message whiptail.
    whiptail --title "Erreur" --msgbox "Une erreur est survenue : $error_message\n\nAppuyez sur OK pour continuer." 12 70
    return 1 # Indique une erreur pour que le script appelant puisse réagir.
}

# Fonction pour vérifier et installer whiptail.
# Whiptail est un outil qui permet de créer des boîtes de dialogue interactives dans le terminal.
check_whiptail() {
    # Vérifie si la commande whiptail existe.
    if ! command -v whiptail &> /dev/null; then
        echo -e "${YELLOW}Whiptail n'est pas installé. Tentative d'installation...${RESET}"
        # Tente de mettre à jour les dépôts APT (gestionnaire de paquets de Debian/Ubuntu).
        if ! sudo apt update -qq > /dev/null 2>&1; then
             show_error "Échec de la mise à jour des dépôts APT avant l'installation de whiptail."
             return 1 # Retourne 1 pour indiquer un échec.
        fi
        # Tente d'installer whiptail.
        if ! sudo apt install -y whiptail -qq > /dev/null 2>&1; then
            show_error "Échec de l'installation de whiptail. Le menu ne peut pas fonctionner sans lui."
            return 1 # Retourne 1 pour indiquer un échec.
        else
            echo -e "${GREEN}Whiptail installé avec succès.${RESET}"
        fi
    fi
    return 0 # Retourne 0 pour indiquer un succès.
}

# --- Fonctions ajoutées pour la saisie utilisateur ---

# Fonction pour obtenir une entrée utilisateur avec whiptail.
get_input() {
    local prompt_message="$1"
    local input_value
    input_value=$(whiptail --inputbox "$prompt_message" 8 78 3>&1 1>&2 2>&3)
    echo "$input_value"
}

# Fonction pour obtenir un mot de passe utilisateur avec whiptail (masqué).
get_input_password() {
    local prompt_message="$1"
    local password_value
    password_value=$(whiptail --passwordbox "$prompt_message" 8 78 3>&1 1>&2 2>&3)
    echo "$password_value"
}