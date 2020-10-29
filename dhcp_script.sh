#! /bin/bash

scripts_path="$(cat /etc/odroid_cluster.conf | grep "^SCRIPTS_DIR=" | cut -d= -f2)"

# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

LOG_FILE=/var/log/dnsmasq.log
HOSTS_FILE=/etc/dnsmasq.d/dnsmasq_hosts.conf
host_name=$(cat /etc/odroid_cluster.conf | grep "^HOSTS_NAME=" | cut -d= -f2)

option=$1
mac=$2
ip=$3

get_time(){
	expr $(date +%s) / 60
}

# Funció per calcular els temps de sleep entre upgrade i upgrade
get_sleep_time() {
        upgrade_time=$(cat /etc/odroid_cluster.conf | grep "^UPGRADE_SLEEP=" | cut -d= -f2)
        act_time=$(get_time)


        if [ -f "${scripts_path}/last_upgrade" ]; then
                end_time=$(cat "${scripts_path}/last_upgrade")
                sleep_time=$(expr $end_time - $act_time)

                if [ $end_time -gt $act_time ]; then
                        echo "$(expr $end_time + $upgrade_time)" > "${scripts_path}/last_upgrade"
                        echo "$sleep_time"
                else
                        echo "$(expr $act_time + $upgrade_time)" > "${scripts_path}/last_upgrade"
                        echo "0"
                fi
        else
                echo "$(expr $act_time + $upgrade_time)" > "${scripts_path}/last_upgrade"
                echo "0"
        fi
}


# Funció per afegir una nova odroid al fitxer de hosts i configurar-la
add_odroid() {
    if [[ ! $(cat $HOSTS_FILE | grep ^dhcp-host=$mac) ]]; then
		num_line=$(expr $(cat $HOSTS_FILE | grep ^dhcp-host | wc -l) + 1)

		# Assignem una ip i hostname fix a la nova MAC
		# (Aquests canvis nomes es produeixen al reiniciar dnsmasq)
		if [[ "$num_line" -gt $(cat $HOSTS_FILE | wc -l) ]]; then
			echo "dhcp-host=$mac,$host_name$num_line,$ip" >> $HOSTS_FILE
		else
			sed -i ''"$num_line"'i\dhcp-host='"$mac"','"$host_name"''"$num_line"','"$ip"'' $HOSTS_FILE
		fi

		# Modifiquem el nombre de odroids al fitxer slurm.conf
		sed -i 's/'"$host_name"'\[1\-[0-9]*\]/'"$host_name"'\[1\-'"$num_line"'\]/g' /etc/slurm-llnl/slurm.conf
		# Fem un restart del dimoni slurmctld
		systemctl restart slurmctld

		# Assignem un hostname a una ip de forma temporal.
		# (Aquests canvis es realitzen automaticament)
		echo "${ip} ${host_name}${num_line}" >> /etc/hosts.d/tmp_hosts

		# Afegim el nou slave i l'inicialitzem
		nohup "${scripts_path}/add_slave.sh" "${host_name}${num_line}"  "$(get_sleep_time)" >> /var/log/odroid_cluster/add_slave_"${host_name}${num_line}".out 2>&1 &

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
