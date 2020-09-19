#!/bin/bash

add_resolvconf() {

	dns_ip="$1"

	# Instal.lem el dimoni resolvconf
	apt-get install resolvconf -y

	# Habilitem i reiniciem el dimoni de resolvconf
	systemctl enable resolvconf
	systemctl start resolvconf

	# Copiem el contingut de original a tail, per a que renovi el contingut
	echo "nameserver ${dns_ip}" > /etc/resolvconf/resolv.conf.d/head

	# Actualitzem els DNS
	resolvconf --enable-updates
	resolvconf -u
}

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

if [ $# -ne 1 ]; then
	echo "Error, you must enter one parameter, corresponding to the IP or host of the master"
	exit 1
fi

master_ip="$1" # $1 ip del master a la lan odroid

nic=$(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1))

if [ -z "$nic" ]; then
      echo "Error, no NIC found"
      exit 1
fi

# Bucle de espera, per assegurarnos de que la resolució de noms està funcionant correctament
while [[ $(ping 8.8.8.8 -I "$nic" -w2 2> /dev/null | grep "received" | cut -d " " -f4) -eq 0 ]]; do
	sleep 2
done

# Fixem com a DNS el master
echo "nameserver ${master_ip}" > /etc/resolv.conf
# Instal.lem el dimoni resolvconf
add_resolvconf "$master_ip"

# Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone Europe/Madrid
ntpdate -u hora.roa.es

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

# Actualitzem
apt-get update -y

# Desactivem autentificació mitjançant usuari root
#sed -i 's/PermitRootLogin yes.*/PermitRootLogin no/' /etc/ssh/sshd_config
#systemctl restart sshd

#  Esborrem software innecessari
apt-get remove --purge libreoffice* thunderbird pacman transmission* -y
apt autoremove -y
apt autoclean -y

# Instal.lem el client NFS
apt-get install nfs-common -y

# Instal.lem munge
apt-get install munge -y
systemctl enable --now munge


cp -p ~/Documents/munge.key /etc/munge && rm ~/Documents/munge.key
chown munge:munge /etc/munge/munge.key
systemctl restart munge

host_name=$(hostnamectl | grep Transient | awk '{print $3}')
if [ -z "$host_name" ]; then
	host_name=$(hostnamectl | grep Static | awk '{print $3}')
fi

echo "${master_ip}:/home /home nfs rw,auto 0 0" >> /etc/fstab 
mount -a || echo "Error: Check the /etc/fstab file, probably the shared directory could
not be mounted using NFS (Network File System), do not restart
${host_name} before solving this problem."

echo "Soy $(get_ip_of_nic $nic) solo me queda hacer upgrade" >> ~/odroid

nohup apt-get upgrade -y 2>&1 &

echo "Soy $(get_ip_of_nic $nic) ya he finalizado la inicialización" >> ~/odroid

# Esborrem el propi script
rm -- "$0"
