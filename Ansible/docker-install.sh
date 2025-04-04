#! /bin/bash

#Script Installation de Docker
echo "#######################"
echo "Debut de l'installation"
echo "#######################"

#Désinstaller tous les packages en conflit avec docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

#Mise à jour de la liste des paquets
echo "Mise à jour de la liste des paquets..."
apt-get update -y

#Installation des dépendances nécessaires
echo "Installation des dépendances nécessaires..."
apt-get install -y ca-certificates curl

#Création du répertoire pour les clés GPG d'APT
echo "Création du répertoire pour les clés GPG..."
install -m 0755 -d /etc/apt/keyrings

#Téléchargement de la clé GPG officielle de Docker
echo "Téléchargement de la clé GPG de Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

#Modification des permissions de la clé GPG
echo "Modification des permissions de la clé GPG..."
chmod a+r /etc/apt/keyrings/docker.asc

#Ajout du dépôt Docker aux sources Apt
echo "Ajout du dépôt Docker aux sources Apt..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

#Mise à jour de la liste des paquets avec le nouveau dépôt
echo "Mise à jour de la liste des paquets avec le dépôt Docker..."
apt-get update -y

echo "Clé GPG officielle de Docker ajoutée et dépôt Docker configuré avec succès."

#Installez les packages Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#Ajouter l'utilisateur actuel dans le groupe docker
sudo usermod -aG docker $USER

#Changer les droits de docker.sock
sudo chmod 777 /var/run/docker.sock

echo "#######################"
echo "Fin de L'installation"
echo "#######################"