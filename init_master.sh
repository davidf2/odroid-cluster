#!/bin/bash


export PATH="$(dirname $0):${PATH}"

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source ./network_api.sh

SCRIPTS_DIR=/opt/urvcluster
EXTERNALDNS1="8.8.8.8"
EXTERNALDNS2="8.8.4.4"

add_ssh() {
	# Instal.lem openssh server
	apt install openssh-server sshpass -y

	# Iniciem el servei ssh
	systemctl start sshd
	systemctl enable sshd

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

	#apt install fail2ban -y
	#cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
	#systemctl restart fail2ban
}

modify_dnsmasq_service() {

	file="/lib/systemd/system/dnsmasq.service"

    if [ ! -z "$file" ] && [ -f "$file" ] && [ $(cat "$file" | grep "\[Service\]" | wc -l) -gt 0  ]; then
            if [ $(grep Restart= "$file" | wc -l) -gt 0 ]; then
                    if [ $(grep Restart= "$file" | grep on-abort "$file" | wc -l) -eq 0 ]; then
                            line=$(grep Restart= "$file")
                            sed -i 's/^'"$line"'.*/"Restart=on-abort"/g' "$file"
                    fi
            else
                    sed -i '/^\[Install\].*/i Restart=on-abort' "$file"
            fi
            systemctl daemon-reloads
    fi
}

add_dnsmasq() {

	if [ $# -lt 1 ]; then
		echo -e "Error, at least you have to enter 1 parameter, for more information \n\t init_master -h"
		exit 1
	fi

	ip="$1"

	# Instal.lem dnsmasq i el dimoni resolvconf
	apt install dnsmasq -y

	# Si no existeix fem una copia de seguretat del fitxer dnsmasq.conf
	if [[ ( ! -f /etc/dnsmasq.conf.back ) && ( -f /etc/dnsmasq.conf ) ]]; then
		bash -c "cp -p /etc/dnsmasq.conf > /etc/dnsmasq.conf.back"
	fi

	# Carreguem la configuració per a dnsmasq
	echo "
	listen-address=127.0.0.1,${ip}
	server=${EXTERNALDNS1}
	server=${EXTERNALDNS2}
	domain-needed
	bogus-priv
	no-resolv
	
	interface=eth1
	dhcp-range=${ip},172.16.0.254,12h
	# Establecer la puerta de enlace predeterminada.
	dhcp-option=3,${ip}
	# Establecer servidores DNS para anunciar
	dhcp-option=6,${ip}

	dhcp-script=/opt/scripts/dhcp_script.sh
	" > /etc/dnsmasq.conf

	# Deshabilitem el dimoni systemd-resolved per a que no canvii la configuració del DNS
	systemctl stop systemd-resolved
	systemctl disable systemd-resolved

	modify_dnsmasq_service

}

install_nic_driver() {
	# Instal.lant driver USB NIC
	apt install wget -y
	wget https://www.asix.com.tw/FrootAttach/driver/AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
	tar -xjvf AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
	make -C AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source
	make install -C AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source
	rm -f AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
	rm -rf AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source
}

add_vnc() {
	# Instal.lem l'entorn d'escriptori Xfce
	apt install xfce4 -y

	# Instal.lem un servidor VNC
	apt install tightvncserver -y

	# Carreguem la configuració de VNC pel nou entorn d'escriptori
	echo "
	#!/bin/bash
	xrdb $HOME/.Xresources
	startxfce4 &
	" > ~/.vnc/xstartup
}

add_nfs() {
	if [ $# -lt 2 ]; then
		echo "Error, you must enter 2 parameters, the first one corresponding to 
		an IP and the second one to the mask"
		exit 1
	fi
	ip="$1"
	mask="$2"
	apt install nfs-kernel-server -y
	echo "/home $(calculate_network_ip $ip $mask)$(mask_to_cidr $mask)(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports
	exportfs -arv

	systemctl enable --now nfs-kernel-server
}

add_munge() {
	apt-get install munge -y
	/usr/sbin/create-munge-key -f
	systemctl enable munge
	systemctl start munge
}

# Instal.lem el driver de la targeta de xarxa 
install_nic_driver

#Fiquem a zona horaria i actualitzem l'hora
timedatectl set-timezone Europe/Madrid
ntpdate -u hora.roa.es

# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

# Actualitzem el master
apt update -y

# Evitem que el dialeg amb la GUI durant la instal.lació de iptables-persistent 
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
# Iptables persistent
apt-get install iptables-persistent -y

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

apt autoremove -y
apt autoclean -y

# Instal.lem VNC i l'entorn grafic xfce4
add_vnc

add_nfs "${net_array[0]}" "${net_array[1]}"

# Instal.lem el servidor dns i dhcp dnsmasq i el configurem
add_dnsmasq "${net_array[0]}"

if [ ! -d /opt/scripts ]; then
	mkdir /opt/scripts
fi

# Copiem el fitxer que s'executa cada cop que el servidor dhcp fa una modificació
cp -p dhcp_script.sh /opt/scripts/
# Copiem els scripts dependents
cp -p init_slave.sh /opt/scripts/
cp -p cron_init_slave.sh /opt/scripts/
cp -p add_slave.sh /opt/scripts/
cp -p network_api.sh /opt/scripts/
cp -p urvcluster.conf /etc

# Descomentem
sed -i '/prepend domain-name-servers 127.0.0.1;/s/^#//g' /etc/dhcp/dhclient.conf

rm /etc/resolv.conf && touch /etc/resolv.conf
# Afegim la propia maquina com a servidor DNS
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# Reiniciem i habilitem el dimoni de dnsmasq
systemctl restart dnsmasq
systemctl enable dnsmasq

add_munge

# Actualitzem per no tindre problemes amb modificacións a les instalacions anteriors
#	amb actualitzacions al kernel
apt upgrade -y
