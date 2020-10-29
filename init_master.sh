#!/bin/bash


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Deshabilitem Unattended-Upgrade
sed -i 's/APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades

cp -p odroid_cluster.conf /etc
cp -p network_lib.sh /usr/local/sbin/

# Carreguem els scripts network_lib.sh i locale.sh com a llibreries, per 
#	poder fer servir les seves funcions
source network_lib.sh
source ./locale.sh

scripts_path="$(cat /etc/odroid_cluster.conf | grep "^SCRIPTS_DIR=" | cut -d= -f2)"
externaldns1="$(cat /etc/odroid_cluster.conf | grep "^EXTERNALDNS1=" | cut -d= -f2)"
externaldns2="$(cat /etc/odroid_cluster.conf | grep "^EXTERNALDNS2=" | cut -d= -f2)"
upgrade="$(cat /etc/odroid_cluster.conf | grep "^UPGRADE=" | cut -d= -f2)"
# Agafem el nom de l'usuari no root
master_name=$(cat /etc/odroid_cluster.conf | grep "^DEFAULT_USER=" | cut -d= -f2)
# Agafem el directori home l'usuari no root
master_home=$(eval echo "~$master_name")
KEY_FILE="${master_home}/.ssh/id_rsa"
KNOWN_HOSTS="${master_home}/.ssh/known_hosts"

locale="$(cat /etc/odroid_cluster.conf | grep "^SYS_LANGUAGE=" | cut -d= -f2)"
layout="$(cat /etc/odroid_cluster.conf | grep "^LAYOUT=" | cut -d= -f2)"
variant="$(cat /etc/odroid_cluster.conf | grep "^VARIANT=" | cut -d= -f2)"


change_password() {
	pass="0"
	pass2="1"

	# Demana la contrasenya dos cops, fins que coincideixin
	while [ $pass != $pass2 ]; do
		echo "Enter the new password for the master node:"
		stty -echo
		read -r pass
		stty sane
		echo "Re-enter the new password:"
		stty -echo
		read -r pass2
		stty sane
	done

	# Modifica la contrasenya de l'usuari root i el per defecte
	echo -e "${pass}\n${pass}" | passwd &> /dev/null
	echo -e "${pass}\n${pass}" | passwd $master_name &> /dev/null
}

add_ssh() {
	# Instal.lem openssh server
	apt-get install openssh-server sshpass -y

	# Iniciem el servei ssh
	systemctl start sshd
	systemctl enable sshd

	# Si no existeixen generem el parell de claus
	if [ ! -f "$KEY_FILE" ]; then
		su $master_name -c "ssh-keygen -q -t rsa -f \"$KEY_FILE\" -N \"$passphrase\""
	fi

	#Ens autoafegim a knownhosts, per a quan estigui el servidor NFS /home
	su $master_name -c "echo \"$(ssh-keyscan -H $(hostname))\" >> $KNOWN_HOSTS"
	#Ens autoafegim la clau publica, per a quan estigui el servidor NFS /home
	cat  $KEY_FILE.pub > "$master_home"/.ssh/authorized_keys

	# Si no existeix, fem una copia del fitxer de configuració
	#	original del servidor ssh
	if [[ ! -f /etc/ssh/sshd_config.back ]]; then
		bash -c "cp /etc/ssh/sshd_config /etc/ssh/sshd_config.back"
	fi

	# Carreguem la configuració per al dimoni sshd
	echo "#Port 5000

	# No permetre fer login com a root
	PermitRootLogin no
	# Fer servir la versio 2 de ssh, més segura que la 1
	Protocol 2
	PermitEmptyPasswords no

	ChallengeResponseAuthentication no
	UsePAM no
	GatewayPorts yes
	X11Forwarding yes
	PrintMotd no

	# Allow client to pass locale environment variables
	AcceptEnv LANG LC_*

	# override default of no subsystems
	Subsystem       sftp    /usr/lib/openssh/sftp-server" > /etc/ssh/sshd_config

	# Reiniciem el dimoni de ssh per a que carregui la nova configuració
	systemctl restart sshd

	#apt-get install fail2ban -y
	#cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
	#systemctl restart fail2ban
}

add_dnsmasq() {

	if [ $# -lt 1 ]; then
		echo -e "Error, at least you have to enter 1 parameter, for more information \n\t init_master -h"
		exit 1
	fi

	ip="$1"
	lan_interface="$2"
	mask="$3"

	# Instal.lem dnsmasq i el deshabilitem
	apt-get install dnsmasq -y 2> /dev/null
	systemctl disable --now dnsmasq

	# Deshabilitem el dimoni systemd-resolved per a que no canvii la configuració del DNS
	systemctl disable systemd-resolved
	systemctl stop systemd-resolved

	# Descomentem
	sed -i '/prepend domain-name-servers 127.0.0.1;/s/^#//g' /etc/dhcp/dhclient.conf

	# Si no existeix fem una copia de seguretat del fitxer dnsmasq.conf
	if [[ ( ! -f /etc/dnsmasq.conf.back ) && ( -f /etc/dnsmasq.conf ) ]]; then
		bash -c "cp -p /etc/dnsmasq.conf > /etc/dnsmasq.conf.back"
	fi

	first_ip=$(calculate_first_ip "$ip" "$mask")
	last_ip=$(calculate_last_ip "$ip" "$mask")
	# Carreguem la configuració per a dnsmasq
	echo "
	listen-address=::1,127.0.0.1,${ip}
	domain-needed
	bogus-priv
	no-hosts
	hostsdir=/etc/hosts.d
	strict-order
	no-resolv
	cache-size=1000
	
	server=${externaldns1}
	server=${externaldns2}
	
	domain=lan
	#local=/lan/
	
	interface=${lan_interface}
	dhcp-range=${first_ip},${last_ip},12h
	# Establecer la puerta de enlace predeterminada.
	dhcp-option=option:router,${ip}
	# Establecer servidores DNS para anunciar
	dhcp-option=option:dns-server,${ip}

	dhcp-script=${scripts_path}/dhcp_script.sh
	" > /etc/dnsmasq.conf

	# Reiniciem i habilitem el dimoni de dnsmasq
	systemctl enable dnsmasq
	systemctl start dnsmasq

	
}

add_vnc() {
	# Instal.lem l'entorn d'escriptori Xfce
	apt-get install xfce4 xfce4-goodies -y

	# Instal.lem un servidor VNC
	apt-get install tightvncserver -y

	# Carreguem la configuració de VNC pel nou entorn d'escriptori
	echo "
	#!/bin/bash
	exec /usr/bin/startxfce4 &
	" > $(eval echo "~$name")/.vnc/xstartup
}

add_nfs() {
	if [ $# -lt 2 ]; then
		echo "Error, you must enter 2 parameters, the first one corresponding to 
		an IP and the second one to the mask"
		exit 1
	fi
	ip="$1"
	mask="$2"
	apt-get install nfs-kernel-server -y
	ip_net="$(calculate_network_ip $ip $mask)"
	mask_cidr="$(mask_to_cidr $mask)"
	echo "/home ${ip_net}${mask_cidr}(rw,no_root_squash,no_subtree_check)" >> /etc/exports
	exportfs -arv

	systemctl enable nfs-kernel-server
	systemctl restart nfs-kernel-server
}

add_munge() {
	apt-get install munge -y
	systemctl enable --now munge
	/usr/sbin/create-munge-key -f
	systemctl restart munge

	# Copiem la clau de munge a /home, per a que puguin copiarla els slaves
	dd if=/etc/munge/munge.key of=/home/munge.key 
}

clean_tmp_hosts() {

	# Afegim un nou servei que s'encarrega de netejar el fitxer de 
	# hosts temporal al tancar el sistema
	echo "[Unit]
	Description=Clean /etc/hosts.d/tmp_hosts file
	DefaultDependencies=no
	Before=shutdown.target

	[Service]
	Type=oneshot
	ExecStart=/bin/sh -c 'echo "" > /etc/hosts.d/tmp_hosts'
	TimeoutStartSec=0

	[Install]
	WantedBy=shutdown.target" > /etc/systemd/system/clean_tmp_hosts.service
	
	systemctl enable clean_tmp_hosts.service
	
}

add_monitoring() {
	apt-get install git -y
	cd $(eval echo ~$name)/Downloads
	git clone https://github.com/JoanJaraBosch/TFG.git
	chown -R odroid: TFG/
	cd TFG
	./start-monitoring.sh
}


# Creem el directori principal, on emmagatzemarem els scripts necessaris
if [ ! -d "$scripts_path" ]; then
	mkdir "$scripts_path"
fi

# Copiem el fitxer que s'executa cada cop que el servidor dhcp fa una modificació
cp -p dhcp_script.sh "$scripts_path"/
# Copiem els scripts dependents
cp -p init_slave.sh "$scripts_path"/
cp -p add_slave.sh "$scripts_path"/
cp -p locale.sh "$scripts_path"/

# Creem el directori on guardarem alguns logs
mkdir /var/log/odroid_cluster
chown "$master_name": /var/log/odroid_cluster

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

# Actualitzem el master
apt-get update -y

# Modifiquem el hostname a master
hostnamectl set-hostname master

# Modifiquem el teclat
#set_layout "$layout" "$variant"

# Obliguem a l'usuari a canviar la contrasenya del master
change_password

#Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone "$(cat /etc/odroid_cluster.conf | grep "^SYS_TIMEZONE=" | cut -d= -f2)"
apt-get install chrony -y
systemctl enable --now chronyd

# Evitem que el dialeg amb la GUI durant la instal.lació de iptables-persistent 
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
# Iptables persistent
apt-get install iptables-persistent -y

# Creem el directori de hosts compartits per a dnsmasq
mkdir /etc/hosts.d

# Cridem al script de configuració de xarxa
result=$(./conf_network_master.sh)

# Del resultat del script agafem només l'ultima linia i descartem les demés
echo "$result" | head -n $(expr $(echo "$result" | wc -l) - 1 ) 2> /dev/null
result=$(echo $result | awk -F' ' '{print $NF}')

# Guardem el resultat en un array per treballar mes comodament
IFS=';' read -a net_array <<< "$result"

# Instal.lem el servidor openssh a més d'altre software relacionat, i el configurem
add_ssh

#  Esborrem software innecessari
apt-get remove --purge libreoffice* thunderbird pacman transmission* mate-* -y

apt-get autoremove -y
apt-get autoclean -y

# Instal.lem VNC i l'entorn grafic xfce4
add_vnc

add_nfs "${net_array[0]}" "${net_array[1]}"

add_munge

clean_tmp_hosts

./install_slurm.sh "${net_array[0]}" "${net_array[1]}"

apt-get install mpich -y

# Assegurem que la xarxa interna estigui en up
ifup --force "${net_array[3]}"

# Instal.lem el servidor dns i dhcp dnsmasq i el configurem
# AIXÓ SEMPRE HA DE SER L'ULTIM QUE FEM ABANS DEL UPGRADE
add_dnsmasq "${net_array[0]}" "${net_array[3]}" "${net_array[1]}"

# Instal.lem el software de monitoreig fet per Joan Jara Bosch
add_monitoring

# Modifiquem l'idioma
set_language "$locale"

if [ "$upgrade" -eq 1 ]; then
	apt-get upgrade -y
fi