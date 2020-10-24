#! /bin/bash

scripts_path="$(cat /etc/odroid_cluster.conf | grep "SCRIPTS_DIR" | cut -d= -f2)"

# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

LOG_FILE=/var/log/dnsmasq.log
HOSTS_FILE=/etc/dnsmasq.d/dnsmasq_hosts.conf
name=$(cat /etc/odroid_cluster.conf | grep "HOSTS_NAME" | cut -d= -f2)

option=$1
mac=$2
ip=$3

get_date(){
	time="$1"

	if [ -z "$1" ]; then
	      echo $(date +"%d-%m-%y-%H-%M")
	else
	      echo $(date +"%d-%m-%y-%H-%M" -d "$time minutes")
	fi
	
}

# Funció per calcular els temps de sleep entre upgrade i upgrade
get_sleep_time() {
	time=0
	sleep_time=$(cat /etc/odroid_cluster.conf | grep "UPGRADE_SLEEP" | cut -d= -f2)

	if [ -f "${scripts_path}/last_upgrade" ]; then
		last=$(cat "${scripts_path}/last_upgrade")
		# Guardem el resultat en un array per treballar mes comodament
		IFS='-' read -a last_date <<< "$last"
		IFS='-' read -a act_date <<< $(get_date)

		# Mirem si el dia, mes i any guardats son els mateixos que lactual
		if [ "${last_date[0]}" -eq "${act_date[0]}" ] && [ "${last_date[1]}" -eq "${act_date[1]}" ] && [ "${last_date[2]}" -eq "${act_date[2]}" ]; then
			# Mirem si sha fet a la mateixa hora
			if [ "${last_date[3]}" -eq "${act_date[3]}" ]; then
				time=$(expr "${act_date[4]}" - "${last_date[4]}")
			else
				# Mirem si ha canviat d'hora
				if [ $(expr "${act_date[3]}" - "${last_date[3]}") -eq 1 ]; then
					time=$(expr 60 - "${last_date[4]}" + "${act_date[4]}")			
				fi
			fi
		else
			if[]; then
				if [ "${last_date[3]}" -eq 23 ] && [ "${act_date[3]}" -eq 0 ]; then
						time=$(expr 60 - "${last_date[4]}" + "${act_date[4]}")
				fi
			fi
		fi
	fi

	


	if [ "$time" -gt "$sleep_time" ]; then
		time=0
	else
		if [ "$time" -ne 0 ]; then
			if [ "$time" -lt "$sleep_time" ]; then
				time=$(expr "$time" - 1)
			fi
			time=$(expr "$sleep_time" - "$time")
		fi
	fi

	echo $(get_date "$time") > "${scripts_path}/last_upgrade"

	echo "$time"
}


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

		# Modifiquem el nombre de odroids al fitxer slurm.conf
		sed -i 's/'"$name"'\[1\-[0-9]*\]/'"$name"'\[1\-'"$num_line"'\]/g' /etc/slurm-llnl/slurm.conf
		# Fem un restart del dimoni slurmctld
		systemctl restart slurmctld

		# Assignem un hostname a una ip de forma temporal.
		# (Aquests canvis es realitzen automaticament)
		echo "${ip} ${name}${num_line}" >> /etc/hosts.d/tmp_hosts

		# Afegim el nou slave i l'inicialitzem
		nohup "${scripts_path}/add_slave.sh" "${name}${num_line}" "$name" "$(get_sleep_time)" >> /tmp/add_slave_"${name}${num_line}".out 2>&1 &

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
		add_odroid $@
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
