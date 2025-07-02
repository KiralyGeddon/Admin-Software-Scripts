#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }



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
    local ip_address_cidr="$3"  # IP in CIDR format for Netplan
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
    echo "# Fichier généré par le script changeIP.sh pour $interface" | sudo tee "$netplan_file" > /dev/null
    echo "network:" | sudo tee -a "$netplan_file" > /dev/null
    echo "  version: 2" | sudo tee -a "$netplan_file" > /dev/null
    echo "  renderer: networkd" | sudo tee -a "$netplan_file" > /dev/null
    echo "  ethernets:" | sudo tee -a "$netplan_file" > /dev/null
    echo "    $interface:" | sudo tee -a "$netplan_file" > /dev/null

    if [[ "$config_type" == "static" ]]; then
        echo "      dhcp4: no" | sudo tee -a "$netplan_file" > /dev/null
        echo "      addresses: [${ip_address_cidr}]" | sudo tee -a "$netplan_file" > /dev/null
        if [[ -n "$gateway" ]]; then
            echo "      routes:" | sudo tee -a "$netplan_file" > /dev/null
            echo "        - to: default" | sudo tee -a "$netplan_file" > /dev/null
            echo "          via: $gateway" | sudo tee -a "$netplan_file" > /dev/null
        fi
        echo "      nameservers:" | sudo tee -a "$netplan_file" > /dev/null
        echo "        addresses: [8.8.8.8, 8.8.4.4]" | sudo tee -a "$netplan_file" > /dev/null
    elif [[ "$config_type" == "dhcp" ]]; then
        echo "      dhcp4: yes" | sudo tee -a "$netplan_file" > /dev/null
        echo "      addresses: []" | sudo tee -a "$netplan_file" > /dev/null
    fi

    print_step "Validation de la configuration Netplan..."
    if ! sudo netplan try &>/dev/null; then
        print_error "La validation Netplan a échoué. Annulation des changements."
        show_error "La configuration Netplan est invalide. Restauration de l'ancien fichier."
        # Restaurer l'ancien fichier si la validation échoue
        if [ -f "$original_netplan_file" ]; then
            sudo mv "$original_netplan_file" "$netplan_file"
        else
            sudo rm "$netplan_file" # Supprimer le nouveau fichier s'il n'y avait pas d'ancien
        fi
        sudo netplan apply # Tenter d'appliquer l'ancienne configuration ou effacer l'erreur
        return 1
    fi

    print_step "Application de la configuration Netplan..."
    if ! sudo netplan apply &>/dev/null; then
        print_error "Échec de l'application de la configuration Netplan."
        show_error "Impossible d'appliquer la configuration Netplan. Vérifiez les logs système."
        return 1
    fi

    print_success "Configuration Netplan appliquée avec succès."
    return 0
}

# =============================================================================
# Fonction: configure_ifupdown
# Configure une interface réseau de manière persistante avec /etc/network/interfaces.
# =============================================================================
configure_ifupdown() {
    local interface="$1"
    local config_type="$2" # "static" or "dhcp"
    local ip_address="$3"  # Only for static (IP only)
    local netmask="$4"     # Only for static
    local gateway="$5"     # Only for static

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
    /^[[:space:]]*(auto|allow-hotplug)?[[:space:]]+IFACE([[:space:]]|$)/ {
        if ($2 == IFACE || $3 == IFACE) {
            in_interface_block=1
        } else {
            print
            in_interface_block=0
        }
    }
    /^[[:space:]]*iface[[:space:]]+IFACE[[:space:]]+inet/ {
        if ($2 == IFACE) {
            in_interface_block=1
        } else {
            print
            in_interface_block=0
        }
    }
    {
        if (in_interface_block == 0) {
            print
        }
    }' "$interfaces_file" | sudo tee "$interfaces_file.tmp" > /dev/null && sudo mv "$interfaces_file.tmp" "$interfaces_file"

    print_success "Ancienne configuration de '$interface' retirée de '$interfaces_file'."

    # Ajouter la nouvelle configuration
    echo "" | sudo tee -a "$interfaces_file" > /dev/null # Ajouter une ligne vide pour la clarté
    echo "auto $interface" | sudo tee -a "$interfaces_file" > /dev/null
    echo "iface $interface inet $config_type" | sudo tee -a "$interfaces_file" > /dev/null

    if [[ "$config_type" == "static" ]]; then
        echo "address $ip_address" | sudo tee -a "$interfaces_file" > /dev/null
        echo "netmask $netmask" | sudo tee -a "$interfaces_file" > /dev/null
        if [[ -n "$gateway" ]]; then
            echo "gateway $gateway" | sudo tee -a "$interfaces_file" > /dev/null
        fi
        echo "dns-nameservers 8.8.8.8 8.8.4.4" | sudo tee -a "$interfaces_file" > /dev/null
    fi

    print_step "Redémarrage de l'interface '$interface' pour appliquer les changements..."
    # Redémarrer l'interface pour s'assurer que les changements sont appliqués.
    # Utilise 'ip link set' pour down/up, ce qui est plus fiable que ifdown/ifup sur certaines configs.
    if sudo ip link set "$interface" down && sudo ip link set "$interface" up; then
        print_success "Interface '$interface' redémarrée avec succès."
    else
        print_error "Échec du redémarrage de l'interface '$interface'. Veuillez redémarrer le réseau manuellement ou le système."
        show_error "Le redémarrage de l'interface $interface a échoué. Les changements peuvent ne pas être appliqués."
        return 1
    fi

    # Redémarrer le service networking si Ubuntu/Debian avant 18.04
    if [[ "$DISTRO" == "debian" || ("$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION < 18.04" | bc -l)" -eq 1) ]]; then
        print_step "Redémarrage du service networking..."
        if sudo systemctl restart networking; then
            print_success "Service networking redémarré avec succès."
        else
            print_warning "Échec du redémarrage du service networking. Les changements peuvent ne pas être appliqués sans redémarrage."
        fi
    fi

    return 0
}

# =============================================================================
# Fonction: get_interface_current_config
# Affiche la configuration IP actuelle d'une interface spécifique.
# =============================================================================
get_interface_current_config() {
    local interface="$1"
    print_step "Configuration actuelle de l'interface '$interface' :"

    local ip_info=$(ip -4 addr show dev "$interface" | grep inet | awk '{print $2}')
    local gateway_info=$(ip route show default dev "$interface" | awk '{print $3}')
    local dhcp_status=""

    # Vérification heuristique pour DHCP
    if pgrep -f "dhclient.*$interface" > /dev/null; then
        dhcp_status="Actuellement DHCP (dhclient en cours)"
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
# Fonction principale du script changeIP.sh
# Gère le processus de changement d'adresse IP.
# =============================================================================
set_permanent_ip() {
    print_step "Démarrage du processus de changement d'adresse IP (CHANGEMENTS PERMANENTS)..."

    detect_distro # Détecte la distribution et sa version

    # Vérifier et installer ipcalc
    install_package_if_not_exists "ipcalc" || return 1

    local interfaces_list=()
    # Utilise 'ip -o link show' pour obtenir toutes les interfaces, exclut 'lo'
    while IFS= read -r line; do
        local iface_name=$(echo "$line" | awk -F': ' '{print $2}')
        if [[ "$iface_name" != "lo" ]]; then
            # Obtenir l'adresse IP actuelle de l'interface, si disponible
            local current_ip=$(ip -4 addr show dev "$iface_name" | grep inet | awk '{print $2}' | head -n 1)
            if [[ -n "$current_ip" ]]; then
                interfaces_list+=("$iface_name" "($current_ip)")
            else
                interfaces_list+=("$iface_name" "(Pas d'IP)")
            fi
        fi
    done < <(ip -o link show)

    if [ ${#interfaces_list[@]} -eq 0 ]; then
        print_error "Aucune interface réseau détectée pour la configuration."
        show_error "Aucune interface réseau n'a été trouvée."
        return 1
    fi

    print_step "Interfaces réseau et leurs adresses IP actuelles :"
    local chosen_interface=$(whiptail --title "Sélection de l'interface" --menu "Sélectionnez l'interface réseau à configurer :" 20 78 10 "${interfaces_list[@]}" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    print_step "Interface '$chosen_interface' sélectionnée."

    local config_type=$(whiptail --title "Type de Configuration" --menu "Choisissez le type de configuration pour '$chosen_interface' :" 10 60 2 \
        "static" "Configuration Statique (adresse IP fixe)" \
        "dhcp" "Configuration DHCP (dynamique)" 3>&1 1>&2 2>&3)

    if [[ -z "$config_type" ]]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    local action_successful=0 # Flag pour indiquer le succès de l'action de configuration

    if [[ "$config_type" == "static" ]]; then
        local chosen_ip_cidr=$(get_input "Entrez la nouvelle adresse IP en format CIDR (ex: 192.168.1.10/24):")
        if [[ -z "$chosen_ip_cidr" ]]; then
            print_step "Changement d'IP annulé."
            return 1
        fi

        # Extract IP address and calculate netmask
        local ip_address=$(echo "$chosen_ip_cidr" | cut -d'/' -f1)
        local netmask=$(calculate_netmask_from_cidr "$chosen_ip_cidr")
        local gateway=$(get_input "Entrez la passerelle par défaut (laissez vide si pas de passerelle):")

        if [[ -z "$netmask" ]]; then
            print_error "Impossible de calculer le masque de sous-réseau. Veuillez vérifier le format de l'IP/CIDR."
            return 1
        fi

        print_step "Configuration statique: IP=$ip_address, Netmask=$netmask, Gateway=$gateway"

        if [[ "$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION >= 18.04" | bc -l)" -eq 1 ]]; then
            configure_netplan "$chosen_interface" "static" "$chosen_ip_cidr" "$gateway" && action_successful=1
        elif [[ "$DISTRO" == "debian" || ("$DISTRO" == "ubuntu" && "$(echo "$DISTRO_VERSION < 18.04" | bc -l)" -eq 1) ]]; then
            configure_ifupdown "$chosen_interface" "static" "$ip_address" "$netmask" "$gateway" && action_successful=1
        else
            print_error "Distribution non supportée ou non détectée pour la configuration permanente."
            show_error "Impossible de configurer de manière permanente. Distribution non supportée ($DISTRO)."
            return 1
        fi
    elif [[ "$config_type" == "dhcp" ]]; then
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
        if whiptail --yesno "La nouvelle configuration a été appliquée de manière PERMANENTE.\\n\\nÊtes-vous satisfait de cette configuration ?" 12 70; then
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

# Lance la fonction au démarrage du script...
set_permanent_ip