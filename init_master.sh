#!/bin/bash

# Instal.lant driver USB NIC
apt install wget -y
wget https://www.asix.com.tw/FrootAttach/driver/AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
tar -xjvf AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
make -C AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source
make install -C AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source
rm -f AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source.tar.bz2
rm -rf AX88772C_772B_772A_760_772_178_Linux_Driver_v4.23.0_Source


# Solucionem error de claus amb l'update
apt-key adv -v --keyserver keyserver.ubuntu.com --recv-keys 5360FB9DAB19BAC9

# Actualitzem el master
apt update
apt upgrade -y

# Instal.lem openssh server
apt install openssh-server -y

# Iniciem el servei ssh
systemctl start sshd
systemctl enable sshd

if [[ ! -f /etc/ssh/sshd_config.back ]]; then
	# Fem una copia del fitxer de configuracio original del servidor ssh
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.back
fi

# Afegim el nou contingut al firxer de configuracio de ssh
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

systemctl restart sshd

apt install fail2ban -y
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl restart fail2ban

#  Esborrem software innecessari
apt-get remove --purge libreoffice* -y
apt-get remove --purge thunderbird -y
apt-get remove --purge pacman -y
apt-get remove --purge transmission* -y

# Eliminem l'entorn d'escriptori MATE
apt-get remove --purge mate-* -y
apt autoremove -y
sudo apt autoclean -y

# Instal.lem l'entorn d'escriptori Xfce
sudo apt install xfce4 -y

# Instal.lem un servidor VNC
apt install tightvncserver -y

echo "
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
" > ~/.vnc/xstartup

result=$(./conf_network_master.sh)

echo "$result" | head -n $(expr $(echo "$result" | wc -l) - 1 ) 2> /dev/null
result=$(echo $result | awk -F' ' '{print $NF}')

# Guardem el resultat en un array per treballar mes comodament
IFS=';' read -a net_array <<< "$result"

# Instal.lem dnsmasq i el dimoni resolvconf
apt install dnsmasq -y
apt install resolvconf -y

if [[ ! -f /etc/dnsmasq.conf.back ]]; then
	cp /etc/dnsmasq.conf > /etc/dnsmasq.conf.back
fi

echo "
listen-address=127.0.0.1,${net_array[0]}
server=8.8.8.8
server=8.8.4.4
domain-needed
bogus-priv

interface=eth1
dhcp-range=${net_array[0]},172.16.255.254,12h
# Establecer la puerta de enlace predeterminada.
dhcp-option=3,${net_array[0]}
# Establecer servidores DNS para anunciar
dhcp-option=6,${net_array[0]}

#dhcp-host=00:1e:06:33:ce:35,odroid1,172.16.0.2
#dhcp-host=00:1e:06:33:4d:fa,odroid2,172.16.0.3
" > /etc/dnsmasq.conf

# Descomentem
sed -i '/prepend domain-name-servers 127.0.0.1;/s/^#//g' /etc/dhcp/dhclient.conf

echo "
/etc/resolvconf/resolv.conf.d" > /etc/resolvconf/resolv.conf.d/base

# Reiniciem i habilitem el dimoni de resolvconf
systemctl restart dnsmasq
systemctl enable dnsmasq

# Reiniciem i habilitem el dimoni de resolvconf
systemctl restart resolvconf
systemctl enable resolvconf

systemctl disable systemd-resolved
systemctl stop systemd-resolved
