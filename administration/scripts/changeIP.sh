#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source $HOME/AdminSysTools/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: changer_adresse_ip
# Cette fonction guide l'utilisateur pour changer l'adresse IP d'une interface réseau.
# Elle est simplifiée et peut nécessiter des ajustements pour des configurations réseau complexes
# ou des distributions Linux spécifiques (ex: netplan sur Ubuntu plus récent).
#=============================================================================
changer_adresse_ip() {
    print_step "Changement de l'adresse IP d'une interface réseau..."

    # Récupère la liste des interfaces réseau disponibles.
    # 'ip -o link show' liste les interfaces, puis 'awk' extrait les noms.
    # 'grep -v "lo"' exclut l'interface de bouclage (localhost).
    local interfaces
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | tr '\n' ' ')

    # Vérifie si des interfaces ont été trouvées.
    if [[ -z "$interfaces" ]]; then
        print_error "Aucune interface réseau trouvée (à part 'lo')."
        return 1
    fi

    # Demande à l'utilisateur de choisir une interface.
    local chosen_interface
    chosen_interface=$(whiptail --menu "Choisissez l'interface réseau à configurer :" 15 60 5 $interfaces 3>&1 1>&2 2>&3)

    # Vérifie si l'utilisateur a annulé.
    if [[ -z "$chosen_interface" ]]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    print_step "Configuration de l'interface '$chosen_interface'."

    # Demande le type de configuration (statique ou DHCP).
    local config_type
    config_type=$(whiptail --menu "Choisissez le type de configuration :" 10 60 2 \
        "static" "Adresse IP statique" \
        "dhcp" "Configuration DHCP (dynamique)" 3>&1 1>&2 2>&3)

    if [[ -z "$config_type" ]]; then
        print_step "Changement d'IP annulé."
        return 1
    fi

    if [[ "$config_type" == "static" ]]; then
        local ip_address
        ip_address=$(get_input "Entrez la nouvelle adresse IP (ex: 192.168.1.10/24):")
        if [[ -z "$ip_address" ]]; then
            print_error "Adresse IP vide. Annulation."
            return 1
        fi

        local gateway
        gateway=$(get_input "Entrez l'adresse de la passerelle (optionnel, laissez vide si non nécessaire):")

        print_step "Application de l'adresse IP statique à '$chosen_interface'..."
        # Utilise 'ip addr' pour supprimer l'ancienne adresse et en ajouter une nouvelle.
        # Attention: Cette méthode est temporaire et ne persiste pas après un redémarrage.
        # Pour une persistance, il faut modifier les fichiers de configuration réseau du système (ex: /etc/network/interfaces, netplan).
        if sudo ip addr flush dev "$chosen_interface" &>/dev/null && \
           sudo ip addr add "$ip_address" dev "$chosen_interface" &>/dev/null; then
            print_success "Adresse IP statique '$ip_address' configurée sur '$chosen_interface'."
            if [[ -n "$gateway" ]]; then
                print_step "Ajout de la passerelle par défaut '$gateway'..."
                sudo ip route add default via "$gateway" dev "$chosen_interface" &>/dev/null
                if [ $? -eq 0 ]; then
                    print_success "Passerelle par défaut ajoutée."
                else
                    print_error "Échec de l'ajout de la passerelle par défaut."
                fi
            fi
            # Redémarre l'interface pour s'assurer que les changements sont appliqués.
            sudo ip link set "$chosen_interface" up &>/dev/null
            return 0
        else
            print_error "Échec de la configuration de l'adresse IP statique."
            return 1
        fi
    elif [[ "$config_type" == "dhcp" ]]; then
        print_step "Configuration de '$chosen_interface' en DHCP..."
        # Pour activer DHCP, on supprime les IPs existantes et on relance le client DHCP.
        # Cela peut varier selon la distribution (ex: dhclient, systemd-networkd).
        if sudo ip addr flush dev "$chosen_interface" &>/dev/null && \
           sudo dhclient "$chosen_interface" &>/dev/null; then
            print_success "Interface '$chosen_interface' configurée en DHCP."
            return 0
        else
            print_error "Échec de la configuration DHCP. Assurez-vous que 'dhclient' est installé ou que le service réseau est configuré pour DHCP."
            return 1
        fi
    fi
}

# Lance la fonction au démarrage du script.
changer_adresse_ip