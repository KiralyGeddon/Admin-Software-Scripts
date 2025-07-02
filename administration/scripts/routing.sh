#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }



#=============================================================================
# Fonction: configurer_routage
# Cette fonction permet de configurer le routage IP et la translation d'adresse réseau (NAT)
# pour permettre à un système Linux de fonctionner comme routeur simple.
# Elle active le forwarding IP et configure une règle NAT avec iptables.
#=============================================================================
configurer_routage() {
    print_step "Configuration du routage IP et NAT..."

    local all_interfaces_for_menu=()
    # Utilise 'ip -o link show' pour obtenir toutes les interfaces, exclut 'lo'
    while IFS= read -r line; do
        local iface_name=$(echo "$line" | awk -F': ' '{print $2}')
        if [[ "$iface_name" != "lo" ]]; then
            # Obtenir l'adresse IP actuelle de l'interface, si disponible
            local current_ip=$(ip -4 addr show dev "$iface_name" | grep inet | awk '{print $2}' | head -n 1)
            if [[ -n "$current_ip" ]]; then
                all_interfaces_for_menu+=("$iface_name" "($current_ip)")
            else
                all_interfaces_for_menu+=("$iface_name" "(Pas d'IP)")
            fi
        fi
    done < <(ip -o link show)

    # Vérifier le nombre d'interfaces physiques disponibles (chaque interface utilise 2 éléments dans le tableau)
    if [ ${#all_interfaces_for_menu[@]} -lt 4 ]; then
        print_error "Seule une interface réseau ou aucune interface n'a été détectée."
        show_error "Le routage nécessite au moins DEUX interfaces réseau (une WAN et une LAN). Impossible de continuer."
        return 1
    fi

    print_step "Interfaces réseau disponibles :"
    
    # Sélection de l'interface WAN
    local external_interface
    external_interface=$(whiptail --title "Sélection de l'Interface WAN" --menu "Sélectionnez l'interface connectée à Internet (WAN) :" 20 78 10 "${all_interfaces_for_menu[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        print_step "Configuration du routage annulée."
        return 1
    fi
    print_step "Interface WAN '$external_interface' sélectionnée."

    # Préparer la liste pour la sélection de l'interface LAN (exclure l'interface WAN déjà choisie)
    local internal_interfaces_for_menu=()
    local skip_next=0
    for (( i=0; i<${#all_interfaces_for_menu[@]}; i+=2 )); do
        local name="${all_interfaces_for_menu[i]}"
        local desc="${all_interfaces_for_menu[i+1]}"
        if [[ "$name" != "$external_interface" ]]; then
            internal_interfaces_for_menu+=("$name" "$desc")
        fi
    done

    # Sélection de l'interface LAN
    local internal_interface
    internal_interface=$(whiptail --title "Sélection de l'Interface LAN" --menu "Sélectionnez l'interface connectée au réseau local (LAN) :" 20 78 10 "${internal_interfaces_for_menu[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        print_step "Configuration du routage annulée."
        return 1
    fi
    print_step "Interface LAN '$internal_interface' sélectionnée."


    # 1. Activation du forwarding IP.
    print_step "Activation du forwarding IP..."
    # Modifie /etc/sysctl.conf pour activer le forwarding IP de manière persistante.
    if sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf && \
       sudo sysctl -p &>/dev/null; then # Applique les changements immédiatement.
        print_success "Forwarding IP activé."
    else
        print_error "Échec de l'activation du forwarding IP."
        return 1
    fi

    # 2. Configuration des règles NAT avec iptables.
    print_step "Configuration des règles NAT avec iptables..."
    # Supprime les règles NAT existantes pour éviter les doublons.
    # Note: ceci est une simplification. Une gestion plus robuste des règles serait nécessaire.
    sudo iptables -t nat -F POSTROUTING &>/dev/null

    # Ajoute une règle MASQUERADE pour masquer les adresses IP du réseau interne derrière l'IP de l'interface externe.
    if sudo iptables -t nat -A POSTROUTING -o "$external_interface" -j MASQUERADE &>/dev/null; then
        print_success "Règle NAT (MASQUERADE) ajoutée pour '$external_interface'."
    else
        print_error "Échec de l'ajout de la règle NAT pour '$external_interface'."
        return 1
    fi

    # 3. Sauvegarde des règles iptables pour la persistance au redémarrage.
    # Cela dépend de l'outil utilisé sur la distribution (iptables-persistent, netfilter-persistent).
    print_step "Sauvegarde des règles iptables..."
    if command -v netfilter-persistent &>/dev/null; then
        if sudo netfilter-persistent save &>/dev/null; then
            print_success "Règles iptables sauvegardées via netfilter-persistent."
        else
            print_error "Échec de la sauvegarde des règles iptables avec netfilter-persistent."
        fi
    elif command -v iptables-save &>/dev/null; then
        # Solution plus générique, mais nécessite un mécanisme pour les recharger au démarrage.
        # Par exemple, via un service systemd ou un script dans /etc/rc.local.
        sudo iptables-save | sudo tee /etc/iptables/rules.v4 &>/dev/null # Supposant ce chemin de sauvegarde.
        print_warning "Les règles iptables ont été sauvegardées, mais vous devrez configurer leur rechargement au démarrage (ex: via /etc/rc.local ou systemd)."
        print_warning "Considérez l'installation de 'netfilter-persistent' pour une persistance automatique."
    else
        print_warning "Aucun outil de persistance iptables automatique trouvé (netfilter-persistent ou équivalent). Les règles ne seront pas persistantes après un redémarrage."
        print_warning "Installez 'iptables-persistent' ou 'netfilter-persistent' (sudo apt install iptables-persistent)."
    fi

    print_success "Configuration du routage et NAT terminée. Votre système agit maintenant comme un routeur basique."
    print_step "Assurez-vous que les clients de votre réseau local utilisent l'adresse IP de l'interface '$internal_interface' de ce serveur comme passerelle."
    return 0
}

# Lance la fonction au démarrage du script.
configurer_routage