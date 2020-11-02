#!/bin/bash

scripts_path="$(cat /etc/odroid_cluster.conf | grep "^SCRIPTS_DIR=" | cut -d= -f2)"
upgrade_slave="$(cat /etc/odroid_cluster.conf | grep "^UPGRADE=" | cut -d= -f2)"

# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

# Evitem que es guardi el password al historial
export HISTIGNORE=$HISTIGNORE':*sudo -S*:*sshpass*'


default_password=$(cat /etc/odroid_cluster.conf | grep "^DEFAULT_PASSWORD=" | cut -d= -f2)
# Agafem el nom de l'usuari no root
user_name=$(cat /etc/odroid_cluster.conf | grep "^DEFAULT_USER=" | cut -d= -f2)
# Agafem el directori home l'usuari no root
user_home=$(eval echo "~$user_name")
upgrade_time=$(cat /etc/odroid_cluster.conf | grep "^UPGRADE_SLEEP=" | cut -d= -f2)

language=$(cat /etc/odroid_cluster.conf | grep "^SYS_LANGUAGE=" | cut -d= -f2)
layout=$(cat /etc/odroid_cluster.conf | grep "^LAYOUT=" | cut -d= -f2)
variant=$(cat /etc/odroid_cluster.conf | grep "^VARIANT=" | cut -d= -f2)
timezone=$(cat /etc/odroid_cluster.conf | grep "^SYS_TIMEZONE=" | cut -d= -f2)
default_host=$(cat /etc/odroid_cluster.conf | grep "^HOSTS_NAME=" | cut -d= -f2)
locale="$language;$layout;$variant;$timezone"

KEY_FILE="${user_home}/.ssh/id_rsa.pub"
KNOWN_HOSTS="${user_home}/.ssh/known_hosts"

host="$1" # $1 la ip del slave
passphrase="$2" # $4 passphrase



# Comprovem que es passi com a minim 1 parametre
if [ $# -lt 1 ]; then
	echo -e "Error, at least you have to enter 1 parameter, for more information \n\t add_slave -h"
	exit 1
fi

# Afegim el fingerprint al fitxer de hosts coneguts
su $user_name -c "echo \"$(ssh-keyscan -H $host)\" >> $KNOWN_HOSTS"

# Copiem la clau publica al slave
su $user_name -c "sshpass -p $default_password ssh-copy-id -i $KEY_FILE $user_name@$host"

# Copiem el script locale.sh dependencia de init_slave.sh
su $user_name -c "scp ${scripts_path}/locale.sh ${user_name}@${host}:Documents"

# Copiem el script de inicialització al slave
su $user_name -c "scp ${scripts_path}/init_slave.sh ${user_name}@${host}:Documents"

# Agafem la IP de la xarxa interna
interface="$(cat /etc/dnsmasq.conf | grep interface= | cut -d= -f2)"
master_ip="$(get_ip_of_nic $interface)"

# Executem el script de inicialització al slave
su $user_name -c "ssh -t ${user_name}@${host} \"echo ${default_password} | sudo -S ~/Documents/init_slave.sh $master_ip $upgrade_slave $upgrade_time $locale \" >> /var/log/odroid_cluster/init_slave_${host}.out 2>&1"


