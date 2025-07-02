#!/bin/bash
#
# Script d'installation de Zabbix via Docker Compose.
# Ce script permet de déployer l'outil de supervision Zabbix en utilisant des conteneurs Docker.
# Il demande à l'utilisateur des informations essentielles comme le port d'accès et les identifiants de base de données.
#
# Dépendances :
#   - lib.sh : Bibliothèque de fonctions partagées pour l'affichage, la vérification de whiptail, etc.
#   - Docker et Docker Compose : Doivent être installés sur le système hôte. Le script menu_logiciels.sh gère l'installation de Docker.

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Inclusion de la bibliothèque de fonctions partagées.
source "$SCRIPT_DIR/../../librairies/lib.sh" || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

# Vérifie si 'whiptail' est installé. C'est un outil essentiel pour afficher des boîtes de dialogue interactives.
# Si whiptail n'est pas là, la fonction check_whiptail de lib.sh tentera de l'installer ou quittera le script en cas d'échec.
check_whiptail || exit 1

# Récupère l'adresse IP locale de la machine. Cette fonction vient de lib.sh.
# L'IP locale est utilisée pour informer l'utilisateur de l'URL d'accès à l'interface web de Zabbix.
LOCAL_IP=$(get_local_ip)

# Demande à l'utilisateur sur quel port il souhaite accéder à l'interface web de Zabbix.
# 'whiptail --inputbox' affiche une boîte de dialogue demandant une saisie utilisateur.
# 10 60 : dimensions de la boîte (hauteur 10 lignes, largeur 60 caractères).
# "8081" : valeur par défaut proposée.
PORT=$(whiptail --inputbox "Sur quel port souhaitez-vous accéder à l'interface web Zabbix (par exemple, 8081) ?" 10 60 "8081" 3>&1 1>&2 2>&3)
# $? vérifie le code de sortie de la dernière commande. Si différent de 0, l'utilisateur a annulé.
if [ $? -ne 0 ]; then
    print_error "Installation de Zabbix annulée par l'utilisateur (choix du port)."
    exit 1
fi

# Demande le nom d'utilisateur pour la base de données Zabbix.
DB_USER=$(whiptail --inputbox "Nom d'utilisateur de la base de données Zabbix (par exemple, zabbix) :" 10 60 "zabbix" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de Zabbix annulée par l'utilisateur (nom d'utilisateur DB)."
    exit 1
fi

# Demande le mot de passe pour l'utilisateur de la base de données Zabbix.
# 'whiptail --passwordbox' masque la saisie pour plus de sécurité.
DB_PASSWORD=$(whiptail --passwordbox "Mot de passe pour l'utilisateur de la base de données Zabbix :" 10 60 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de Zabbix annulée par l'utilisateur (mot de passe DB)."
    exit 1
fi

# Demande le nom de la base de données Zabbix.
DB_NAME=$(whiptail --inputbox "Nom de la base de données Zabbix (par exemple, zabbix) :" 10 60 "zabbix" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de Zabbix annulée par l'utilisateur (nom DB)."
    exit 1
fi

# Demande le mot de passe ROOT pour le serveur PostgreSQL.
# Ce mot de passe est essentiel pour l'administration interne de la base de données PostgreSQL.
POSTGRES_ROOT_PASSWORD=$(whiptail --passwordbox "Mot de passe ROOT pour le serveur PostgreSQL de Zabbix (sera créé ou utilisé) :" 10 60 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
    print_error "Installation de Zabbix annulée par l'utilisateur (mot de passe ROOT PostgreSQL)."
    exit 1
fi

# Affiche une étape de progression pour l'utilisateur.
print_step "Création du répertoire pour les fichiers Docker Compose de Zabbix..."
# Crée un répertoire spécifique pour Zabbix dans le dossier personnel de l'utilisateur.
mkdir -p ~/zabbix_docker
# Change le répertoire de travail actuel pour ce nouveau dossier.
# Le '|| { ...; exit 1; }' gère les erreurs : si le cd échoue, un message d'erreur est affiché et le script quitte.
cd ~/zabbix_docker || { print_error "Impossible de créer ou d'accéder au répertoire ~/zabbix_docker"; exit 1; }

print_step "Création du fichier docker-compose.yaml pour Zabbix..."
# Crée le fichier docker-compose.yaml en utilisant un "heredoc" (EOF).
# Cela permet d'écrire un bloc de texte multiligne directement dans un fichier.
cat <<EOF > docker-compose.yaml
# Version du fichier Docker Compose.
version: '3.8'

# Définition des services (conteneurs) qui composent l'application Zabbix.
services:
  # Service pour le serveur Zabbix.
  zabbix-server:
    # Utilise l'image Docker officielle de Zabbix server avec PostgreSQL.
    image: zabbix/zabbix-server-pgsql:latest
    # Définit les variables d'environnement nécessaires au serveur Zabbix pour se connecter à la base de données.
    environment:
      - DB_SERVER_HOST=zabbix-db # L'hôte de la base de données est le nom du service Docker Compose.
      - POSTGRES_USER=$DB_USER
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_DB=$DB_NAME
      - ZBX_LOGLEVEL=3 # Niveau de log de Zabbix.
      - ZBX_LISTENPORT=10051 # Port d'écoute du serveur Zabbix.
    # Dépend du service de base de données. Cela garantit que la DB démarre avant le serveur Zabbix.
    depends_on:
      - zabbix-db
    # Redémarre toujours le conteneur s'il s'arrête.
    restart: always

  # Service pour l'interface web de Zabbix (frontend).
  zabbix-web:
    # Utilise l'image Docker officielle de Zabbix web avec Nginx et PostgreSQL.
    image: zabbix/zabbix-web-nginx-pgsql:latest
    # Mappe le port spécifié par l'utilisateur (par exemple, 8081) sur le port 80 du conteneur.
    ports:
      - "$PORT:80"
    # Variables d'environnement pour l'interface web, y compris les informations de connexion à la DB et le fuseau horaire.
    environment:
      - DB_SERVER_HOST=zabbix-db
      - POSTGRES_USER=$DB_USER
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_DB=$DB_NAME
      - PHP_TZ=Europe/Paris # Ajustez votre fuseau horaire si nécessaire.
    # Dépend du serveur Zabbix.
    depends_on:
      - zabbix-server
    restart: always

  # Service pour la base de données PostgreSQL.
  zabbix-db:
    # Utilise l'image officielle de PostgreSQL.
    image: postgres:latest
    # Variables d'environnement pour la configuration de la base de données PostgreSQL.
    environment:
      - POSTGRES_USER=$DB_USER
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_DB=$DB_NAME
      - POSTGRES_PASSWORD=$POSTGRES_ROOT_PASSWORD # Mot de passe pour le superuser Postgres interne au conteneur.
    # Monte un volume persistant pour stocker les données de la base de données.
    # Cela garantit que les données ne sont pas perdues si le conteneur est supprimé.
    volumes:
      - ./pg_data:/var/lib/postgresql/data
    restart: always
EOF

print_step "Déploiement de Zabbix via Docker Compose..."
# Exécute les services définis dans docker-compose.yaml en mode détaché (-d).
# Cela lance les conteneurs en arrière-plan.
docker compose up -d

# Vérifie si la commande 'docker compose up -d' s'est exécutée avec succès.
if [ $? -eq 0 ]; then
    print_success "Zabbix est en cours d'installation sur le port $PORT. Veuillez patienter pendant le démarrage des services."
    # Affiche une boîte de message Whiptail récapitulant les informations d'accès.
    whiptail --title "Installation de Zabbix Terminée" --msgbox "
Zabbix a été déployé avec succès via Docker Compose !

Accès à l'interface web :
URL : http://$LOCAL_IP:$PORT

Informations de connexion par défaut (pour la première connexion) :
Utilisateur : Admin
Mot de passe : zabbix

Informations Base de Données (utilisées par Zabbix) :
Nom d'utilisateur DB : $DB_USER
Mot de passe DB : $DB_PASSWORD
Nom de la base de données : $DB_NAME
Mot de passe ROOT PostgreSQL (pour administration DB interne) : $POSTGRES_ROOT_PASSWORD
" 20 80
else
    print_error "Échec du déploiement de Zabbix via Docker Compose. Veuillez vérifier les logs."
    whiptail --title "Erreur d'installation" --msgbox "Une erreur est survenue lors du déploiement de Zabbix.
Vérifiez que Docker est bien en cours d'exécution et que le port $PORT n'est pas déjà utilisé." 10 70
fi

# Retourne le statut de l'installation (0 pour succès, 1 pour échec).
return $?