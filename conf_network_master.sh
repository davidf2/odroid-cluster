#!/bin/bash


# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh

add_iptables() {
	net_interface="$1"
	lan_interface="$2"
	path="$3"

	# Configurem les iptables
	"$path"/iptables.sh "$lan_interface" "$net_interface"
	sleep 1
	# Guardem els canvis a iptables de forma permanentment
	iptables-save > /etc/iptables/rules.v4
	iptables-save > /etc/iptables/rules.v6

	systemctl enable netfilter-persistent
	systemctl restart netfilter-persistent
}

# Default values
ip=$(cat /etc/odroid_cluster.conf | grep "^IP=" | cut -d= -f2)
mask=$(cat /etc/odroid_cluster.conf | grep "^MASK=" | cut -d= -f2)
class=$(cat /etc/odroid_cluster.conf | grep "^IP_CLASS=" | cut -d= -f2)
scripts_path="$(cat /etc/odroid_cluster.conf | grep "^SCRIPTS_DIR=" | cut -d= -f2)"

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

echo "auto lo
iface lo inet loopback

auto ${lan_interface}
iface ${lan_interface} inet static
    address ${ip}
    netmask ${mask//:/.}

auto ${net_interface}
iface ${net_interface} inet dhcp" > /etc/network/interfaces

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

add_iptables "$net_interface" "$lan_interface" "$scripts_path"

# Retornem els resultats
echo "$ip;$mask;$net_interface;$lan_interface"

