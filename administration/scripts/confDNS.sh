#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source ../librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: configurer_serveur_dns
# Cette fonction est un point de départ pour la configuration d'un serveur DNS (BIND9).
# La configuration DNS est complexe et nécessiterait un script beaucoup plus détaillé
# pour couvrir toutes les zones (maître, esclave, cache, etc.).
# Ce script se concentre sur l'installation de BIND9 et l'information de base.
#=============================================================================
configurer_serveur_dns() {
    print_step "Configuration d'un serveur DNS (BIND9)..."

    # Vérifie si BIND9 est installé.
    if ! dpkg -s bind9 &>/dev/null; then
        print_step "Le paquet 'bind9' n'est pas installé. Tentative d'installation..."
        if sudo apt update -y &>/dev/null && sudo apt install -y bind9 bind9utils bind9-doc &>/dev/null; then
            print_success "'bind9' a été installé avec succès."
        else
            print_error "Échec de l'installation de 'bind9'. Veuillez l'installer manuellement et relancer le script."
            return 1
        fi
    fi

    whiptail --msgbox "L'installation et la configuration complètes d'un serveur DNS sont complexes et nécessitent une intervention manuelle pour définir les zones et les enregistrements.\n\nCe script a installé le serveur BIND9. Vous devrez modifier les fichiers de configuration manuellement (par exemple, /etc/bind/named.conf.local, /etc/bind/db.example.com)." 15 70

    # Offre d'ouvrir le fichier de configuration principal pour consultation.
    if whiptail --yesno "Voulez-vous ouvrir le fichier de configuration principal de BIND9 (/etc/bind/named.conf.local) pour édition (nécessite un éditeur de texte en ligne de commande comme nano ou vim)?" 10 70; then
        print_step "Ouverture de /etc/bind/named.conf.local..."
        # Vérifie si nano est installé, sinon utilise vi.
        if command -v nano &>/dev/null; then
            sudo nano /etc/bind/named.conf.local
        elif command -v vim &>/dev/null; then
            sudo vim /etc/bind/named.conf.local
        else
            print_error "Aucun éditeur de texte (nano ou vim) trouvé. Veuillez l'installer ou éditer le fichier manuellement."
            return 1
        fi
    fi
    
    # Demande de redémarrer le service DNS après les modifications.
    if whiptail --yesno "Après avoir modifié les fichiers de configuration, il est recommandé de redémarrer le service BIND9. Voulez-vous le redémarrer maintenant ?" 10 70; then
        print_step "Redémarrage du service BIND9..."
        if sudo systemctl restart bind9 &>/dev/null; then
            print_success "Service BIND9 redémarré avec succès."
        else
            print_error "Échec du redémarrage du service BIND9. Vérifiez les logs pour plus d'informations (sudo systemctl status bind9)."
            print_error "Assurez-vous que votre configuration est valide : 'sudo named-checkconf' et 'sudo named-checkzone <zone> <fichier_zone>'."
            return 1
        fi
    fi

    print_step "Configuration DNS terminée (installation effectuée, configuration manuelle requise)."
    return 0
}

# Lance la fonction au démarrage du script.
configurer_serveur_dns