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

# Fem una copia del fitxer de configuracio original del servidor ssh
cp /etc/ssh/sshd_config /etc/ssh/sshd_config_copy

# Afegim el nou contingut al firxer de configuracio de ssh
echo "Port 5000

# No permetre fer login com a root
PermitRootLogin no

# Fer servir la versio 2 de ssh, més segura que la 1
Protocol 2

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
startxfce4 &" > ~/.vnc/xstartup


# Instal.lem dnsmasq
apt install dnsmasq -y


<< 'MULTILINE-COMMENT'
while [ -n "$1" ]; do # Mentres $1 no sigui null 

	case "$1" in

	-a) echo "-a option passed" ;;

	-b)

		if [[ $2 == "" ]]; then
			echo " -b incorrect option"
		else
			echo "-b option passed, with value $2"
		fi
		shift
		;;

	-c|--clean) echo "-c option passed" ;;

	*) echo "Option $1 not recognized" ;;

	esac

	shift # Desplaça $# cap a l'esquerra $1 -> $2 ...

done
MULTILINE-COMMENT
