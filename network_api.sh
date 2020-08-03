#! /bin/bash


# Funció per controlar que una IP estigui en un format correcte
check_ip() {

	result="P" # IP publica

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
		;;

		172)
			if [[ $(echo $1 | cut -d "." -f 2) -ge 16 ]] && [[ $(echo $1 | cut -d "." -f 2) -le 31 ]]; then
				result="B" # IP privada de classe B
			fi
		;;

		192)
			if [[ $(echo $1 | cut -d "." -f 2) -eq 168 ]]; then
				result="C" # IP privada de classe C
			fi
		;;

	esac
	
	echo $result
}

# Funció per controlar que la mascara de xarxa sigui correcta
check_mask() {

	result="true"

	if [[ $(echo $1 | grep [^0-9:]) ]]; then
		echo "ERROR: Incorrect mask format, can only contain numbers and colons" 1>&2
		return 1
	fi

	if [[ $(echo $1 | awk -F':' '{print NF}') -ne 4 ]]; then
		echo "ERROR: Incorrect mask format, incorrect octets number" 1>&2
		return 1
	fi

	case $2 in
		A) min=1;;
		B) min=2;;
		C) min=2;;
	esac

	octet=1
	while [ $(echo $1 | cut -d ":" -f $octet) ]; do
		if [[ $octet -le $min ]]; then
			if [[ $(echo $1 | cut -d ":" -f $octet) -ne 255 ]]; then
				echo "ERROR: Incorrect mask format" 1>&2
				return 1
			fi
		else
			if [[ $(echo $1 | cut -d ":" -f $octet) -lt 0 ]] || [[ $(echo $1 | cut -d ":" -f $octet) -gt 255 ]]; then
				echo "ERROR: Incorrect mask format" 1>&2
				return 1
			fi
		fi
		let octet=octet+1
	done

	echo $result
}

# El primer parametre retorna la interficie de xarxa amb connexió a internet
check_interfaces() {
	OLDIFS=$IFS
	IFS=$' \t\n'
	# Cerca la NIC amb connexió a internet
	for nic in $(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1)); do
		if [[ $(ping 8.8.8.8 -I $nic -w2 2> /dev/null | grep "received" | cut -d " " -f4) -gt 0 ]]; then
			interface="$nic"
		else
			interface2="$nic"
		fi
	done
	IFS=$OLDIFS

	# Comprovació final
	if [[ -z "$interface" ]]; then
		echo "ERROR: No internet connected interfaces found" 1>&2
		return 1
	fi

	# Comprovació final
	if [[ -z "$interface2" ]]; then
		echo "ERROR: Not found the second network interface" 1>&2
		return 1
	fi

	echo "$interface;$interface2"
}

# Funció que retorna una ip, segons una interficie de xarxa pasada per parametre.
get_ip_of_nic() {
	
	if [ $# -lt 1 ]; then
		echo "Error, you have to enter 1 parameter corresponding to the network interface."
		exit 1
	fi

	interface="$1"

	nic_info=$(ip -4 a show $interface)
	nic_ip=""

	OLDIFS=$IFS
	IFS=$' '
	for ip in $(echo $(hostname -I)); do
		if [ $(echo "$nic_info" | grep "$ip" | wc -l) -gt 0 ]; then
			nic_ip="$ip"
		fi
	done
	IFS=$OLDIFS

	if [ -z $nic_ip ]; then
		echo "Error: The ip assigned to the interface ${interface} was not found"
		exit 1
	fi

	echo "$nic_ip"
}


mask_to_cidr() {

	if [ $# -lt 1 ]; then
		echo "Error, you have to enter 1 parameter corresponding to the mask."
		exit 1
	fi
	mask="$1"

	result=$(check_mask "$mask")

	if [[ $result == "true" ]]; then
		result=0
		IFS=':' read -a mask_array <<< "$mask"

		for i in "${mask_array[@]}"; do
		   number=$(echo "obase=2;${i}" | bc | awk -F "1" '{print NF-1}')
		   result=$(($result + $number))
		done

	else
		exit 1
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

	if [[ $(echo $ip | grep [^0-9.]) ]]; then
		echo "ERROR: Incorrect IP format, can only contain numbers and dots" 1>&2
		return 1
	fi

	if [[ $(echo $1ip| awk -F'.' '{print NF}') -ne 4 ]]; then
		echo "ERROR: Incorrect IP format, incorrect octets number" 1>&2
		return 1
	fi


	result=$(check_mask "$mask")

	if [[ $result == "true" ]]; then
		IFS=':' read -a mask_array <<< "$mask"
		IFS='.' read -a ip_array <<< "$ip"

		if [ ${#mask_array[@]} -ne 4 ] && [ ${#ip_array[@]} -ne 4 ]; then
			echo "Error, the IP or mask entered by parameter must contain 4 octets each"
			exit 1
		fi
		result=""
		i=0
		for octet in "${ip_array[@]}"; do
			result="$result$(($octet & mask_array[$i]))"
			i=$(($i + 1))
			if [ $i -lt ${#mask_array[@]} ]; then
				result=$result"."
			fi
			
		done

	else
		exit 1
	fi

	echo $result
}
