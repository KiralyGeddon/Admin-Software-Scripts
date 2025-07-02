#!/bin/bash
#
# Script d'installation de Docker Engine, Containerd et Docker Compose sur Debian/Ubuntu.
# Ce script automatise les étapes nécessaires pour installer Docker, le moteur de conteneurisation,
# ainsi que les outils pour gérer les conteneurs et les applications multi-conteneurs.
#
# Ce script ne dépend pas directement de lib.sh pour son exécution, mais il est appelé par menu_logiciels.sh.

# Affiche un message d'étape pour informer l'utilisateur.
echo "Mise à jour des paquets du système..."
# Met à jour la liste des paquets disponibles et les versions des paquets installés.
# '-y' : répond "oui" automatiquement à toutes les questions.
sudo apt-get update -y

echo "Installation des pré-requis pour Docker..."
# Installe les paquets nécessaires pour que Docker puisse s'installer correctement.
# 'ca-certificates' : permet aux navigateurs web et aux outils de vérifier l'authenticité des serveurs SSL/TLS.
# 'curl' : un outil en ligne de commande pour transférer des données avec des URL.
# 'gnupg' : un outil pour gérer les clés GPG, utilisé pour vérifier l'authenticité des paquets.
# 'lsb-release' : fournit des informations sur la distribution Linux (comme la version).
sudo apt-get install -y ca-certificates curl gnupg lsb-release

echo "Ajout de la clé GPG officielle de Docker..."
# Crée un répertoire pour stocker les clés GPG des dépôts APT, avec les permissions appropriées.
sudo mkdir -m 0755 -p /etc/apt/keyrings
# Télécharge la clé GPG officielle de Docker via curl.
# '| sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg' : décompacte la clé et la stocke dans le fichier spécifié.
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "Configuration du dépôt Docker..."
# Ajoute le dépôt officiel de Docker aux sources de paquets APT.
# Cela permet à apt de trouver et d'installer les paquets Docker.
# 'arch=$(dpkg --print-architecture)' : détecte l'architecture de votre système (ex: amd64).
# 'signed-by=/etc/apt/keyrings/docker.gpg' : spécifie la clé GPG utilisée pour vérifier l'authenticité des paquets de ce dépôt.
# '$(lsb_release -cs)' : détecte le nom de code de votre distribution Linux (ex: bookworm pour Debian 12).
# '> /dev/null' : redirige la sortie standard vers /dev/null pour éviter l'affichage de messages superflus.
# '2>&1' : redirige la sortie d'erreur vers la sortie standard.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Mise à jour des paquets après ajout du dépôt Docker..."
# Met à jour la liste des paquets APT pour inclure les nouveaux paquets du dépôt Docker.
sudo apt-get update -y

echo "Installation de Docker Engine, Containerd et Docker Compose..."
# Installe les composants principaux de Docker :
# 'docker-ce' : Docker Community Edition (le moteur Docker).
# 'docker-ce-cli' : L'interface en ligne de commande de Docker.
# 'containerd.io' : Un runtime de conteneur qui gère le cycle de vie des conteneurs.
# 'docker-buildx-plugin' : Un plugin pour Docker qui étend les capacités de build.
# 'docker-compose-plugin' : Le plugin Docker Compose pour définir et exécuter des applications multi-conteneurs.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Ajout de l'utilisateur actuel au groupe docker pour exécuter Docker sans sudo (nécessite une reconnexion)..."
# Ajoute l'utilisateur actuel ($USER) au groupe 'docker'.
# Cela permet à l'utilisateur d'exécuter les commandes Docker sans avoir à utiliser 'sudo' à chaque fois.
# NOTE : Cette modification prend effet après une déconnexion/reconnexion de l'utilisateur.
sudo usermod -aG docker "$USER"

echo "Démarrage et activation du service Docker..."
# Démarre le service Docker.
sudo systemctl start docker
# Active le service Docker pour qu'il démarre automatiquement au démarrage du système.
sudo systemctl enable docker

echo "Vérification de l'installation de Docker..."
# Exécute un conteneur simple "hello-world" pour vérifier que Docker fonctionne correctement.
# Si cette commande s'exécute sans erreur et affiche un message de bienvenue de Docker, l'installation est réussie.
docker run hello-world

echo "Installation de Docker terminée. Veuillez vous déconnecter et vous reconnecter pour que les changements de groupe prennent effet."
# Le script se termine ici. L'utilisateur doit se reconnecter manuellement.