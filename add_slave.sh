#!/bin/bash

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source ./network_api.sh

# Evitem que es guardi el password al historial
export HISTIGNORE='*sudo -S*'

# Agafem el nom de l'usuari no root
user=$(echo $(who am i | awk '{print $1}'))
# Agafem el directori home l'usuari no root
master_home=$(eval echo "~$user")

echo $user
#echo $master_home
KEY_FILE="${master_home}/.ssh/id_rsa"
KNOWN_HOSTS="${master_home}/.ssh/known_hosts"

host="$1" # $1 la ip del slave
name="$2" # $2 nom del slave
password="$3" # $3 password per defecte del slave
passphrase="$4" # $4 passphrase


# Comprovem que es passi com a minim 3 parametres
if [ $# -lt 3 ]; then
	echo -e "Error, at least you have to enter 3 parameters, for more information \n\t add_slave -h"
	exit 1
fi

# Si no existeixen generem el parell de claus
if [ ! -f "$KEY_FILE" ]; then
	ssh-keygen -q -t rsa -f "$KEY_FILE" -N "$passphrase"
	# Modifiquem l'usuari propietari a odroid i com a grup el seu grup primari
	chown "$user":$(id -gn "$user") $KEY_FILE
fi

# Afegim el fingerprint al fitxer de hosts coneguts
echo "$(ssh-keyscan -H $host)" >> $KNOWN_HOSTS
# Modifiquem l'usuari propietari a odroid i com a grup el seu grup primari
chown "$user":$(id -gn "$user") $KNOWN_HOSTS

# Copiem la clau publica al slave
sshpass -p $password ssh-copy-id -i $KEY_FILE $name@$host

# Agafem la IP de la xarxa interna
interface=$(cat /etc/dnsmasq.conf | grep interface= | cut -d= -f2)
master_ip=$(get_ip_of_nic "$interface")

echo "Copiant script al slave"
sshpass -p $password scp init_slave.sh "${name}@${host}:Documents"

echo "Afegint excpeció a /etc/password"
sshpass -p $password ssh -t "${name}@${host}" " echo $password | sudo -S -k $(echo '${name} ALL=(ALL) NOPASSWD:/home/${name}/Documents/init_slave.sh' >> /etc/sudoers)"

echo "Executant script de inicialització"
# Executem el script que configura el slave mitjançant ssh, primera conexió com a root
sshpass -p $password ssh -t "${name}@${host}" " ~/Documents/init_slave.sh ${master_ip} ${master_home}"

