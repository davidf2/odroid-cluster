#! /bin/bash

# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

LOG_FILE=/var/log/dnsmasq.log
HOSTS_FILE=/etc/dnsmasq.d/dnsmasq_hosts.conf
name=$(cat /etc/urvcluster.conf | grep "HOSTS_NAME" | cut -d= -f2)

option=$1
mac=$2
ip=$3

# Funció per afegir una nova odroid al fitxer de hosts i configurar-la
add_odroid() {
    if [[ ! $(cat $HOSTS_FILE | grep ^dhcp-host=$mac) ]]; then
		num_line=$(expr $(cat $HOSTS_FILE | grep ^dhcp-host | wc -l) + 1)

		# Assignem una ip i hostname fix a la nova MAC
		# (Aquests canvis nomes es produeixen al reiniciar dnsmasq)
		if [[ "$num_line" -gt $(cat $HOSTS_FILE | wc -l) ]]; then
			echo "dhcp-host=$mac,$name$num_line,$ip" >> $HOSTS_FILE
		else
			sed -i ''"$num_line"'i\dhcp-host='"$mac"','"$name"''"$num_line"','"$ip"'' $HOSTS_FILE
		fi

		# Assignem un hostname a una ip de forma temporal.
		# (Aquests canvis es realitzen automaticament)
		echo "${ip} ${name}${num_line}" >> /etc/hosts.d/tmp_hosts

		# Afegim el nou slave i l'inicialitzem
		nohup add_slave.sh "${name}${num_line}" "$name" >> /tmp/add_slave_"${name}${num_line}".out 2>&1 &

    fi
}


# Funció per esborrar una odroid del fitxer de hosts
delete_odroid() {
	sed -i '/'"$mac"'/d' /var/lib/misc/dnsmasq.leases
	#sed '/^$/d' /var/lib/misc/dnsmasq.leases # Esborra linies buides
	sed -i '/'"$mac"'/d' $HOSTS_FILE
	#sed '/^$/d' $HOSTS_FILE # Esborra linies buides
}

# Funció per afegir una nova entrada al fitxer de log
save_log() {
	echo $(date) >> $LOG_FILE
	echo $@ >> $LOG_FILE
	echo >> $LOG_FILE
}

if [[ ! -f $HOSTS_FILE ]]; then
	touch $HOSTS_FILE
fi

save_log $@

case "$option" in

	add)
		add_odroid $@
	;;

	old)
		# Si no esta al fitxer de hosts l'afegim
		if [[ ! $(grep "$mac" $HOSTS_FILE) ]]; then
			add_odroid $@
		#else
			# Si esta al fitxer de hosts pero no te la ip correcta
			#if [[ $(grep "$mac" $HOSTS_FILE | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}') != $ip ]]; then
			#	sed -i '/'"$mac"'/d' $HOSTS_FILE
			#	add_odroid $@
			#	systemctl restart dnsmasq
			#fi

		fi
	;;

	del)
		#delete_odroid $@
	;;

	-h|--help)
		echo "Dnsmasq sends the following parameters in this order:
	\$1 = Action to take, which can be: add, old, del
	\$2 = mac address
	\$3 = IP address
	\$4 = Assigned name 

Of the above, this script only uses the first 3, to assign
the IPs to the hosts statically and give them a name."
	;;
	*)
		echo "Incorrect option" 1>&2
		exit 1
	;;
esac
