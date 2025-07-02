#!/bin/bash
#
# Script d'installation de GLPI (Gestion Libre de Parc Informatique) via Docker Compose.
# Ce script facilite le déploiement de GLPI en utilisant des conteneurs Docker pour l'application
# et sa base de données (MariaDB/MySQL).
# Il demande à l'utilisateur de configurer le port d'accès et les informations de la base de données.
#
# Dépendances :
#   - lib.sh : Bibliothèque de fonctions partagées pour l'affichage, la vérification de whiptail, etc.
#   - Docker et Docker Compose : Doivent être installés sur le système hôte. Le script menu_logiciels.sh gère l'installation de Docker.

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Vérifie si 'whiptail' est installé pour les boîtes de dialogue interactives.
check_whiptail || exit 1

# Récupère l'adresse IP locale de la machine à partir de lib.sh.
LOCAL_IP=$(get_local_ip)

# Demande à l'utilisateur sur quel port il souhaite accéder à l'interface web de GLPI.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à GLPI (par exemple, 8080) ?" 10 60 "8080" 3>&1 1>&2 2>&3)
# Si l'utilisateur annule la saisie du port, le script quitte.
if [ $? -ne 0 ]; then
    print_error "Installation de GLPI annulée par l'utilisateur (choix du port)."
    exit 1
fi

# Demande le nom d'utilisateur pour la base de données GLPI.
DB_USER=$(whiptail --inputbox "Nom d'utilisateur de la base de données GLPI (par exemple, glpiuser) :" 10 60 "glpiuser" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de GLPI annulée par l'utilisateur (nom d'utilisateur DB)."
    exit 1
fi

# Demande le mot de passe pour l'utilisateur de la base de données GLPI (masqué).
DB_PASSWORD=$(whiptail --passwordbox "Mot de passe pour l'utilisateur de la base de données GLPI :" 10 60 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de GLPI annulée par l'utilisateur (mot de passe DB)."
    exit 1
fi

# Demande le nom de la base de données GLPI.
DB_NAME=$(whiptail --inputbox "Nom de la base de données GLPI (par exemple, glpidb) :" 10 60 "glpidb" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de GLPI annulée par l'utilisateur (nom DB)."
    exit 1
fi

# Demande le mot de passe ROOT pour le serveur MySQL/MariaDB (masqué).
# Ce mot de passe est utilisé pour l'administration interne de la base de données.
MYSQL_ROOT_PASSWORD=$(whiptail --passwordbox "Mot de passe ROOT pour le serveur MySQL/MariaDB de GLPI (sera créé ou utilisé) :" 10 60 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de GLPI annulée par l'utilisateur (mot de passe ROOT MySQL)."
    exit 1
fi

print_step "Création du répertoire pour les fichiers Docker Compose de GLPI..."
mkdir -p ~/glpi_docker
cd ~/glpi_docker || { print_error "Impossible de créer ou d'accéder au répertoire ~/glpi_docker"; exit 1; }

print_step "Création du fichier docker-compose.yaml pour GLPI..."
# Crée le fichier docker-compose.yaml avec la configuration des services GLPI et MariaDB.
cat <<EOF > docker-compose.yaml
# Version du fichier Docker Compose.
version: '3.8'

# Définition des volumes persistants pour les données de GLPI et de la base de données.
# Cela assure que les données ne sont pas perdues si les conteneurs sont recréés.
volumes:
  glpi_db_data: # Volume pour les données de la base de données.
  glpi_data:    # Volume pour les fichiers de l'application GLPI.

# Définition des services (conteneurs) qui composent l'application GLPI.
services:
  # Service de base de données MariaDB pour GLPI.
  glpi-db:
    image: mariadb:latest # Utilise l'image officielle de MariaDB.
    container_name: glpi_db # Nom du conteneur.
    # Variables d'environnement pour configurer la base de données.
    environment:
      MYSQL_ROOT_PASSWORD: "$MYSQL_ROOT_PASSWORD" # Mot de passe root pour MariaDB.
      MYSQL_DATABASE: "$DB_NAME"
      MYSQL_USER: "$DB_USER"
      MYSQL_PASSWORD: "$DB_PASSWORD"
    # Monte le volume persistant pour stocker les données de la base.
    volumes:
      - glpi_db_data:/var/lib/mysql
    restart: always # Redémarre toujours le conteneur s'il s'arrête.

  # Service de l'application GLPI.
  glpi-app:
    image: diouxx/glpi:latest # Utilise l'image Docker de DiouxX pour GLPI.
    container_name: glpi_app # Nom du conteneur.
    # Mappe le port spécifié par l'utilisateur (ex: 8080) sur le port 80 du conteneur (port web par défaut).
    ports:
      - "$PORT:80"
    # Variables d'environnement pour que l'application GLPI se connecte à sa base de données.
    environment:
      GLPI_DB_HOST: glpi-db # L'hôte de la base de données est le nom du service Docker Compose.
      GLPI_DB_NAME: "$DB_NAME"
      GLPI_DB_USER: "$DB_USER"
      GLPI_DB_PASSWORD: "$DB_PASSWORD"
      # Vous pouvez ajouter d'autres variables d'environnement spécifiques à l'image DiouxX si nécessaire,
      # par exemple, pour le fuseau horaire: TIMEZONE: "Europe/Paris"
    # Monte le volume persistant pour stocker les fichiers de l'application GLPI.
    volumes:
      - glpi_data:/var/www/html # L'image DiouxX s'attend à /var/www/html pour les données GLPI
    # Dépend du service de base de données, assure que la DB démarre avant l'application.
    depends_on:
      - glpi-db
    restart: always
EOF

print_step "Déploiement de GLPI via Docker Compose..."
# Démarre les services définis dans docker-compose.yaml en mode détaché.
docker compose up -d

# Vérifie le succès du déploiement.
if [ $? -eq 0 ]; then
    print_success "GLPI est en cours d'installation sur le port $PORT. Veuillez patienter pendant le démarrage des services."
    # Affiche un récapitulatif des informations importantes via whiptail.
    whiptail --title "Installation de GLPI Terminée" --msgbox "
GLPI a été déployé avec succès via Docker Compose !

Accès à l'interface web :
URL : http://$LOCAL_IP:$PORT

Informations Base de Données (utilisées par GLPI) :
Nom d'utilisateur DB : $DB_USER
Mot de passe DB : $DB_PASSWORD
Nom de la base de données : $DB_NAME
Mot de passe ROOT MySQL (pour administration DB) : $MYSQL_ROOT_PASSWORD

Note: Lors de la première connexion à l'interface web, suivez les étapes de configuration de GLPI.
" 20 80
else
    print_error "Échec du déploiement de GLPI via Docker Compose. Vérifiez les logs."
    whiptail --title "Erreur d'installation" --msgbox "Une erreur est survenue lors du déploiement de GLPI.
Vérifiez que Docker est bien en cours d'exécution et que le port $PORT n'est pas déjà utilisé." 10 70
fi

return $?