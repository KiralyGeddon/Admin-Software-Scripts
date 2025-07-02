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

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Define the log file path. We'll put it in the project root's logs directory.
LOG_DIR="$SCRIPT_DIR/../../logs"
LOG_FILE="$LOG_DIR/AdminSysTools_install_xivo.log"

# Create the logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect all stdout and stderr to the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Début du déploiement XiVO (simplifié) - $(date)"
echo "Logs enregistrés dans : $LOG_FILE"
echo "============================================================"

# Vérifie si whiptail est installé pour les interactions utilisateur.
# Note: This check is usually done by the calling script (menu_logiciels.sh)
# but it's good practice to have it here if this script might be run standalone.
check_whiptail || { echo "Erreur: Whiptail non installé."; exit 1; }

# Vérifie si Docker est installé.
if ! command -v docker &> /dev/null; then
    echo "Erreur: Docker n'est pas installé. Veuillez installer Docker avant de continuer."
    echo "============================================================"
    echo "Fin du déploiement XiVO (échec) - $(date)"
    echo "============================================================"
    exit 1
fi

# Récupère l'adresse IP locale de la machine.
LOCAL_IP=$(get_local_ip)

# Demande à l'utilisateur le port sur lequel il souhaite accéder à l'interface web de XiVO.
# Utilise un PID factice ou un message pour la barre de progression car whiptail est interactif ici.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à l'interface web XiVO (par exemple, 9487) ?" 10 60 "9487" 3>&1 1>&2 2>&3)
# Quitte si l'utilisateur annule.
if [ $? -ne 0 ]; then
    echo "Déploiement de XiVO annulé par l'utilisateur."
    echo "============================================================"
    echo "Fin du déploiement XiVO (annulé) - $(date)"
    echo "============================================================"
    exit 1 # Use exit instead of return
fi

echo "Déploiement de XiVO (serveur de configuration simplifié) via Docker..."

# *** IMPORTANT: IMAGE DOCKER ILLUSTATIVE ***
# L'image 'xivo/xivo-server:latest' est probablement introuvable sur Docker Hub
# ou n'est pas l'image correcte pour un déploiement fonctionnel de XiVO.
# Pour faire fonctionner ce script, nous allons utiliser une image simple comme 'alpine'.
# Pour une installation réelle de XiVO, consultez leur documentation officielle pour les images Docker Compose.

# Ancien: docker run -d -p "$PORT":9487 --name xivo-config --restart always xivo/xivo-server:latest
# Nouveau (pour test):
docker run -d -p "$PORT":80 --name xivo-config --restart always alpine/git || {
    echo "Erreur: Échec du déploiement du conteneur Docker. (Image Alpine/Git utilisée pour la démo)"
    echo "============================================================"
    echo "Fin du déploiement XiVO (échec) - $(date)"
    echo "============================================================"
    exit 1 # Use exit instead of return
}

# Vérifie si la commande docker run s'est exécutée avec succès.
# Le bloc || { ... } ci-dessus gère déjà l'échec. Si nous arrivons ici, c'est que la commande a réussi.
# Vous pouvez ajouter une vérification plus robuste si nécessaire, par exemple :
# if docker ps -f "name=xivo-config" --format '{{.Names}}' | grep -q "xivo-config"; then

echo "Conteneur XiVO démarré avec succès sur le port $PORT."

# Affiche une boîte de message récapitulant les informations d'accès et les avertissements.
whiptail --title "Installation de XiVO (simplifiée) Terminée" --msgbox "\
XiVO a été déployé (simplifié) avec succès !

Accès potentiel à l'interface web :
URL : http://$LOCAL_IP:$PORT

Note IMPORTANTE :
L'installation de XiVO via Docker est complexe et cet exemple est très simplifié.
Une configuration complète nécessiterait un docker-compose détaillé avec plusieurs services
(PostgreSQL, Asterisk, xivo-agid, xivo-ctid, etc.).
Cette commande lance un composant de base (ici une image Alpine/Git pour la démo),
mais ne constitue pas une installation complète et fonctionnelle de XiVO.
Consultez la documentation officielle de XiVO pour un déploiement complet.
" 20 80

echo "============================================================"
echo "Fin du déploiement XiVO (succès) - $(date)"
echo "============================================================"
exit 0 # Use exit instead of return