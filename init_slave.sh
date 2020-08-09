#!/bin/bash


if [ $# -ne 1 ]; then
	echo "Error, you must enter 2 parameters, the first corresponding to the IP of the master
	and the second to your home directory"
	exit 1
fi

master_ip="$1" # $1 ip del master a la lan odroid

interface=$(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1))

if [ -z "$interface" ]; then
      echo "Error, no network interfaces found"
      exit 1
fi

chattr -i /etc/resolv.conf
# Fixem com a DNS el master, i convertim el fitxer a immutable
echo "nameserver ${master_ip}" > /etc/resolv.conf
# Protegim el resolv.conf de modificacions
chattr +i /etc/resolv.conf

# Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone Europe/Madrid
ntpdate -u hora.roa.es

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

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

# Instal.lem munge
apt install munge -y
systemctl enable --now munge


cp -p ~/Documents/munge.key /etc/munge && rm ~/Documents/munge.key
chown munge:munge /etc/munge/munge.key
systemctl restart munge

host_name=$(hostnamectl | grep Transient | awk '{print $3}')
if [ -z "$host_name" ]; then
	host_name=$(hostnamectl | grep Static | awk '{print $3}')
fi

echo "${master_ip}:/home /home nfs rw,async,auto 0 0" >> /etc/fstab 
mount -a || echo "Error: Check the /etc/fstab file, probably the shared directory could
not be mounted using NFS (Network File System), do not restart
${host_name} before solving this problem."

nohup apt upgrade -y 2>&1 &

rm -- "$0"
