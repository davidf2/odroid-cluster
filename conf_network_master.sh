#!/bin/bash

export PATH="$(dirname $0):${PATH}"

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source ./network_api.sh

# Default values
ip="172.16.0.1"
mask="255.255.255.0"
class="B"

while getopts ":i:m:n:" opt; do
  case ${opt} in
    -i) result=$(check_ip "$OPTARG")
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
		ip=$OPTARG
		shift
		;;

	-m)
		result=$(check_mask "$OPTARG" "$class")
		if [[ $? -ne 0 ]]; then
			exit 1
		fi
		mask=$OPTARG
		;;

	-n)
		interface2=$OPTARG
		;;
    \?)
		echo "Invalid option: $OPTARG" 1>&2
    	;;

    :)
		echo "Invalid option: $OPTARG requires an argument" 1>&2
		;;
  esac
done


if [[ -z "$interface" ]]; then
	result=$(check_interfaces)
	if [[ $? -ne 0 ]]; then 
		exit 1
	fi
	interface=$(echo $result | cut -d ";" -f 1)
	interface2=$(echo $result | cut -d ";" -f 2)
fi

echo "
auto $interface2
iface $interface2 inet static
    address $ip
    netmask $mask" > /etc/network/interfaces

echo "$ip master" >> /etc/hosts

line=$(cat /etc/hosts | grep 127.0.0.1)
host=$(echo $(who am i | awk '{print $1}'))
sed -i 's/^'"$line"'.*/'"$line"' '"$host"'/g' /etc/hosts

# Reiniciem la interficie de xarxa (xarxa interna)
ifdown $interface2
ifup $interface2

# Habilitem de forma permanent el forwarding, descomentant la linia pertinent
sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
# Carrega els canvis sense reiniciar
sysctl -p

# Habilitem el postrouitng a iptables per donar acces a internet a la xarxa interna
iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE

# Guardem els canvis a iptables de forma permanentment
bash -c "iptables-save > /etc/iptables/rules.v4"
bash -c "iptables-save > /etc/iptables/rules.v6"

# Retornem els resultats
echo "$ip;$mask;$interface;$interface2"

