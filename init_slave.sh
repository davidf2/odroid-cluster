#!/bin/bash

SLURM_ETC=/etc/slurm-llnl

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

add_slurm() {
	master_ip=$1

	# Instal.lem slurm-wlm
	apt install slurm-wlm -y

	if [ $(cat /etc/fstab | grep "${SLURM_ETC}" | wc -l) -eq 0 ]; then
		echo "${master_ip}:${SLURM_ETC} ${SLURM_ETC} nfs rw,auto,_netdev 0 0" >> /etc/fstab
	fi

	mount ${SLURM_ETC}

	mkdir /var/spool/slurmd
	chown slurm: /var/spool/slurmd

	systemctl enable --now slurmd
}

add_slurm_watcher() {
	echo "[Unit]
Description=Restart slurmd if slurm.conf is modified.
After=network.target

[Service]
Type=oneshot
ExecStart=$(which systemctl) restart slurmd.service

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/slurm_watcher.service
	echo "[Path]
PathModified=${SLURM_ETC}/slurm.conf

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/slurm_watcher.path

	systemctl enable --now slurm_watcher.{path,service}
}

set_language() {
        
		locale="$1"

        if [ -z "$locale" ]; then
                echo "You need to enter a language in odroid_cluster.conf"
                exit 1
        fi

        if [ $(cat /usr/share/i18n/SUPPORTED | grep ^"$locale".UTF-8 | wc -l) -eq 0 ]; then
                echo "Incorrect language"
                exit 1
        fi

        if [ $(grep "source /etc/default/locale" /etc/profile | wc -l) -eq 0 ]; then
                echo "source /etc/default/locale" >> /etc/profile
        fi

        if [ $(grep "source /etc/default/locale" /etc/bash.bashrc | wc -l) -eq 0 ]; then
                echo "source /etc/default/locale" >> /etc/bash.bashrc
        fi

        # Instal.lem el nou idioma
        locale-gen "$locale".utf8

        # Seleccionem el nou idioma
        #update-locale LANG="$locale".UTF-8 LANGUAGE
        localectl set-locale LANG="$locale".UTF-8 LANGUAGE="$locale".UTF-8:"$(echo $locale | cut -d_ -f1)"

        # Actualitza les varaibles LANG i LANGUAGE
        source /etc/default/locale

        su $master_name -c 'source /etc/default/locale'

        # Instal.lem dependencies del nou idioma per tal de traduir-ho tot.
        apt-get install $(check-language-support -l "$locale") -y
}

set_layout() {
	
	layout="$1"
	variant="$2"
		
    if [ $# -ne 2 ]; then
            echo -e "It is necessary to pass 2 arguments, the first corresponding to the \nlayout and the second to the variant"
            exit 1
    fi
	
	if [ "$layout" == "$variant" ]; then
		variant="basic"
	fi

	setxkbmap -layout $layout -variant $variant

	if [ $(grep "setxkbmap -layout $layout -variant $variant" /etc/profile | wc -l) -eq 0 ]; then
            sed -i '/^setxkbmap/d' /etc/profile
            echo "setxkbmap -layout $layout -variant $variant" >> /etc/profile
    fi

    if [ $(grep "setxkbmap -layout $layout -variant $variant" /etc/bash.bashrc | wc -l) -eq 0 ]; then
             sed -i '/^setxkbmap/d' /etc/bash.bashrc
            echo "setxkbmap -layout $layout -variant $variant" >> /etc/bash.bashrc
    fi
}

if [ $# -ne 4 ]; then
	echo "Error, you must enter 5 parameters, the first corresponding to the IP or host name 
of the master, the second an integer value between 1 and 0 to indicate whether the slave is 
updated or not and the third an integer value corresponding to the waiting time in minutes
between the upgrade of one node and the next."
	exit 1
fi
if [ "$2" -ne 1 ] && [ "$2" -ne 0 ]; then
	echo "The second parameter must be an integer value between 1 and 0"
	exit 1
fi

master_ip="$1" # $1 ip del master a la lan odroid
upgrade="$2"
sleep_time="$3"
locale="$4"

language=$(echo "$locale" | cut -d';' -f 1)
layout=$(echo "$locale" | cut -d';' -f 2)
variant=$(echo "$locale" | cut -d';' -f 3)
timezone=$(echo "$locale" | cut -d';' -f 4)

# Deshabilitem Unattended-Upgrade
sed -i 's/APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades

nic=$(echo $(sed '1d;2d' /proc/net/dev | grep -v 'lo' | cut -d: -f1))

if [ -z "$nic" ]; then
      echo "Error, no NIC found"
      exit 1
fi

# Bucle de espera, per assegurarnos de que la resolució de noms està funcionant correctament
while [[ $(ping google.com -I "$nic" -w2 2> /dev/null | grep "received" | cut -d " " -f4) -eq 0 ]]; do
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

# Modifiquem l'idioma i el layout del teclat
set_language "$language"
set_layout "$layout" "$variant"

# Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone "$timezone"
apt install chrony -y
systemctl enable --now chronyd

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

# Actualitzem
apt-get update -y

# Instal.lem sysstat per a al software de monitorització de Joan Jara
apt-get install sysstat -y

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

add_slurm "${master_ip}"

apt-get install mpich -y

echo "I am $(hostname) I have already installed and configured everything." >> ~/.slave_responses

if [ $upgrade -eq 1 ]; then
	sleep "$sleep_time"m && apt-get upgrade -y &> /var/log/upgrade_$(hostname).log 
fi

# Esborrem el propi script
rm -- "$0"
