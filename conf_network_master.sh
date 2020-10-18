#!/bin/bash


# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

# Default values
ip="172.16.0.1"
mask="255:255:255:0"
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
		lan_interface=$OPTARG
		;;
    \?)
		echo "Invalid option: $OPTARG" 1>&2
    	;;

    :)
		echo "Invalid option: $OPTARG requires an argument" 1>&2
		;;
  esac
done

line=$(cat /etc/hosts | grep 127.0.0.1)
host=$(hostname)
host2=$(echo $(who am i | awk '{print $1}'))
sed -i 's/^'"$line"'.*/'"$line"' '"$host"' '"$host2"'/g' /etc/hosts

result=$(check_interfaces)

if [[ $? -ne 0 ]]; then 
	exit 1
fi

net_interface=$(echo $result | cut -d ";" -f 1)
lan_interface=$(echo $result | cut -d ";" -f 2)

echo "
auto $lan_interface
iface $lan_interface inet static
    address $ip
    netmask ${mask//:/.}
auto $net_interface
iface $net_interface inet dhcp" > /etc/network/interfaces

echo "$ip master" >> /etc/hosts.d/lan_hosts

# Afegim la interficie de xarxa lan al fitxer /run/network/ifstate
if [ ! $(cat /run/network/ifstate | grep "$lan_interface") ]; then
	echo "$lan_interface=$lan_interface" >> /run/network/ifstate
fi
# Afegim la interficie de xarxa internet al fitxer /run/network/ifstate
if [ ! $(cat /run/network/ifstate | grep "$net_interface") ]; then
	echo "$net_interface=$net_interface" >> /run/network/ifstate
fi

# Reiniciem la interficie de xarxa (xarxa interna)
ifdown --force $lan_interface
ifup --force $lan_interface

# Habilitem de forma permanent el forwarding, descomentant la linia pertinent
sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
# Carrega els canvis sense reiniciar
sysctl -p

# Habilitem el postrouitng a iptables per donar acces a internet a la xarxa interna
iptables -t nat -A POSTROUTING -o $net_interface -j MASQUERADE
sleep 1

# Guardem els canvis a iptables de forma permanentment
iptables-save > /etc/iptables/rules.v4
iptables-save > /etc/iptables/rules.v6

systemctl restart netfilter-persistent
systemctl enable netfilter-persistent

# Retornem els resultats
echo "$ip;$mask;$net_interface;$lan_interface"

