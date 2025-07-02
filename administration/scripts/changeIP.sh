#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source ../librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# =============================================================================
# Fonction: detect_distro
# Détecte la distribution Linux (Debian ou Ubuntu) et sa version.
# Définit DISTRO et DISTRO_VERSION.
# =============================================================================
detect_distro() {
    DISTRO="unknown"
    DISTRO_VERSION="unknown"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=${ID_LIKE:-$ID}
        DISTRO_VERSION=${VERSION_ID}
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        # Extract major version, e.g., "12" from "12.0.0"
        DISTRO_VERSION=$(cat /etc/debian_version | cut -d'.' -f1)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=${DISTRIB_ID}
        DISTRO_VERSION=${DISTRIB_RELEASE}
    fi

    DISTRO=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    print_step "Distribution détectée: $DISTRO, Version: $DISTRO_VERSION"
}

# =============================================================================
# Fonction: configure_netplan
# Configure une interface réseau de manière persistante avec Netplan.
# =============================================================================
configure_netplan() {
    local interface="$1"
    local config_type="$2" # "static" or "dhcp"
    local ip_address="$3"  # Only for static
    local gateway="$4"     # Only for static

    print_step "Configuration de l'interface '$interface' avec Netplan (persistante)..."

    local netplan_dir="/etc/netplan"
    local netplan_file="${netplan_dir}/99-config-${interface}.yaml"
    local original_netplan_file="${netplan_file}.bak.$(date +%Y%m%d%H%M%S)"

    # Vérifier si Netplan est installé
    if ! command -v netplan &> /dev/null; then
        print_error "Netplan n'est pas installé ou trouvé. Impossible de configurer Netplan."
        show_error "Netplan n'est pas trouvé. Assurez-vous qu'il est installé sur votre système Ubuntu."
        return 1
    fi

    # Sauvegarder les fichiers Netplan existants
    mkdir -p "$netplan_dir"
    if [ -f "$netplan_file" ]; then
        print_step "Sauvegarde du fichier Netplan existant: $netplan_file -> $original_netplan_file"
        sudo mv "$netplan_file" "$original_netplan_file"
    fi

    # Créer le nouveau fichier de configuration Netplan
    # Utilisation de tee pour écrire avec sudo
    echo "# Fichier généré par le script changeIP.sh pour $interface" | sudo tee "$netplan_file" > /dev/null
    echo "network:" | sudo tee -a "$netplan_file" > /dev/null
    echo "  version: 2" | sudo tee -a "$netplan_file" > /dev/null
    echo "  renderer: networkd" | sudo tee -a "$netplan_file" > /dev/null
    echo "  ethernets:" | sudo tee -a "$netplan_file" > /dev/null
    echo "    $interface:" | sudo tee -a "$netplan_file" > /dev/null

    if [[ "$config_type" == "static" ]]; then
        echo "      dhcp4: no" | sudo tee -a "$netplan_file" > /dev/null
        echo "      addresses: [${ip_address}]" | sudo tee -a "$netplan_file" > /dev/null
        if [[ -n "$gateway" ]]; then
            echo "      routes:" | sudo tee -a "$netplan_file" > /dev/null
            echo "        - to: default" | sudo tee -a "$netplan_file" > /dev/null
            echo "          via: $gateway" | sudo tee -a "$netplan_file" > /dev/null
        fi
        # Ajouter une configuration DNS basique, peut être améliorée
        echo "      nameservers:" | sudo tee -a "$netplan_file" > /dev/null
        echo "        addresses: [8.8.8.8, 8.8.4.4]" | sudo tee -a "$netplan_file" > /dev/null
    elif [[ "$config_type" == "dhcp" ]]; then
        echo "      dhcp4: yes" | sudo tee -a "$netplan_file" > /dev/null
        # Assurez-vous qu'il n'y a pas d'adresses statiques conflictuelles
        echo "      addresses: []" | sudo tee -a "$netplan_file" > /dev/null
    fi

    print_step "Validation de la configuration Netplan..."
    if ! sudo netplan try &>/dev/null; then # Use netplan try for safe validation
        print_error "La configuration Netplan est invalide. Restauration du fichier précédent."
        show_error "La configuration Netplan pour '$interface' est invalide. Veuillez vérifier le formatage."
        # Restaurer l'ancien fichier si 'netplan try' échoue
        if [ -f "$original_netplan_file" ]; then
            sudo mv "$original_netplan_file" "$netplan_file"
            print_success "Fichier Netplan restauré."
        else
            print_error "Aucun fichier Netplan précédent à restaurer. Le fichier '$netplan_file' peut être vide ou incorrect."
        fi
        return 1
    fi

    print_step "Application de la configuration Netplan..."
    if sudo netplan apply &>/dev/null; then
        print_success "Configuration Netplan appliquée avec succès pour '$interface'."
        return 0
    else
        print_error "Échec de l'application de la configuration Netplan."
        show_error "Échec de l'application de la configuration Netplan pour '$interface'. Vérifiez les logs Netplan."
        # Si apply échoue, on peut essayer de restaurer, mais try aurait déjà dû le détecter
        if [ -f "$original_netplan_file" ]; then
            sudo mv "$original_netplan_file" "$netplan_file"
            sudo netplan apply &>/dev/null # Re-apply the old one
            print_error "Tentative de restauration de la configuration Netplan précédente."
        fi
        return 1
    fi
}

# =============================================================================
# Fonction: configure_ifupdown
# Configure une interface réseau de manière persistante avec /etc/network/interfaces.
# =============================================================================
configure_ifupdown() {
    local interface="$1"
    local config_type="$2" # "static" or "dhcp"
    local ip_address="$3"  # Only for static
    local gateway="$4"     # Only for static

    print_step "Configuration de l'interface '$interface' avec /etc/network/interfaces (persistante)..."

    local interfaces_file="/etc/network/interfaces"
    local original_interfaces_file="${interfaces_file}.bak.$(date +%Y%m%d%H%M%S)"

    # Sauvegarder le fichier interfaces existant
    if [ -f "$interfaces_file" ]; then
        print_step "Sauvegarde du fichier interfaces existant: $interfaces_file -> $original_interfaces_file"
        sudo cp "$interfaces_file" "$original_interfaces_file"
    else
        print_error "Le fichier $interfaces_file n'existe pas. Création..."
        sudo touch "$interfaces_file"
    fi

    # Supprimer les anciennes configurations de l'interface spécifique
    # Utilise awk pour reconstruire le fichier sans les lignes concernant l'interface
    # IMPORTANT: Utilisation de sudo tee pour la redirection afin de gérer les permissions.
    sudo awk -v IFACE="$interface" '
        BEGIN { in_interface_block=0 }
        /^[[:space:]]*auto[[:space:]]+IFACE\b/ {
            if ($2 == IFACE) { in_interface_block=1; next } # Skip this line
        }
        /^[[:space:]]*iface[[:space:]]+IFACE\b/ {
            if ($2 == IFACE) { in_interface_block=1; next } # Skip this line
        }
        /^[[:space:]]*iface / { # Start of a new iface block
            if ($2 != IFACE) { in_interface_block=0 } # Not our interface block
        }
        !in_interface_block { print }
    ' "$interfaces_file" | sudo tee "${interfaces_file}.tmp" > /dev/null

    # Déplacer le fichier temporaire écrasé avec sudo
    if sudo mv "${interfaces_file}.tmp" "$interfaces_file"; then
        print_success "Ancienne configuration de '$interface' retirée de '$interfaces_file'."
    else
        print_error "Échec de la suppression de l'ancienne configuration ou du déplacement du fichier temporaire."
        show_error "Échec de l'édition de $interfaces_file. Vérifiez les permissions et l'espace disque."
        return 1
    fi


    # Ajouter la nouvelle configuration
    echo "" | sudo tee -a "$interfaces_file" > /dev/null # Nouvelle ligne pour la propreté
    echo "auto $interface" | sudo tee -a "$interfaces_file" > /dev/null

    if [[ "$config_type" == "static" ]]; then
        echo "iface $interface inet static" | sudo tee -a "$interfaces_file" > /dev/null
        echo "    address $(echo "$ip_address" | cut -d'/' -f1)" | sudo tee -a "$interfaces_file" > /dev/null

        # Calculer le netmask en utilisant ipcalc
        if ! command -v ipcalc &> /dev/null; then
            print_error "Le paquet 'ipcalc' n'est pas installé. Nécessaire pour calculer le masque de sous-réseau."
            show_error "Le paquet 'ipcalc' est nécessaire pour la configuration statique. Veuillez l'installer."
            return 1
        fi
        local netmask=$(ipcalc -nm "$ip_address" | awk -F'=' '/Netmask:/ {print $2}')
        if [[ -n "$netmask" ]]; then
            echo "    netmask $netmask" | sudo tee -a "$interfaces_file" > /dev/null
        else
            print_error "Impossible de calculer le masque de sous-réseau pour '$ip_address'."
            show_error "Impossible de calculer le masque de sous-réseau. Vérifiez le format de l'IP/CIDR."
            return 1
        fi

        if [[ -n "$gateway" ]]; then
            echo "    gateway $gateway" | sudo tee -a "$interfaces_file" > /dev/null
        fi
        # Ajouter une configuration DNS basique
        echo "    dns-nameservers 8.8.8.8 8.8.4.4" | sudo tee -a "$interfaces_file" > /dev/null
    elif [[ "$config_type" == "dhcp" ]]; then
        echo "iface $interface inet dhcp" | sudo tee -a "$interfaces_file" > /dev/null
    fi

    print_step "Redémarrage de l'interface '$interface' pour appliquer les changements..."
    # Redémarrer l'interface pour s'assurer que les changements sont appliqués.
    # Ceci est critique pour ifupdown
    if sudo ifdown "$interface" &>/dev/null && sudo ifup "$interface" &>/dev/null; then
        print_success "Interface '$interface' configurée avec succès via /etc/network/interfaces."
        return 0
    else
        print_error "Échec de l'application de la configuration via /etc/network/interfaces. Vérifiez les logs."
        show_error "Échec de l'application de la configuration via /etc/network/interfaces. Restaurez le fichier original si nécessaire."
        # Restaurer l'ancien fichier si l'application échoue
        if [ -f "$original_interfaces_file" ]; then
            sudo cp "$original_interfaces_file" "$interfaces_file"
            print_error "Fichier /etc/network/interfaces restauré."
        fi
        return 1
    fi
}

# =============================================================================
# Fonction: afficher_interfaces_et_ip
# Affiche les interfaces réseau disponibles et leurs adresses IP actuelles.
# =============================================================================
afficher_interfaces_et_ip() {
    print_step "Interfaces réseau et leurs adresses IP actuelles :"
    local interfaces_info
    # Utilisez grep -E pour une regex étendue pour filtrer 'lo' plus proprement
    interfaces_info=$(ip -o -4 addr show | awk '{print $2 ": " $4}' | grep -E -v '^lo:')

    if [[ -z "$interfaces_info" ]]; then
        print_error "Aucune interface réseau avec adresse IPv4 trouvée."
        whiptail --title "Aucune Interface Réseau" --msgbox "Aucune interface réseau avec adresse IPv4 n'a été trouvée (à part 'lo')." 10 70
        return 1
    fi

    local formatted_info=""
    while IFS= read -r line; do
        formatted_info+="$line\n"
    done <<< "$interfaces_info"

    whiptail --title "Informations Réseau Actuelles" --msgbox "$formatted_info" 20 70
    return 0
}

# =============================================================================
# Fonction: get_interface_current_config
# Récupère et affiche la configuration actuelle d'une interface.
# =============================================================================
get_interface_current_config() {
    local interface="$1"
    print_step "Récupération de la configuration actuelle pour '$interface'..."

    local ip_info=$(ip -o -4 addr show dev "$interface" | awk '{print $4}' | head -n 1) # Prendre la première IP si plusieurs
    local gateway_info=$(ip route show default dev "$interface" | awk '{print $3}' | head -n 1) # Prendre la première passerelle

    local dhcp_status="Non déterminé"
    # Vérifier si un processus dhclient est en cours pour cette interface
    if pgrep -f "dhclient.*$interface" &>/dev/null; then
        dhcp_status="Probablement DHCP (dhclient en cours)"
    elif [[ -z "$ip_info" ]] && [[ -z "$gateway_info" ]]; then
        dhcp_status="Potentiellement DHCP (pas d'IP/Passerelle statique détectée)"
    else
        dhcp_status="Probablement Statique (ou DHCP sans dhclient actif directement)"
    fi


    local config_display="Interface: $interface\n"
    config_display+="Adresse IP/CIDR: ${ip_info:-Aucune}\n"
    config_display+="Passerelle: ${gateway_info:-Aucune}\n"
    config_display+="Statut DHCP: $dhcp_status\n"

    whiptail --title "Configuration Actuelle de $interface" --msgbox "$config_display" 15 70
}


# =============================================================================
# Fonction: changer_adresse_ip
# Cette fonction guide l'utilisateur pour changer l'adresse IP d'une interface réseau.
# Les changements sont permanents en modifiant les fichiers de configuration système.
# =============================================================================
changer_adresse_ip() {
    print_step "Démarrage du processus de changement d'adresse IP (CHANGEMENTS PERMANENTS)..."

    detect_distro # Détecte la distribution au début

    # Installe ipcalc si la distribution est Debian/Ubuntu (nécessaire pour le netmask statique)
    if [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" ]]; then
        install_package_if_not_exists "ipcalc" || { print_error "Impossible d'installer ipcalc. La configuration statique pourrait échouer."; return 1; }
    fi


    # 1. Afficher les interfaces réseau et leurs IP
    afficher_interfaces_et_ip || { print_error "Impossible d'afficher les interfaces réseau."; return 1; }

    # Demander si l'utilisateur souhaite changer une IP
    if ! whiptail --yesno "Souhaitez-vous changer une adresse IP de manière PERMANENTE ?\nSoyez prudent, cette opération modifie les fichiers de configuration système." 12 75; then
        print_step "Opération de changement d'IP annulée par l'utilisateur."
        return 0
    fi

    print_step "Sélection de l'interface réseau à configurer..."

    # Récupère la liste des interfaces réseau disponibles.
    local interfaces_raw
    interfaces_raw=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")

    local menu_options=()
    if [[ -z "$interfaces_raw" ]]; then
        print_error "Aucune interface réseau trouvée (à part 'lo')."
        show_error "Aucune interface réseau à configurer."
        return 1
    fi

    # Formatte pour whiptail --menu (tag item)
    while IFS= read -r interface_name; do
        menu_options+=("$interface_name" "Interface réseau")
    done <<< "$interfaces_raw"

    local chosen_interface
    # Convertir le tableau en liste d'arguments pour whiptail
    chosen_interface=$(whiptail --menu "Choisissez l'interface réseau à configurer :" 15 60 5 "${menu_options[@]}" 3>&1 1>&2 2>&3)

    # Vérifie si l'utilisateur a annulé.
    if [[ -z "$chosen_interface" ]]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    print_step "Interface '$chosen_interface' sélectionnée."

    # Demande le type de configuration (statique ou DHCP).
    local config_type
    config_type=$(whiptail --menu "Choisissez le type de configuration pour '$chosen_interface' :" 10 60 2 \
        "static" "Adresse IP statique" \
        "dhcp" "Configuration DHCP (dynamique)" 3>&1 1>&2 2>&3)

    if [[ -z "$config_type" ]]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    local action_successful=0 # Flag pour indiquer si l'action a réussi

    if [[ "$config_type" == "static" ]]; then
        local ip_address
        ip_address=$(get_input "Entrez la nouvelle adresse IP/CIDR pour '$chosen_interface' (ex: 192.168.1.10/24):")
        if [[ -z "$ip_address" ]]; then
            print_error "Adresse IP vide. Annulation."
            show_error "L'adresse IP ne peut pas être vide pour une configuration statique."
            return 1
        fi

        # Simple validation d'IP/CIDR (peut être améliorée)
        if ! [[ "$ip_address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            print_error "Format d'adresse IP/CIDR invalide. Annulation."
            show_error "Format d'adresse IP/CIDR invalide. Utilisez le format XXX.XXX.XXX.XXX/YY."
            return 1
        fi

        local gateway
        gateway=$(get_input "Entrez l'adresse de la passerelle pour '$chosen_interface' (optionnel, laissez vide si non nécessaire):")

        # Appeler la fonction de configuration persistante appropriée
        if [[ "$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION >= 18.04" | bc -l)" -eq 1 ]]; then
            configure_netplan "$chosen_interface" "static" "$ip_address" "$gateway" && action_successful=1
        elif [[ "$DISTRO" == "debian" || ("$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION < 18.04" | bc -l)" -eq 1) ]]; then
            configure_ifupdown "$chosen_interface" "static" "$ip_address" "$gateway" && action_successful=1
        else
            print_error "Distribution non supportée ou non détectée pour la configuration permanente."
            show_error "Impossible de configurer de manière permanente. Distribution non supportée ($DISTRO)."
            return 1
        fi

    elif [[ "$config_type" == "dhcp" ]]; then
        # Appeler la fonction de configuration persistante appropriée
        if [[ "$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION >= 18.04" | bc -l)" -eq 1 ]]; then
            configure_netplan "$chosen_interface" "dhcp" && action_successful=1
        elif [[ "$DISTRO" == "debian" || ("$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION < 18.04" | bc -l)" -eq 1) ]]; then
            configure_ifupdown "$chosen_interface" "dhcp" && action_successful=1
        else
            print_error "Distribution non supportée ou non détectée pour la configuration permanente."
            show_error "Impossible de configurer de manière permanente. Distribution non supportée ($DISTRO)."
            return 1
        fi
    fi

    # 3. Afficher la nouvelle configuration si l'action a réussi
    if [[ "$action_successful" -eq 1 ]]; then
        get_interface_current_config "$chosen_interface"

        # 4. Demander si ça nous convient - avec un avertissement permanent
        if whiptail --yesno "La nouvelle configuration a été appliquée de manière PERMANENTE.\n\nÊtes-vous satisfait de cette configuration ?" 12 70; then
            print_success "Configuration permanente appliquée avec succès."
            return 0
        else
            print_error "L'utilisateur n'est pas satisfait. La configuration est PERMANENTE. Vous devrez la modifier manuellement si nécessaire."
            return 1
        fi
    else
        print_error "Aucune configuration permanente appliquée en raison d'erreurs précédentes."
        return 1
    fi
}

# Lance la fonction au démarrage du script.
changer_adresse_ip