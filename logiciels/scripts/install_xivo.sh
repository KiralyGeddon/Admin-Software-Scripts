#!/bin/bash
#
# Script d'installation simplifié de XiVO via Docker.
# Ce script fournit un exemple très basique de déploiement d'un composant de XiVO (solution de téléphonie VoIP)
# via Docker. Il est important de noter qu'une installation complète de XiVO est complexe et nécessite
# généralement une configuration plus détaillée avec Docker Compose et plusieurs services.
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

# Demande à l'utilisateur le port sur lequel il souhaite accéder à l'interface web de XiVO.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à l'interface web XiVO (par exemple, 9487) ?" 10 60 "9487" 3>&1 1>&2 2>&3)
# Quitte si l'utilisateur annule.
if [ $? -ne 0 ]; then
    print_error "Installation de XiVO annulée par l'utilisateur (choix du port)."
    exit 1
fi

print_step "Déploiement de XiVO (serveur de configuration simplifié) via Docker..."
# Commande Docker pour lancer un conteneur XiVO.
# Note IMPORTANTE : C'est un exemple très simplifié. Un déploiement complet de XiVO implique de nombreux services
# (PostgreSQL, Asterisk, xivo-agid, xivo-ctid, etc.) et nécessiterait un fichier docker-compose détaillé.
# L'image 'xivo/xivo-server:latest' est illustrative et pourrait ne pas exister ou être suffisante pour une installation complète.
# -d : Démarre le conteneur en mode détaché (en arrière-plan).
# -p "$PORT":9487 : Mappe le port choisi par l'utilisateur sur le port 9487 du conteneur (port par défaut pour XiVO Config).
# --name xivo-config : Donne un nom au conteneur.
# --restart always : Le conteneur redémarrera automatiquement.
# xivo/xivo-server:latest : Image Docker illustrative pour un composant XiVO.
docker run -d -p "$PORT":9487 --name xivo-config --restart always xivo/xivo-server:latest # This image name is illustrative

# Vérifie si la commande docker run s'est exécutée avec succès.
if [ $? -eq 0 ]; then
    print_success "XiVO est en cours d'installation sur le port $PORT."
    # Affiche une boîte de message récapitulant les informations d'accès et les avertissements.
    whiptail --title "Installation de XiVO (simplifiée) Terminée" --msgbox "
XiVO a été déployé (simplifié) avec succès !

Accès potentiel à l'interface web :
URL : http://$LOCAL_IP:$PORT

Note IMPORTANTE :
L'installation de XiVO via Docker est complexe et cet exemple est très simplifié.
Une configuration complète nécessiterait un docker-compose détaillé avec plusieurs services
(PostgreSQL, Asterisk, xivo-agid, xivo-ctid, etc.).
Cette commande lance un composant de base, mais ne constitue pas une installation complète et fonctionnelle de XiVO.
Consultez la documentation officielle de XiVO pour un déploiement complet.
" 20 80
else
    print_error "Échec du déploiement de XiVO via Docker. Veuillez vérifier les logs."
    whiptail --title "Erreur d'installation" --msgbox "Une erreur est survenue lors du déploiement de XiVO.
Vérifiez que Docker est bien en cours d'exécution et que le port $PORT n'est pas déjà utilisé." 10 70
fi

return $?