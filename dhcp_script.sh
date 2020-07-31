#! /bin/bash

LOG_FILE=/var/log/dnsmasq.log
HOSTS_FILE=/etc/dnsmasq.d/dnsmasq_hosts.conf
NAME="odroid"
DEFAULT_PASSWORD="odroid"

option=$1
mac=$2
ip=$3

# Funció per afegir una nova odroid al fitxer de hosts i configurar-la
add_odroid() {
    if [[ ! $(cat $HOSTS_FILE | grep ^dhcp-host=$mac) ]]; then
		num_line=$(expr $(cat $HOSTS_FILE | grep ^dhcp-host | wc -l) + 1)
		if [[ "$num_line" -gt $(cat $HOSTS_FILE | wc -l) ]]; then
			echo "dhcp-host=$mac,$NAME$num_line,$ip" >> $HOSTS_FILE
		else
			sed -i ''"$num_line"'i\dhcp-host='"$mac"','"$NAME"''"$num_line"','"$ip"'' $HOSTS_FILE
		fi

		bash -c './add_slave.sh "$ip" "$NAME"  "$DEFAULT_PASSWORD" "$num_line" >/dev/null 2>&1 & disown'

		if [ -f /var/run/dnsmasq/dnsmasq.pid ]; then
			pid=$(cat /var/run/dnsmasq/dnsmasq.pid)
		else
			pid=$(pgrep -f dnsmasq | head -n1)
			if [ -z "$pid"]; then
				echo -e "Error: Could not get PID from dnsmasq, make sure it is running with 
						\tsystemctl start dnsmasq\nor installed with \n\tapt-get install dnsmasq"
			fi
		fi

		# Enviem senyal SIGKILL al proces per a que reinicii el dimoni
		# 	i d'aquesta manera llegeixi inmediatament el fitxer de hosts especificat
		kill -9 "$pid"
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
