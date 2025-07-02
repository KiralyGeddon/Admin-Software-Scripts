#!/bin/bash
#
# Script d'installation de Nagios Core via Docker.
# Ce script déploie une instance simplifiée de Nagios Core, un outil de supervision de systèmes et réseaux,
# en utilisant un conteneur Docker. Il demande un port d'accès et un mot de passe administrateur.
#
# Dépendances :
#   - lib.sh : Bibliothèque de fonctions partagées.
#   - Docker : Doit être installé sur le système hôte.

# Inclusion de la bibliothèque de fonctions partagées. Le script quitte si non trouvée.
source ../librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Vérifie si whiptail est installé pour les interactions utilisateur.
check_whiptail || exit 1

# Récupère l'adresse IP locale de la machine.
LOCAL_IP=$(get_local_ip)

# Demande à l'utilisateur le port sur lequel l'interface web de Nagios sera accessible.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à l'interface web Nagios (par exemple, 8082) ?" 10 60 "8082" 3>&1 1>&2 2>&3)
# Quitte si l'utilisateur annule.
if [ $? -ne 0 ]; then
    print_error "Installation de Nagios annulée par l'utilisateur (choix du port)."
    exit 1
fi

# Demande à l'utilisateur de définir un mot de passe pour l'utilisateur 'nagiosadmin'.
# C'est l'utilisateur par défaut pour se connecter à l'interface web de Nagios.
NAGIOS_ADMIN_PASSWORD=$(whiptail --passwordbox "Définissez un mot de passe pour l'utilisateur 'nagiosadmin' (l'administrateur web de Nagios) :" 10 60 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de Nagios annulée par l'utilisateur (mot de passe admin)."
    exit 1
fi

print_step "Déploiement de Nagios Core via Docker..."
# Commande Docker pour lancer le conteneur Nagios.
# -d : Démarre le conteneur en mode détaché (en arrière-plan).
# -p "$PORT":80 : Mappe le port choisi par l'utilisateur ($PORT) sur le port 80 du conteneur (port HTTP de Nagios).
# --name nagios : Donne un nom au conteneur pour le gérer plus facilement.
# --restart always : Le conteneur redémarrera automatiquement en cas d'arrêt ou au démarrage du système.
# -e NAGIOS_AUTH_USER=nagiosadmin : Définit la variable d'environnement pour l'utilisateur d'authentification.
# -e NAGIOS_AUTH_PASSWORD="$NAGIOS_ADMIN_PASSWORD" : Définit la variable d'environnement pour le mot de passe admin.
# jasonrivers/nagios:latest : L'image Docker utilisée pour Nagios Core.
docker run -d -p "$PORT":80 --name nagios --restart always \
    -e NAGIOS_AUTH_USER=nagiosadmin \
    -e NAGIOS_AUTH_PASSWORD="$NAGIOS_ADMIN_PASSWORD" \
    jasonrivers/nagios:latest

# Vérifie si la commande docker run s'est exécutée avec succès.
if [ $? -eq 0 ]; then
    print_success "Nagios Core est en cours d'installation sur le port $PORT."
    # Affiche une boîte de message récapitulant les informations d'accès.
    whiptail --title "Installation de Nagios Core Terminée" --msgbox "
Nagios Core a été déployé avec succès !

Accès à l'interface web :
URL : http://$LOCAL_IP:$PORT/nagios

Informations de connexion :
Utilisateur : nagiosadmin
Mot de passe : $NAGIOS_ADMIN_PASSWORD (le mot de passe que vous avez défini)

Note : L'interface web peut prendre quelques instants pour être entièrement disponible.
" 18 80
else
    print_error "Échec du déploiement de Nagios Core via Docker. Veuillez vérifier les logs."
    whiptail --title "Erreur d'installation" --msgbox "Une erreur est survenue lors du déploiement de Nagios.
Vérifiez que Docker est bien en cours d'exécution et que le port $PORT n'est pas déjà utilisé." 10 70
fi

return $?