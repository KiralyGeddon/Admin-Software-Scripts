#!/bin/bash
#
# Script d'installation de Portainer CE (Community Edition) via Docker.
# Portainer est une interface de gestion graphique pour Docker, permettant de gérer facilement
# les conteneurs, images, volumes et réseaux Docker.
# Ce script demande le port d'accès pour l'interface web de Portainer.
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

# Demande à l'utilisateur le port sur lequel il souhaite accéder à l'interface web de Portainer.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à Portainer (par exemple, 9000) ?" 10 60 "9000" 3>&1 1>&2 2>&3)
# Quitte si l'utilisateur annule.
if [ $? -ne 0 ]; then
    print_error "Installation de Portainer annulée par l'utilisateur (choix du port)."
    exit 1
fi

print_step "Création du volume Portainer..."
# Crée un volume Docker persistant nommé 'portainer_data'.
# Ce volume est utilisé par Portainer pour stocker ses données de configuration.
docker volume create portainer_data

print_step "Déploiement de Portainer via Docker..."
# Commande Docker pour lancer le conteneur Portainer.
# -d : Démarre le conteneur en mode détaché (en arrière-plan).
# -p "$PORT":9000 : Mappe le port choisi par l'utilisateur ($PORT) sur le port 9000 du conteneur (port web de Portainer).
# -p 8000:8000 : Mappe le port 8000 du conteneur pour la communication entre Portainer et l'agent (si utilisé).
# --name portainer : Donne un nom au conteneur.
# --restart always : Le conteneur redémarrera automatiquement.
# -v /var/run/docker.sock:/var/run/docker.sock : Monte le socket Docker de l'hôte dans le conteneur.
#   Cela permet à Portainer de communiquer avec le démon Docker de l'hôte pour gérer les conteneurs.
# -v portainer_data:/data : Monte le volume persistant 'portainer_data' dans le répertoire /data du conteneur.
# portainer/portainer-ce:latest : L'image Docker de Portainer Community Edition.
docker run -d -p "$PORT":9000 -p 8000:8000 --name portainer --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

# Vérifie si la commande docker run s'est exécutée avec succès.
if [ $? -eq 0 ]; then
    print_success "Portainer est en cours d'installation sur le port $PORT."
    # Affiche une boîte de message récapitulant les informations d'accès.
    whiptail --title "Installation de Portainer Terminée" --msgbox "
Portainer a été déployé avec succès !

Accès à l'interface web :
URL : http://$LOCAL_IP:$PORT

Lors de la première connexion, vous serez invité à créer un utilisateur administrateur et son mot de passe.
" 15 80
else
    print_error "Échec du déploiement de Portainer via Docker. Veuillez vérifier les logs."
    whiptail --title "Erreur d'installation" --msgbox "Une erreur est survenue lors du déploiement de Portainer.
Vérifiez que Docker est bien en cours d'exécution et que le port $PORT n'est pas déjà utilisé." 10 70
fi

return $?