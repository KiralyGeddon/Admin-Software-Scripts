#!/bin/bash

# Inclusion de la bibliothèque de fonctions partagées.
# Le '.' est un raccourci pour la commande 'source'.
# Cela permet d'utiliser les fonctions définies dans 'lib.sh' (comme print_success, print_error, etc.).
# Le script s'arrête si la bibliothèque n'est pas trouvée, affichant un message d'erreur.
source ../librairies/lib.sh || { echo "Erreur: Le fichier lib.sh est introuvable."; exit 1; }


#=============================================================================
# Menu de gestion d'administration
# Cette fonction affiche un menu interactif pour les tâches d'administration système.
#=============================================================================
menu_admin(){
    # Boucle infinie pour afficher le menu tant que l'utilisateur ne quitte pas.
    # La boucle s'arrêtera lorsque l'utilisateur choisira l'option "Retour au menu principal" (option 11).
    while true; do
        # 'whiptail' est un outil qui crée des boîtes de dialogue interactives dans le terminal.
        # --title: Définit le titre de la boîte de dialogue du menu.
        # --menu: Indique que nous voulons un menu.
        # "Que souhaitez vous faire? ": C'est le texte de la question posée à l'utilisateur.
        # 20 90 10: Dimensions du menu (hauteur, largeur, nombre d'éléments visibles sans défilement).
        # Chaque paire de guillemets qui suit ("1" "➕ Créer un utilisateur") représente:
        #   - La valeur renvoyée si l'utilisateur choisit cette option (ex: "1").
        #   - Le texte affiché à côté de l'option dans le menu.
        # 3>&1 1>&2 2>&3: C'est une redirection complexe des descripteurs de fichiers pour que whiptail fonctionne correctement
        #                 avec la capture de la sortie dans la variable 'choice'.
        choice=$(whiptail --title "Administration du système" \
            --menu "Que souhaitez vous faire? " 20 100 10 \
            "1" "➕ Créer un utilisateur" \
            "2" "➖ Supprimer un utilisateur" \
            "3" "🌐 Changer l'IP" \
            "4" "🔐 Configurer le sudo" \
            "5" "🔑 Changer les droits" \
            "6" "💻 Configurer le SSH" \
            "7" "📡 Configurer un serveur DNS" \
            "8" "🔌 Configurer un serveur DHCP" \
            "9" "🗺️ Configurer le routage" \
            "10" "📁 Configurer un serveur FTP" \
            "11" "↩️ Retour au menu principal" \
            3>&1 1>&2 2>&3)

        # Vérifier si l'utilisateur a appuyé sur "Annuler" ou "Échap".
        # Dans ce cas, la variable 'choice' sera vide.
        if [[ -z "$choice" ]]; then
            # Si l'utilisateur annule ce sous-menu, on utilise 'return' pour sortir de cette fonction.
            # Cela rendra le contrôle au script appelant (main.sh dans ce cas).
            return
        fi

        # 'local result=0' initialise une variable pour stocker le code de retour des scripts exécutés.
        # 0 signifie succès, 1 signifie échec ou action non finalisée nécessitant une intervention.
        local result=0
        # 'case "$choice" in ... esac' est une structure de contrôle qui exécute différentes actions
        # en fonction de la valeur de la variable 'choice'.
        case "$choice" in
            1)
            # Rend le script 'createuser.sh' exécutable.
            chmod +x administration/scripts/createuser.sh
            # Exécute le script. '|| result=$?' capture le code de retour du script.
            # Si le script échoue (retourne un code d'erreur non nul), 'result' prendra cette valeur.
            bash administration/scripts/createuser.sh || result=$?
            ;;
            2)
            chmod +x administration/scripts/deluser.sh
            bash administration/scripts/deluser.sh || result=$?
            ;;
            3)
            chmod +x administration/scripts/changeIP.sh
            bash administration/scripts/changeIP.sh || result=$?
            ;;
            4)
            chmod +x administration/scripts/confsudo.sh
            bash administration/scripts/confsudo.sh || result=$?
            ;;
            5)
            chmod +x administration/scripts/changedroits.sh
            bash administration/scripts/changedroits.sh || result=$?
            ;;
            6)
            chmod +x administration/scripts/confssh.sh
            bash administration/scripts/confssh.sh || result=$?
            ;;
            7)
            chmod +x administration/scripts/confDNS.sh
            bash administration/scripts/confDNS.sh || result=$?
            ;;
            8)
            chmod +x administration/scripts/confDHCP.sh
            bash administration/scripts/confDHCP.sh || result=$?
            ;;
            9)
            chmod +x administration/scripts/routing.sh
            bash administration/scripts/routing.sh || result=$?
            ;;
            10)
            chmod +x administration/scripts/FTPconfig.sh
            bash administration/scripts/FTPconfig.sh || result=$?
            ;;
            11)
                # Lorsque l'option 11 est choisie, la commande 'return' est exécutée.
                # Cela met fin à l'exécution de la fonction 'menu_admin'.
                # Le contrôle du script est alors rendu à l'endroit où 'menu_admin' a été appelée.
                # Dans le cas de 'main.sh', cela reviendra à la fonction 'main_menu'.
                return # Retourne au menu principal
                ;;
            *)
                # Si l'utilisateur entre une option non valide, affiche une boîte de message d'erreur.
                whiptail --msgbox "Option invalide. Veuillez choisir une option valide dans le menu." 10 60
                ;;
        esac
        # Ce commentaire explique que si une erreur est survenue (result non nul),
        # le script continue la boucle pour réafficher le menu d'administration.
        # Cela donne l'occasion à l'utilisateur de faire un nouveau choix.
    done
}

# Fonction principale du script menu_administration.sh.
# Elle ne fait qu'appeler la fonction 'menu_admin'.
main(){
    menu_admin
}

# Lance la fonction 'main' au démarrage du script.
main