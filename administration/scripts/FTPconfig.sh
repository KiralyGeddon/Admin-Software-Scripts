#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
source /home/sam/script/TSSR/librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }

#=============================================================================
# Fonction: configurer_serveur_ftp
# Cette fonction permet d'installer et de configurer un serveur FTP (vsftpd).
# Elle propose une configuration de base pour un accès sécurisé via chroot.
#=============================================================================
configurer_serveur_ftp() {
    print_step "Configuration d'un serveur FTP (vsftpd)..."

    # Vérifie si vsftpd est installé.
    if ! dpkg -s vsftpd &>/dev/null; then
        print_step "Le paquet 'vsftpd' n'est pas installé. Tentative d'installation..."
        if sudo apt update -y &>/dev/null && sudo apt install -y vsftpd &>/dev/null; then
            print_success "'vsftpd' a été installé avec succès."
        else
            print_error "Échec de l'installation de 'vsftpd'. Veuillez l'installer manuellement et relancer le script."
            return 1
        fi
    fi

    local vsftpd_config_file="/etc/vsftpd.conf"

    # Sauvegarde du fichier de configuration original.
    print_step "Sauvegarde du fichier de configuration original de vsftpd..."
    if sudo cp "$vsftpd_config_file" "$vsftpd_config_file.bak" &>/dev/null; then
        print_success "Ancienne configuration sauvegardée sous '$vsftpd_config_file.bak'."
    else
        print_warning "Impossible de sauvegarder l'ancienne configuration vsftpd. Le fichier existe peut-être déjà ou problème de permissions."
    fi

    print_step "Configuration de vsftpd pour un accès sécurisé..."

    # Configuration de base pour vsftpd
    # On utilise 'tee' pour écrire dans le fichier avec sudo.
    # 'eof' est un délimiteur pour le bloc de texte à écrire (heredoc).
    local config_content="
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
# Permet aux utilisateurs d'écrire si leur répertoire chrooté n'est pas inscriptible par l'utilisateur.
# Créez des sous-répertoires inscriptibles si nécessaire.
allow_writeable_chroot=YES 
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
#ssl_tlsv1=YES
#ssl_sslv2=NO
#ssl_sslv3=NO
#require_ssl_reuse=NO
#ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
"
    if echo "$config_content" | sudo tee "$vsftpd_config_file" &>/dev/null; then
        print_success "Fichier de configuration '$vsftpd_config_file' mis à jour."
    else
        print_error "Échec de l'écriture du fichier de configuration vsftpd."
        return 1
    fi

    # Création du répertoire chroot vide si vsftpd le nécessite (selon la version).
    print_step "Vérification et création du répertoire chroot sécurisé..."
    if sudo mkdir -p /var/run/vsftpd/empty &>/dev/null && sudo chmod 600 /var/run/vsftpd/empty &>/dev/null; then
        print_success "Répertoire /var/run/vsftpd/empty créé et sécurisé."
    else
        print_warning "Impossible de créer ou sécuriser /var/run/vsftpd/empty. Le service peut ne pas démarrer."
    fi

    # Création d'un utilisateur FTP dédié (si souhaité) ou utilisation d'un utilisateur existant.
    if whiptail --yesno "Voulez-vous créer un nouvel utilisateur dédié à FTP (non-sudoer, chrooté) ?" 8 70; then
        local ftp_username
        ftp_username=$(get_input "Entrez le nom du nouvel utilisateur FTP:")
        if [[ -z "$ftp_username" ]]; then
            print_error "Nom d'utilisateur vide. Annulation de la création d'utilisateur FTP."
        else
            if id -u "$ftp_username" &>/dev/null; then
                print_warning "L'utilisateur '$ftp_username' existe déjà. Nous allons utiliser cet utilisateur."
            else
                print_step "Création de l'utilisateur FTP '$ftp_username'..."
                if sudo useradd -m "$ftp_username" -s /usr/sbin/nologin &>/dev/null; then # -s nologin pour éviter la connexion shell
                    print_success "Utilisateur '$ftp_username' créé."
                    local ftp_password
                    ftp_password=$(get_input_password "Définissez le mot de passe pour l'utilisateur '$ftp_username':")
                    echo "$ftp_username:$ftp_password" | sudo chpasswd &>/dev/null
                    print_success "Mot de passe défini pour '$ftp_username'."
                else
                    print_error "Échec de la création de l'utilisateur '$ftp_username'."
                fi
            fi
            # Création d'un répertoire 'ftp' inscriptible à l'intérieur du home de l'utilisateur.
            # L'utilisateur sera chrooté dans son répertoire personnel.
            # Seul ce sous-répertoire sera inscriptible.
            print_step "Création d'un répertoire inscriptible pour '$ftp_username'..."
            sudo mkdir -p "/home/$ftp_username/ftp" &>/dev/null
            sudo chown nobody:nogroup "/home/$ftp_username/ftp" &>/dev/null
            sudo chmod a-w "/home/$ftp_username" &>/dev/null # Rendre le dossier home non-inscriptible par l'utilisateur lui-même
            sudo chown "$ftp_username:$ftp_username" "/home/$ftp_username/ftp" &>/dev/null
            print_success "Répertoire FTP '/home/$ftp_username/ftp' créé et permissions ajustées."
        fi
    else
        print_step "Aucun nouvel utilisateur FTP créé. Vous devrez utiliser un utilisateur existant."
    fi


    print_step "Redémarrage du service vsftpd..."
    # Redémarre le service vsftpd pour appliquer les modifications.
    if sudo systemctl restart vsftpd &>/dev/null; then
        print_success "Service vsftpd redémarré avec succès."
        print_step "Votre serveur FTP est maintenant configuré."
        print_step "Pour un accès sécurisé, utilisez SFTP (SSH) si possible, qui est généralement activé par défaut avec SSH."
        return 0
    else
        print_error "Échec du redémarrage du service vsftpd. Vérifiez les logs pour plus d'informations (sudo systemctl status vsftpd)."
        print_error "Assurez-vous que le fichier vsftpd.conf ne contient pas d'erreurs de syntaxe."
        return 1
    fi
}

# Lance la fonction au démarrage du script.
configurer_serveur_ftp