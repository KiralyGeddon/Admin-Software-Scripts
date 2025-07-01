#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source /home/sam/script/TSSR/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: configurer_serveur_dhcp
# Cette fonction permet d'installer et de configurer un serveur DHCP (ISC-DHCP-SERVER).
# Elle propose une configuration de base pour un sous-réseau.
#=============================================================================
configurer_serveur_dhcp() {
    print_step "Configuration d'un serveur DHCP (ISC-DHCP-SERVER)..."

    # Vérifie si le paquet ISC-DHCP-SERVER est installé.
    if ! dpkg -s isc-dhcp-server &>/dev/null; then
        print_step "Le paquet 'isc-dhcp-server' n'est pas installé. Tentative d'installation..."
        if sudo apt update -y &>/dev/null && sudo apt install -y isc-dhcp-server &>/dev/null; then
            print_success "'isc-dhcp-server' a été installé avec succès."
        else
            print_error "Échec de l'installation de 'isc-dhcp-server'. Veuillez l'installer manuellement et relancer le script."
            return 1
        fi
    fi

    # Demande l'interface réseau sur laquelle le serveur DHCP doit écouter.
    local dhcp_interface
    dhcp_interface=$(get_input "Sur quelle interface réseau le serveur DHCP doit-il écouter ? (ex: eth0, enp0s3) :")
    if [[ -z "$dhcp_interface" ]]; then
        print_error "Interface réseau non spécifiée. Annulation."
        return 1
    fi

    # Configure l'interface dans /etc/default/isc-dhcp-server.
    print_step "Configuration de l'interface DHCP dans /etc/default/isc-dhcp-server..."
    if sudo sed -i "s/^INTERFACESv4=\".*\"/INTERFACESv4=\"$dhcp_interface\"/" /etc/default/isc-dhcp-server; then
        print_success "Interface '$dhcp_interface' configurée."
    else
        print_error "Échec de la configuration de l'interface dans /etc/default/isc-dhcp-server."
        return 1
    fi

    # Demande les paramètres du sous-réseau DHCP.
    local subnet
    subnet=$(get_input "Entrez l'adresse du sous-réseau (ex: 192.168.1.0):")
    if [[ -z "$subnet" ]]; then print_error "Sous-réseau vide. Annulation."; return 1; fi

    local netmask
    netmask=$(get_input "Entrez le masque de sous-réseau (ex: 255.255.255.0):")
    if [[ -z "$netmask" ]]; then print_error "Masque de sous-réseau vide. Annulation."; return 1; fi

    local range_start
    range_start=$(get_input "Entrez le début de la plage d'adresses IP (ex: 192.168.1.100):")
    if [[ -z "$range_start" ]]; then print_error "Début de plage vide. Annulation."; return 1; fi

    local range_end
    range_end=$(get_input "Entrez la fin de la plage d'adresses IP (ex: 192.168.1.200):")
    if [[ -z "$range_end" ]]; then print_error "Fin de plage vide. Annulation."; return 1; fi

    local default_gateway
    default_gateway=$(get_input "Entrez l'adresse de la passerelle par défaut (ex: 192.168.1.1):")
    if [[ -z "$default_gateway" ]]; then print_error "Passerelle vide. Annulation."; return 1; fi

    local dns_servers
    dns_servers=$(get_input "Entrez les serveurs DNS (séparés par des virgules, ex: 8.8.8.8,8.8.4.4):")
    if [[ -z "$dns_servers" ]]; then print_error "Serveurs DNS vides. Annulation."; return 1; fi

    local domain_name
    domain_name=$(get_input "Entrez le nom de domaine (ex: mondomaine.local):")
    if [[ -z "$domain_name" ]]; then print_error "Nom de domaine vide. Annulation."; return 1; fi

    local lease_time="600" # Temps de bail par défaut (secondes)
    local max_lease_time="7200" # Temps de bail maximum par défaut (secondes)

    # Création du bloc de configuration pour dhcpd.conf.
    # On commente les exemples existants et ajoute notre configuration.
    local dhcp_config="
# Configuration ajoutée par le script
# ----------------------------------
subnet $subnet netmask $netmask {
    range $range_start $range_end;
    option routers $default_gateway;
    option domain-name-servers $dns_servers;
    option domain-name \"$domain_name\";
    default-lease-time $lease_time;
    max-lease-time $max_lease_time;
}
"

    print_step "Sauvegarde de la configuration DHCP précédente et écriture de la nouvelle..."
    # Sauvegarde du fichier de configuration original.
    if sudo mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak &>/dev/null; then
        print_success "Ancienne configuration sauvegardée sous /etc/dhcp/dhcpd.conf.bak"
    else
        print_warning "Impossible de sauvegarder l'ancienne configuration DHCP. Le fichier n'existe peut-être pas encore ou problème de permissions."
    fi

    # Écrit la nouvelle configuration dans le fichier.
    if echo "$dhcp_config" | sudo tee /etc/dhcp/dhcpd.conf &>/dev/null; then
        print_success "Configuration DHCP écrite dans /etc/dhcp/dhcpd.conf."
    else
        print_error "Échec de l'écriture de la configuration DHCP."
        return 1
    fi

    print_step "Redémarrage du service DHCP..."
    # Redémarre le service DHCP pour appliquer les modifications.
    if sudo systemctl restart isc-dhcp-server &>/dev/null; then
        print_success "Service ISC-DHCP-SERVER redémarré avec succès."
        print_step "Votre serveur DHCP est maintenant configuré sur l'interface '$dhcp_interface'."
        print_step "Assurez-vous que l'interface '$dhcp_interface' a une adresse IP statique dans le même sous-réseau que la plage DHCP."
        return 0
    else
        print_error "Échec du redémarrage du service ISC-DHCP-SERVER. Vérifiez les logs pour plus d'informations (sudo systemctl status isc-dhcp-server)."
        print_error "Assurez-vous que l'interface '$dhcp_interface' est correctement configurée et que le fichier dhcpd.conf ne contient pas d'erreurs de syntaxe."
        return 1
    fi
}

# Lance la fonction au démarrage du script.
configurer_serveur_dhcp