#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Ajout de la fonction print_warning manquante dans lib.sh si vous ne l'avez pas déjà fait
# Note: Idéalement, cette fonction devrait être dans lib.sh.
# Si vous avez déjà mis à jour lib.sh avec cette fonction, cette partie est redondante.
# Cependant, je la laisse ici pour s'assurer que le script fonctionne même si lib.sh n'est pas encore mis à jour.
if ! command -v print_warning &>/dev/null; then
    print_warning() { echo -e "${YELLOW}⚠️ Avertissement: $1${RESET}"; }
fi


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
    if [ ${#all_interfaces_for_menu[@]} -lt 4 ]; then # Moins de 4 éléments = moins de 2 interfaces réelles
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
    for (( i=0; i<${#all_interfaces_for_menu[@]}; i+=2 )); do
        local name="${all_interfaces_for_menu[i]}"
        local desc="${all_interfaces_for_menu[i+1]}"
        if [[ "$name" != "$external_interface" ]]; then
            internal_interfaces_for_menu+=("$name" "$desc")
        fi
    done

    # Vérifier s'il reste au moins une interface pour la LAN
    if [ ${#internal_interfaces_for_menu[@]} -eq 0 ]; then
        print_error "Après la sélection de l'interface WAN, aucune autre interface n'est disponible pour le LAN."
        show_error "Impossible de configurer le routage car il n'y a pas d'interface distincte pour le LAN."
        return 1
    fi

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
    # Utilise sed pour décommenter ou ajouter la ligne.
    if ! sudo grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        if sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf; then
            print_step "Ligne 'net.ipv4.ip_forward=1' décommentée dans /etc/sysctl.conf."
        else
            echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
            print_step "Ligne 'net.ipv4.ip_forward=1' ajoutée à /etc/sysctl.conf."
        fi
    else
        print_step "Forwarding IP déjà configuré dans /etc/sysctl.conf."
    fi

    if sudo sysctl -p &>/dev/null; then # Applique les changements immédiatement.
        print_success "Forwarding IP activé."
    else
        print_error "Échec de l'activation du forwarding IP. Vérifiez les logs."
        return 1
    fi

    # 2. Configuration des règles NAT avec iptables.
    print_step "Configuration des règles NAT avec iptables..."
    # Supprime les règles NAT existantes pour éviter les doublons pour la même interface de sortie.
    # Ceci est une approche plus sûre que de flusher toute la chaîne POSTROUTING.
    print_step "Suppression des règles NAT MASQUERADE existantes pour '$external_interface'..."
    local rule_exists=$(sudo iptables -t nat -nL POSTROUTING | grep "MASQUERADE" | grep "$external_interface")
    if [[ -n "$rule_exists" ]]; then
        # Tente de supprimer les règles exactes pour éviter de supprimer des règles non liées.
        # Une approche plus robuste serait de supprimer par numéro de ligne si la règle est simple.
        # Pour cet exemple, on suppose qu'on peut ajouter sans crainte et que le système de persistance gérera les doublons.
        # Mais pour être sûr, on flush seulement si on gère la persistance.
        # Pour éviter les problèmes si des règles manuelles existent, on se concentre sur l'ajout.
        # Le paquet netfilter-persistent gère déjà l'effacement et le rechargement.
        # Pour une règle spécifique, on peut faire: sudo iptables -t nat -D POSTROUTING -o "$external_interface" -j MASQUERADE
        # print_step "Règle existante trouvée, suppression nécessaire avant ajout."
        # sudo iptables -t nat -D POSTROUTING -o "$external_interface" -j MASQUERADE &>/dev/null
        : # Ne rien faire, l'ajout va créer un doublon qui sera géré par netfilter-persistent lors de la sauvegarde/restauration.
          # Ou on peut choisir de ne pas supprimer et laisser iptables-save gérer le rechargement propre.
    fi

    # Ajoute une règle MASQUERADE pour masquer les adresses IP du réseau interne derrière l'IP de l'interface externe.
    if sudo iptables -t nat -A POSTROUTING -o "$external_interface" -j MASQUERADE &>/dev/null; then
        print_success "Règle NAT (MASQUERADE) ajoutée pour '$external_interface'."
    else
        print_error "Échec de l'ajout de la règle NAT pour '$external_interface'. Vérifiez les permissions ou si iptables est installé."
        return 1
    fi

    # 3. Sauvegarde des règles iptables pour la persistance au redémarrage.
    print_step "Sauvegarde des règles iptables pour la persistance..."

    # Vérifie et installe netfilter-persistent si nécessaire
    if ! dpkg -s netfilter-persistent &>/dev/null; then
        print_warning "Le paquet 'netfilter-persistent' n'est pas installé. Installation en cours pour assurer la persistance des règles IPTables."
        if ! sudo apt update -y &>/dev/null || ! sudo apt install -y netfilter-persistent &>/dev/null; then
            print_error "Échec de l'installation de 'netfilter-persistent'. Les règles IPTables ne seront PAS persistantes après un redémarrage."
            show_error "Échec de l'installation de netfilter-persistent. Les règles ne seront pas persistantes."
            return 1
        else
            print_success "'netfilter-persistent' a été installé avec succès."
        fi
    fi

    # Sauvegarde les règles en utilisant netfilter-persistent (qui utilise iptables-save en coulisses)
    if sudo netfilter-persistent save &>/dev/null; then
        print_success "Règles iptables sauvegardées via netfilter-persistent (persistantes au redémarrage)."
    else
        print_error "Échec de la sauvegarde des règles iptables avec netfilter-persistent. Les règles pourraient ne PAS être persistantes."
        show_error "Échec de la sauvegarde des règles iptables. Vérifiez les logs."
        return 1
    fi

    print_success "Configuration du routage et NAT terminée. Votre système agit maintenant comme un routeur basique."
    print_step "Assurez-vous que les clients de votre réseau local utilisent l'adresse IP de l'interface '$internal_interface' de ce serveur comme passerelle."
    return 0
}

# Lance la fonction au démarrage du script.
configurer_routage
