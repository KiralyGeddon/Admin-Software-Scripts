#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Define the log file path. We'll put it in the project root's logs directory.
LOG_DIR="$SCRIPT_DIR/../../logs"
LOG_FILE="$LOG_DIR/AdminSysTools_conf_dhcp.log"

# Create the logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect all stdout and stderr to the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Début de la configuration du serveur DHCP (Kea) - $(date)"
echo "Logs enregistrés dans : $LOG_FILE"
echo "============================================================"

# =============================================================================
# Fonction: uninstall_isc_dhcp_server
# Désinstalle le serveur ISC DHCP s'il est présent.
# =============================================================================
uninstall_isc_dhcp_server() {
    print_step "Vérification et désinstallation de ISC DHCP Server si présent..."
    if dpkg -s isc-dhcp-server &>/dev/null; then
        print_warning "ISC DHCP Server détecté. Désinstallation..."
        if sudo apt-get purge -y isc-dhcp-server &>/dev/null; then
            print_success "ISC DHCP Server désinstallé avec succès."
        else
            print_error "Échec de la désinstallation de ISC DHCP Server."
            return 1
        fi
    else
        print_step "ISC DHCP Server non trouvé, pas de désinstallation nécessaire."
    fi
    return 0
}

# =============================================================================
# Fonction: install_kea_dhcp_server
# Installe le serveur Kea DHCP.
# =============================================================================
install_kea_dhcp_server() {
    print_step "Installation de Kea DHCP Server..."
    # Kea est généralement disponible dans les dépôts par défaut de Debian/Ubuntu récents.
    if ! install_package_if_not_exists "kea-dhcp4-server"; then
        print_error "Échec de l'installation de kea-dhcp4-server."
        return 1
    fi
    print_success "Kea DHCP Server installé avec succès."
    return 0
}

# =============================================================================
# Fonction: configure_kea_dhcp
# Configure le serveur Kea DHCP avec les paramètres fournis.
# =============================================================================
configure_kea_dhcp() {
    local interface="$1"
    local network_cidr="$2" # e.g., 192.168.1.0/24
    local pool_start="$3"   # e.g., 192.168.1.10
    local pool_end="$4"     # e.g., 192.168.1.200
    local gateway="$5"      # e.g., 192.168.1.1
    local dns_servers="$6"  # e.g., 8.8.8.8,8.8.4.4

    print_step "Génération du fichier de configuration Kea DHCP pour l'interface '$interface'..."

    local config_file="/etc/kea/kea-dhcp4.conf"
    local backup_file="${config_file}.bak.$(date +%Y%m%d%H%M%S)"

    # Sauvegarder la configuration existante
    if [ -f "$config_file" ]; then
        print_step "Sauvegarde du fichier de configuration Kea existant: $config_file -> $backup_file"
        sudo cp "$config_file" "$backup_file"
    fi

    # Créer le contenu JSON de la configuration Kea
    # Utilisation d'un here-document pour la clarté
    local kea_json_config=$(cat <<EOF
{
"Dhcp4": {
    "interfaces-config": {
        "interfaces": [ "$interface" ]
    },
    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/tmp/kea4-ctrl-socket"
    },
    "lease-database": {
        "type": "memfile",
        "persist": true,
        "name": "/var/lib/kea/dhcp4.leases"
    },
    "loggers": [
        {
            "name": "kea-dhcp4",
            "output_options": [
                {
                    "output": "stdout"
                }
            ],
            "severity": "INFO"
        }
    ],
    "subnet4": [
        {
            "subnet": "$network_cidr",
            "pools": [ { "pool": "$pool_start - $pool_end" } ],
            "option-data": [
                {
                    "name": "routers",
                    "data": "$gateway"
                },
                {
                    "name": "domain-name-servers",
                    "data": "$dns_servers"
                }
            ],
            "valid-lifetime": 4000
        }
    ]
}
}
EOF
)
    # Écrire la configuration dans le fichier
    echo "$kea_json_config" | sudo tee "$config_file" > /dev/null

    # Valider la configuration JSON
    print_step "Validation de la configuration Kea DHCP..."
    if ! sudo kea-dhcp4 -t "$config_file" &>/dev/null; then
        print_error "La configuration Kea DHCP est invalide. Restauration de l'ancien fichier."
        show_error "La configuration Kea DHCP est invalide. Vérifiez le fichier de log pour les erreurs."
        if [ -f "$backup_file" ]; then
            sudo mv "$backup_file" "$config_file"
        fi
        return 1
    fi

    print_success "Configuration Kea DHCP générée et validée avec succès."

    # Redémarrer et activer le service Kea DHCP
    print_step "Redémarrage et activation du service Kea DHCP..."
    if sudo systemctl enable kea-dhcp4-server &>/dev/null && \
       sudo systemctl restart kea-dhcp4-server &>/dev/null; then
        print_success "Service Kea DHCP redémarré et activé avec succès."
    else
        print_error "Échec du redémarrage ou de l'activation du service Kea DHCP."
        show_error "Le service Kea DHCP n'a pas pu démarrer. Vérifiez les logs système."
        return 1
    fi

    return 0
}

# =============================================================================
# Fonction principale pour la configuration DHCP
# =============================================================================
configure_dhcp_server() {
    print_step "Démarrage de la configuration du serveur DHCP..."

    # 1. Désinstaller ISC DHCP si présent
    uninstall_isc_dhcp_server || { show_error "Impossible de désinstaller ISC DHCP. Annulation."; exit 1; }

    # 2. Installer Kea DHCP
    install_kea_dhcp_server || { show_error "Impossible d'installer Kea DHCP. Annulation."; exit 1; }

    # 3. Sélection de l'interface d'écoute
    local interfaces_list=()
    while IFS= read -r line; do
        local iface_name=$(echo "$line" | awk -F': ' '{print $2}')
        if [[ "$iface_name" != "lo" ]]; then
            local current_ip=$(ip -4 addr show dev "$iface_name" | grep inet | awk '{print $2}' | head -n 1)
            if [[ -n "$current_ip" ]]; then
                interfaces_list+=("$iface_name" "($current_ip)")
            else
                interfaces_list+=("$iface_name" "(Pas d'IP)")
            fi
        fi
    done < <(ip -o link show)

    if [ ${#interfaces_list[@]} -eq 0 ]; then
        print_error "Aucune interface réseau détectée pour la configuration DHCP."
        show_error "Aucune interface réseau n'a été trouvée. Impossible de configurer le serveur DHCP."
        return 1
    fi

    print_step "Interfaces réseau disponibles :"
    local chosen_interface=$(whiptail --title "Sélection de l'Interface DHCP" --menu "Sélectionnez l'interface sur laquelle le serveur DHCP doit écouter :" 20 78 10 "${interfaces_list[@]}" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        print_step "Configuration DHCP annulée par l'utilisateur."
        return 1
    fi

    print_step "Interface '$chosen_interface' sélectionnée pour l'écoute DHCP."

    # 4. Demander les paramètres réseau à l'utilisateur
    local network_cidr=$(get_input "Entrez l'adresse réseau en format CIDR (ex: 192.168.1.0/24):")
    if [[ -z "$network_cidr" ]]; then
        print_step "Configuration DHCP annulée: Adresse réseau manquante."
        return 1
    fi

    local pool_start=$(get_input "Entrez l'adresse IP de début de la plage DHCP (ex: 192.168.1.10):")
    if [[ -z "$pool_start" ]]; then
        print_step "Configuration DHCP annulée: Début de plage DHCP manquant."
        return 1
    fi

    local pool_end=$(get_input "Entrez l'adresse IP de fin de la plage DHCP (ex: 192.168.1.200):")
    if [[ -z "$pool_end" ]]; then
        print_step "Configuration DHCP annulée: Fin de plage DHCP manquante."
        return 1
    fi

    local gateway=$(get_input "Entrez l'adresse IP de la passerelle par défaut pour ce réseau (ex: 192.168.1.1):")
    if [[ -z "$gateway" ]]; then
        print_step "Configuration DHCP annulée: Passerelle manquante."
        return 1
    fi

    local dns_servers=$(get_input "Entrez les adresses IP des serveurs DNS (séparées par des virgules, ex: 8.8.8.8,8.8.4.4):")
    if [[ -z "$dns_servers" ]]; then
        print_step "Configuration DHCP annulée: Serveurs DNS manquants."
        return 1
    fi

    # 5. Configurer Kea DHCP
    if configure_kea_dhcp "$chosen_interface" "$network_cidr" "$pool_start" "$pool_end" "$gateway" "$dns_servers"; then
        print_success "Serveur DHCP (Kea) configuré et démarré avec succès sur '$chosen_interface'."
        whiptail --title "Configuration DHCP Terminée" --msgbox "\
Le serveur DHCP (Kea) a été configuré et démarré avec succès sur l'interface '$chosen_interface'.

Détails de la configuration :
Réseau : $network_cidr
Plage IP : $pool_start - $pool_end
Passerelle : $gateway
DNS : $dns_servers

Veuillez vérifier les logs pour plus de détails :
$LOG_FILE
" 20 80
        return 0
    else
        print_error "Échec de la configuration du serveur DHCP (Kea)."
        show_error "La configuration du serveur DHCP (Kea) a échoué. Vérifiez le fichier de log pour les erreurs :\\n$LOG_FILE"
        return 1
    fi
}

# Lance la fonction au démarrage du script.
configure_dhcp_server