#! /bin/bash


# Funció per controlar que una IP estigui en un format correcte
check_ip() {

	if [[ $(echo $1 | grep [^0-9.]) ]]; then
		echo "ERROR: Incorrect IP format, can only contain numbers and dots" 1>&2
		return 1
	fi

	if [[ $(echo $1 | awk -F'.' '{print NF}') -ne 4 ]]; then
		echo "ERROR: Incorrect IP format, incorrect octets number" 1>&2
		return 1
	fi

	if [[ $(echo $1 | cut -d "." -f 4) -eq 255 ]]; then
		echo "ERROR: You cannot put broadcast address as the master's IP" 1>&2
		return 1
	fi

	octet=1
	while [ $(echo $1 | cut -d "." -f $octet) ]; do
		if [[ $(echo $1 | cut -d "." -f $octet) -lt 0 ]] || [[ $(echo $1 | cut -d "." -f $octet) -gt 255 ]]; then
			echo "ERROR: Incorrect IP format $(echo $1 | cut -d "." -f $octet)" 1>&2
			return 1
		fi
		let octet=octet+1
	done

	case $(echo $1 | cut -d "." -f 1) in
		10)
			result="A" # IP privada de classe A
			return 0
		;;

		172)
			if [[ $(echo $1 | cut -d "." -f 2) -ge 16 ]] && [[ $(echo $1 | cut -d "." -f 2) -le 31 ]]; then
				return 0
			fi
		;;

		192)
			if [[ $(echo $1 | cut -d "." -f 2) -eq 168 ]]; then
				return 0
			fi
		;;

	esac
	
	return 1
}

# Funció per controlar que la mascara de xarxa sigui correcta
check_mask() {

	mask=$1
	class=$(cat /etc/odroid_cluster.conf | grep "^IP_CLASS=" | cut -d= -f2)

	if [[ $(echo $mask | grep [^0-9:]) ]]; then
		echo "ERROR: Incorrect mask format, can only contain numbers and colons" 1>&2
		return 1
	fi

	if [[ $(echo $mask | awk -F':' '{print NF}') -ne 4 ]]; then
		echo "ERROR: Incorrect mask format, incorrect octets number" 1>&2
		return 1
	fi

	case $class in
		A) min=1;;
		B) min=2;;
		C) min=2;;
	esac

	octet=1
	while [ $(echo $mask | cut -d ":" -f $octet) ]; do
		if [[ $octet -le $min ]]; then
			if [[ $(echo $1 | cut -d ":" -f $octet) -ne 255 ]]; then
				echo "ERROR: Incorrect mask format" 1>&2
				return 1
			fi
		else
			if [[ $(echo $mask | cut -d ":" -f $octet) -lt 0 ]] || [[ $(echo $mask | cut -d ":" -f $octet) -gt 255 ]]; then
				echo "ERROR: Incorrect mask format" 1>&2
				return 1
			fi
		fi
		let octet=octet+1
	done

}

# El primer parametre retorna la interficie de xarxa amb connexió a internet
check_interfaces() {
	iptables -t nat -D POSTROUTING 1
	OLDIFS=$IFS
	IFS=$' \t\n'
	# Cerca la NIC amb connexió a internet
	for nic in $(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1)); do
		if [[ $(ping 8.8.8.8 -I $nic -w2 2> /dev/null | grep "received" | cut -d " " -f4) -gt 0 ]]; then
			net_interface="$nic"
		else
			lan_interface="$nic"
		fi
	done
	IFS=$OLDIFS

	# Comprovació final
	if [[ -z "$net_interface" ]]; then
		echo "ERROR: No internet connected interfaces found" 1>&2
		return 1
	fi

	# Comprovació final
	if [[ -z "$lan_interface" ]]; then
		echo "ERROR: Not found the second network interface" 1>&2
		return 1
	fi

	echo "$net_interface;$lan_interface"
}

# Funció que retorna una ip, segons una interficie de xarxa pasada per parametre.
get_ip_of_nic() {
	
	if [ $# -lt 1 ]; then
		echo "Error, you have to enter 1 parameter corresponding to the network interface."
		exit 1
	fi

	interface="$1"

	
	nic_ip=""


	nic_info=$(ip -4 a show $interface)

	OLDIFS=$IFS
	IFS=$' '
	for ip in $(echo $(hostname -I)); do
		if [ $(echo "$nic_info" | grep "$ip" | wc -l) -gt 0 ]; then
			nic_ip="$ip"
		fi
	done
	IFS=$OLDIFS


	if [ "$nic_ip" == "" ]; then
		return 1
	fi

	echo "$nic_ip"
}


mask_to_cidr() {

	if [ $# -lt 1 ]; then
		echo "Error, you have to enter 1 parameter corresponding to the mask."
		exit 1
	fi
	mask="$1"

	check_mask "$mask"
	result=$?

	if [[ $result -eq 0 ]]; then
		result=0
		IFS=':' read -a mask_array <<< "$mask"

		for i in "${mask_array[@]}"; do
		   number=$(echo "obase=2;${i}" | bc | awk -F "1" '{print NF-1}')
		   result=$(($result + $number))
		done

	else
		return 1
	fi

	echo "/$result"
}


calculate_network_ip() {
	
	if [ $# -lt 2 ]; then
		echo "Error, you must enter 2 parameters, the first one corresponding to 
		an IP and the second one to the mask"
		exit 1
	fi
	ip="$1"
	mask="$2"

	
	check_ip "$ip"
	result1=$?
	check_mask "$mask"
	result2=$?

	if [ "$result1" -eq 0 ] && [ "$result2" -eq 0 ]; then
		IFS=. read -r i1 i2 i3 i4 <<< "$ip"
		IFS=: read -r m1 m2 m3 m4 <<< "$mask"
		result=$(echo "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$((i4 & m4))")
	else
		return 1
	fi

	echo $result
}

calculate_first_ip() {
	
	if [ $# -lt 2 ]; then
		echo "Error, you must enter 2 parameters, the first one corresponding to 
		an IP and the second one to the mask"
		exit 1
	fi
	ip="$1"
	mask="$2"

	check_ip "$ip"
	result1=$?

	check_mask "$mask"
	result2=$?

	if [ "$result1" -eq 0 ] && [ "$result2" -eq 0 ]; then
		IFS=. read -r i1 i2 i3 i4 <<< "$ip"
		IFS=: read -r m1 m2 m3 m4 <<< "$mask"
		result=$(echo "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$(((i4 & m4)+1))")
	else
		return 1
	fi

	echo $result
}

calculate_last_ip() {
	
	if [ $# -lt 2 ]; then
		echo "Error, you must enter 2 parameters, the first one corresponding to 
		an IP and the second one to the mask"
		exit 1
	fi
	ip="$1"
	mask="$2"

	check_ip "$ip"
	result1=$?
	check_mask "$mask"
	result2=$?

	if [ "$result1" -eq 0 ] && [ "$result2" -eq 0 ]; then
		IFS=. read -r i1 i2 i3 i4 <<< "$ip"
		IFS=: read -r m1 m2 m3 m4 <<< "$mask"
		result=$(echo "$((i1 & m1 | 255-m1)).$((i2 & m2 | 255-m2)).$((i3 & m3 | 255-m3)).$(((i4 & m4 | 255-m4)-1))")
	else
		return 1
	fi

	echo $result
}