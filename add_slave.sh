#!/bin/bash

if [ $(echo "$PATH" | grep "$(dirname $0)" | wc -l) -eq 0 ]; then
        export PATH="$(dirname $0):${PATH}"
fi

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_api.sh

# Evitem que es guardi el password al historial
export HISTIGNORE=$HISTIGNORE':*sudo -S*:*sshpass*'


default_password=$(cat /etc/urvcluster.conf | grep "DEFAULT_PASSWORD" | cut -d= -f2)
# Agafem el nom de l'usuari no root
master_name=$(cat /etc/urvcluster.conf | grep "DEFAULT_USER" | cut -d= -f2)
# Agafem el directori home l'usuari no root
master_home=$(eval echo "~$master_name")


KEY_FILE="${master_home}/.ssh/id_rsa"
KNOWN_HOSTS="${master_home}/.ssh/known_hosts"
default_password=$(cat /etc/urvcluster.conf | grep "DEFAULT_PASSWORD" | cut -d= -f2)

ip="$1" # $1 la ip del slave
name="$2" # $2 nom del slave
assigned_number="$3"
passphrase="$4" # $4 passphrase

# Comprovem que es passi com a minim 3 parametres
if [ $# -lt 3 ]; then
	echo -e "Error, at least you have to enter 3 parameters, for more information \n\t add_slave -h"
	exit 1
fi

# Si no existeixen generem el parell de claus
if [ ! -f "$KEY_FILE" ]; then
	su $master_name -c "ssh-keygen -q -t rsa -f \"$KEY_FILE\" -N \"$passphrase\""
fi

# Afegim el fingerprint al fitxer de hosts coneguts
su $master_name -c "echo \"$(ssh-keyscan -H $ip)\" >> $KNOWN_HOSTS"

# Copiem la clau publica al slave
su $master_name -c "sshpass -p $default_password ssh-copy-id -i $KEY_FILE $name@$ip"

# Copiem el script de inicialització al slave
su $master_name -c "sshpass -p ${default_password} scp \"$(dirname $0)\"/init_slave.sh ${name}@${ip}:Documents"

# Copiem la clau de munge
sshpass -p ${default_password} scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p -r /etc/munge/munge.key ${name}@${ip}:Documents/munge.key


# Agafem la IP de la xarxa interna
interface=$(cat /etc/dnsmasq.conf | grep interface= | cut -d= -f2)
master_ip=$(get_ip_of_nic "$interface")

# Executem el script de inicialització al slave
su $master_name -c "sshpass -p ${default_password} ssh -t ${name}@${ip} \"echo ${default_password} | sudo -S ~/Documents/init_slave.sh $master_ip $ip \" >> /tmp/init_slave.out 2>&1"


