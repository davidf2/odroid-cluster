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

if [ $# -ne 2 ]; then
	echo "Error, you must enter 2 parameters, the first corresponding to the IP or hostname of the master,
and the second an integer value between 1 and 0 to indicate if the slave updates or not."
	exit 1
fi
if [ "$2" -eq 1 ] || [ "$2" -eq 0 ]; then
	echo "The second parameter must be an integer value between 1 and 0"
	exit 1
fi

master_ip="$1" # $1 ip del master a la lan odroid
upgrade="$2"

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
rm /etc/resolv.conf
echo "nameserver ${master_ip}" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# Configurem les interficies de xarxa
echo "auto lo
iface lo inet loopback

auto ${nic}
iface ${nic} inet dhcp" > /etc/network/interfaces

# Afegim aquest petit sctipt per a que actualitci el hostname amb el dhcp
echo "#!/bin/bash

hostnamectl set-hostname --static \$new_host_name" > /etc/dhcp/dhclient-exit-hooks.d/hostname
chmod a+r /etc/dhcp/dhclient-exit-hooks.d/hostname
dhclient -v

# Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone Europe/Madrid
apt install chrony -y
systemctl enable --now chronyd

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


# Afegim NFS /home a fstab i el muntem
echo "${master_ip}:/home /home nfs rw,auto,_netdev 0 0" >> /etc/fstab 
mount -a || echo "Error: Check the /etc/fstab file, probably the shared directory could
not be mounted using NFS (Network File System), do not restart
$(hostname) before solving this problem."

# Instal.lem munge
apt-get install munge -y
systemctl enable --now munge

# Copiem la clau guardada a /home i reiniciem munge
dd if=/home/munge.key of=/etc/munge/munge.key 
systemctl restart munge


if [ $upgrade -eq 1 ]; then
	echo "I am $(hostname) I have already installed and configured everything. Starting upgrade." >> ~/odroid

	nohup apt-get upgrade -y 2>&1 &

	echo "I am $(hostname) I have already finished the upgrade." >> ~/odroid
else
	echo "I am $(hostname) I have already installed and configured everything." >> ~/odroid
fi

# Esborrem el propi script
rm -- "$0"
