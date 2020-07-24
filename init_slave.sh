#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Error, you must enter 2 parameters, the first corresponding to the IP of the master
	and the second to your home directory"
	exit 1
fi

master_ip="$1" # $1 ip del master a la lan odroid
master_home="$2" # $2 directori home del master
interface=$(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1))

if [ -z "$interface" ]; then
      echo "Error, no network interfaces found"
      exit 1
fi

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

chattr -i /etc/resolv.conf
# Fixem com a DNS el master, i convertim el fitxer a immutable
echo "nameserver ${master_ip}" > /etc/resolv.conf
# Protegim el resolv.conf de modificacions
chattr +i /etc/resolv.conf

# Actualitzem
apt update -y

# Desactivem autentificació mitjançant usuari root
#sed -i 's/PermitRootLogin yes.*/PermitRootLogin no/' /etc/ssh/sshd_config
#systemctl restart sshd

#  Esborrem software innecessari
apt-get remove --purge libreoffice* thunderbird pacman transmission* -y
apt autoremove -y
apt autoclean -y

# Instal.lem el client NFS
apt install nfs-common -y

if [[ ! -d $HOME/master ]]; then
	mkdir $HOME/master
fi

echo "${master_ip}:/home/odroid ${master_home}/master nfs rw,async,auto 0 0" >> /etc/fstab
mount -a

apt upgrade -y

rm -- "$0"