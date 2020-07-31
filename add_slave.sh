#!/bin/bash

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source ./network_api.sh

# Evitem que es guardi el password al historial
export HISTIGNORE=$HISTIGNORE':*sudo -S*:*sshpass*'


# Agafem el nom de l'usuari no root
user=$(echo $(who am i | awk '{print $1}'))
# Agafem el directori home l'usuari no root
master_home=$(eval echo "~$user")

echo $user
echo $master_home
KEY_FILE="${master_home}/.ssh/id_rsa"
KNOWN_HOSTS="${master_home}/.ssh/known_hosts"

ip="$1" # $1 la ip del slave
name="$2" # $2 nom del slave
password="$3" # $3 password per defecte del slave
assigned_number="$4"
passphrase="$5" # $4 passphrase


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
echo "$(ssh-keyscan -H $ip)" >> $KNOWN_HOSTS
# Modifiquem l'usuari propietari a odroid i com a grup el seu grup primari
chown "$user":$(id -gn "$user") $KNOWN_HOSTS

# Copiem la clau publica al slave
su $name -c "sshpass -p $password ssh-copy-id -i $KEY_FILE $name@$ip"

# Agafem la IP de la xarxa interna
interface=$(cat /etc/dnsmasq.conf | grep interface= | cut -d= -f2)
master_ip=$(get_ip_of_nic "$interface")

# Copiem la clau de munge
sshpass -p ${password} scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p -r /etc/munge/munge.key ${ip}:/etc/munge/munge.key

if [ "$?" -gt 0 ]; then
	echo "Error: The munge key could not be copied to the host odroid${assigned_number}, this could
	be due to the fact that the default password of the root user of
	odroid${assigned_number} has been changed, or access to its ssh server has been
	blocked by root."
	# Copiem la clau al directori home
	dd if=/etc/munge/munge.key of=/home/munge.key 
fi

echo "Copiant script al slave"
su $user -c "sshpass -p ${password} scp init_slave.sh ${name}@${ip}:Documents"

echo "Executant script de inicialització"
# Executem el script que configura el slave mitjançant ssh, primera conexió com a root
su $user -c "sshpass -p ${password} ssh -t ${name}@${ip} \"echo ${password} | sudo -S Documents/init_slave.sh $master_ip $master_home \""

