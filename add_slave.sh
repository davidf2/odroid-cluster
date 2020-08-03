#!/bin/bash


# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source ./network_api.sh

# Evitem que es guardi el password al historial
export HISTIGNORE=$HISTIGNORE':*sudo -S*:*sshpass*'

# Agafem el nom de l'usuari no root
master_name=$(echo $(who am i | awk '{print $1}'))
# Agafem el directori home l'usuari no root
master_home=$(eval echo "~$master_name")


KEY_FILE="${master_home}/.ssh/id_rsa"
KNOWN_HOSTS="${master_home}/.ssh/known_hosts"
default_password=$(cat /etc/urvcluster.conf | grep "DEFAULT_PASSWORD" | cut -d= -f2)

ip="$1" # $1 la ip del slave
name="$2" # $2 nom del slave
assigned_number="$3"
passphrase="$4" # $4 passphrase

add_cron_job() {

	name="$1"
	ip="$2"
	master_name="$3"
	master_home="$4"

	line="*/1 * * * * root $(dirname $0)/cron_init_slave.sh $name $ip $master_name $master_home >> /tmp/cron_init_slave.log 2>&1"

	# Si no existeix creem el fitxer crontab, propietat de root i amb permisos limitats
	if [ ! -f /etc/crontab ]; then
		touch /etc/crontab
		chmod 644 /etc/crontab
		chown root: /etc/crontab
	fi

	echo "$line" >> /etc/crontab
}

# Comprovem que es passi com a minim 3 parametres
if [ $# -lt 3 ]; then
	echo -e "Error, at least you have to enter 3 parameters, for more information \n\t add_slave -h"
	exit 1
fi

# Si no existeixen generem el parell de claus
if [ ! -f "$KEY_FILE" ]; then
	ssh-keygen -q -t rsa -f "$KEY_FILE" -N "$passphrase"
	# Modifiquem l'usuari propietari a odroid i com a grup el seu grup primari
	chown "$master_name":$(id -gn "$master_name") $KEY_FILE
fi

# Afegim el fingerprint al fitxer de hosts coneguts
echo "$(ssh-keyscan -H $ip)" >> $KNOWN_HOSTS
# Modifiquem l'usuari propietari a odroid i com a grup el seu grup primari
chown "$master_name":$(id -gn "$master_name") $KNOWN_HOSTS

# Copiem la clau publica al slave
su $name -c "sshpass -p $default_password ssh-copy-id -i $KEY_FILE $name@$ip"


# Copiem la clau de munge
sshpass -p ${default_password} scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p -r /etc/munge/munge.key ${ip}:/etc/munge/munge.key

if [ "$?" -gt 0 ]; then
	echo "Error: The munge key could not be copied to the host odroid${assigned_number}, this could
	be due to the fact that the default password of the root user of
	odroid${assigned_number} has been changed, or access to its ssh server has been
	blocked by root."
	# Copiem la clau al directori home
	dd if=/etc/munge/munge.key of=/home/munge.key 
fi

echo "Copiant script al slave"
su $master_name -c "sshpass -p ${default_password} scp init_slave.sh ${name}@${ip}:Documents"

add_cron_job "$name" "$ip" "$master_name" "$master_home"
