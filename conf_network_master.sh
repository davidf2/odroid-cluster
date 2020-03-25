#!/bin/bash

# Default values
ip="172.16.0.1"
mask="255:255:0:0"
class="B"


checkIP() {

	result="P"

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
			result="A"
		;;

		172)
			if [[ $(echo $1 | cut -d "." -f 2) -ge 16 ]] && [[ $(echo $1 | cut -d "." -f 2) -le 31 ]]; then
				result="B"
			fi
		;;

		192)
			if [[ $(echo $1 | cut -d "." -f 2) -eq 168 ]]; then
				result="C"
			fi
		;;

	esac
	
	echo $result
}

checkMask() {

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

# El primer parametre retorna la interficie de xarxa amb connexio a internet
checkInterfaces() {
	OLDIFS=$IFS
	IFS=$'\t'
	# !!! En comptes d'instalar net-tools podria treure els noms del fitxer /proc/net/dev !!!
	# Cerca la NIC amb connexió a internet
	for nic in $(echo $(nmcli device status) | grep " connected " | awk '{print $1}'); do
		if [[ $(ping 8.8.8.8 -I $nic -w2 | grep "received" | cut -d " " -f4) -gt 0 ]]; then
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

while [ -n "$1" ]; do # Mentres $1 no sigui null 

	case "$1" in

	-i) result=$(checkIP "$2")
		if [[ $? -ne 0 ]]; then
			exit 1
		fi
		case "$result" in
			A) echo "Class A private IP";;
			B) echo "Class B private IP";;
			C) echo "Class C private IP";;
			P) echo "ERROR: Cannot put a public IP" 1>&2
				exit 1 ;;
		esac
		class=$result
		ip=$2
		shift
		;;

	-m)
		result=$(checkMask "$2" "$class")
		if [[ $? -ne 0 ]]; then
			exit 1
		fi
		mask=$2
		shift
		;;

	-n)
		interface=$2
		shift
		;;

	*) echo "Option $1 not recognized" ;;

	esac

	shift # Desplaça $# cap a l'esquerra $1 -> $2 ...

done


apt install net-tools -y

if [[ -z "$interface" ]]; then
	result=$(checkInterfaces)
	if [[ $? -ne 0 ]]; then 
		exit 1
	fi
	interface=$(echo $result | cut -d ";" -f 1)
	interface2=$(echo $result | cut -d ";" -f 2)
fi

echo "The interface selected to the internet is $interface"


#DESCOMENTAR CUANDO ESTE HECHO
<< 'MULTILINE-COMMENT'
echo "
auto $interface
iface $interface inet static
    address $ip
    netmask $mask" > /etc/network/interfaces

# Habilitar forwarding, descomentant la linia pertinent
sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sysctl -p

MULTILINE-COMMENT

echo "$ip $mask"

