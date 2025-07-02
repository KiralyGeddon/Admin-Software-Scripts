#!/bin/bash
#
# Script d'installation de Docker Engine, Containerd et Docker Compose sur Debian/Ubuntu.
# Ce script automatise les étapes nécessaires pour installer Docker, le moteur de conteneurisation,
# ainsi que les outils pour gérer les conteneurs et les applications multi-conteneurs.
#
# Ce script ne dépend pas directement de lib.sh pour son exécution, mais il est appelé par menu_logiciels.sh.

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Define the log file path. We'll put it in the project root's logs directory.
# Assuming logs directory is at the same level as 'librairies', 'administration', 'logiciels'.
# We need to go up two levels from 'logiciels/scripts' to the root, then into 'logs'.
LOG_DIR="$SCRIPT_DIR/../../logs"
LOG_FILE="$LOG_DIR/AdminSysTools_install_docker.log"

# Create the logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect all stdout and stderr to the log file.
# The `exec` command replaces the current shell with a new one,
# where stdout (1) and stderr (2) are redirected to the log file.
# This ensures all subsequent commands in this script write to the log.
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Début de l'installation de Docker - $(date)"
echo "Logs enregistrés dans : $LOG_FILE"
echo "============================================================"

echo "Mise à jour des paquets du système..."
# Met à jour la liste des paquets disponibles et les versions des paquets installés.
sudo apt-get update -y || { echo "Erreur: Échec de la mise à jour des paquets." && exit 1; }

echo "Installation des pré-requis pour Docker..."
# Installe les paquets nécessaires pour que Docker puisse s'installer correctement.
sudo apt-get install -y ca-certificates curl gnupg lsb-release || { echo "Erreur: Échec de l'installation des pré-requis." && exit 1; }

echo "Ajout de la clé GPG officielle de Docker..."
# Crée un répertoire pour stocker les clés GPG des dépôts APT, avec les permissions appropriées.
sudo mkdir -m 0755 -p /etc/apt/keyrings || { echo "Erreur: Échec de création du répertoire de clés GPG." && exit 1; }
# Télécharge la clé GPG officielle de Docker et l'ajoute au trousseau de clés APT.
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "Erreur: Échec du téléchargement ou de l'ajout de la clé GPG Docker." && exit 1; }
# S'assure que les permissions du fichier de la clé GPG sont correctes.
sudo chmod a+r /etc/apt/keyrings/docker.gpg || { echo "Erreur: Échec de la modification des permissions de la clé GPG." && exit 1; }

echo "Configuration du dépôt Docker..."
# Ajoute le dépôt APT de Docker à la liste des sources du système.
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  \"$(. /etc/os-release && echo \"$VERSION_CODENAME\")\" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "Erreur: Échec de l'ajout du dépôt Docker." && exit 1; }

echo "Mise à jour de la liste des paquets avec le nouveau dépôt..."
# Met à jour la liste des paquets disponibles après l'ajout du dépôt Docker.
sudo apt-get update -y || { echo "Erreur: Échec de la mise à jour des dépôts après ajout de Docker." && exit 1; }

echo "Installation de Docker Engine, Containerd et Docker Compose..."
# Installe les composants principaux de Docker.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "Erreur: Échec de l'installation des paquets Docker." && exit 1; }

echo "Ajout de l'utilisateur actuel au groupe docker (nécessite une reconnexion)..."
sudo usermod -aG docker "$USER" || { echo "Erreur: Échec de l'ajout de l'utilisateur au groupe docker." && exit 1; }

echo "Démarrage et activation du service Docker..."
sudo systemctl start docker || { echo "Erreur: Échec du démarrage de Docker." && exit 1; }
sudo systemctl enable docker || { echo "Erreur: Échec de l'activation de Docker au démarrage." && exit 1; }

echo "Vérification de l'installation de Docker (cette commande peut échouer avant reconnexion)..."
docker run hello-world
# Note: This 'docker run' command is expected to fail with permission denied
# until the user logs out and back in. We don't want this failure to
# mark the overall installation as failed, as the necessary group
# modification has been applied.

echo "Installation de Docker terminée. Veuillez vous déconnecter et vous reconnecter pour que les changements de groupe prennent effet."
echo "============================================================"
echo "Fin de l'installation de Docker - $(date)"
echo "============================================================"

exit 0 # Indicate success