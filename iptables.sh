#!/bin/bash

if [ $# -ne 2 ]; then
	echo "Error, you have to enter 2 parameters."
	exit 1
fi

cluster_lan="$1"
internet="$2"

externaldns1="$(cat /etc/odroid_cluster.conf | grep "^EXTERNALDNS1=" | cut -d= -f2)"
externaldns2="$(cat /etc/odroid_cluster.conf | grep "^EXTERNALDNS2=" | cut -d= -f2)"

# Esborrem les regles anteriors
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Afegim les politiques per defecte
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Permetem les entrades i sortides de la interficie loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Acceptem les respostes en conexions establertes
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Acceptem conexions SSH d'entrada i sortida nomes cap a la xarxa interna
iptables -A INPUT -p TCP --dport 22 -j ACCEPT
iptables -A OUTPUT -p TCP --dport 22 -o $cluster_lan -j ACCEPT

# Acceptem conexions DNS d'entrada per la xarxa interna
iptables -A INPUT -p TCP --dport 53 -i $cluster_lan -j ACCEPT
iptables -A INPUT -p UDP --dport 53 -i $cluster_lan -j ACCEPT

# Acceptem connexion DNS de sortida, pels servidors configurats
iptables -A OUTPUT -p TCP -d "$externaldns1","$externaldns2" --dport 53 -j ACCEPT
iptables -A OUTPUT -p UDP -d "$externaldns1","$externaldns2" --dport 53 -j ACCEPT

# Acceptem les  entrades pel port 67 amb origen port 68 per al servidor DHCP
iptables -A INPUT -p UDP --dport 67 -i $cluster_lan -j ACCEPT
iptables -A OUTPUT -p UDP --dport 68  -j ACCEPT

# Acceptem les sortides HTTP i HTTPS per les actualitzacións o navegar per internet
iptables -A OUTPUT -p TCP --dport 80 -o $internet -j ACCEPT
iptables -A OUTPUT -p TCP --dport 443 -o $internet -j ACCEPT

# Fem forwarding dels paquets que surtin de la xarxa interna cap a internet, pel port 80 i 443 com a desti
iptables -A FORWARD -p TCP --dport 80 -i $cluster_lan -o $internet  -j ACCEPT
iptables -A FORWARD -p TCP --dport 443 -i $cluster_lan -o $internet -j ACCEPT

# Acceptem les entrades pel port 443 pel servidor web
iptables -A INPUT -p TCP --dport 443 -i $internet -j ACCEPT

# Acceptem les entrades pel port 3000, pel servidor node.js, per la monitorització i el manteniment
iptables -A INPUT -p TCP --dport 3000 -i $internet -j ACCEPT

# Acceptem les entrades pel port 5901 pel servidor VNC
iptables -A INPUT -p TCP --dport 5901 -i $internet -j ACCEPT

# Acceptem les sortides i entrades pel port 6817 i 6818 per a les comunicacións
# entre  slurmctld i slurmd
iptables -A INPUT -p TCP --dport 6817 -i $cluster_lan -j ACCEPT
iptables -A OUTPUT -p TCP --dport 6818 -o $cluster_lan -j ACCEPT

# Acceptem la entrada TCP des de la xarxa interna, degut a la obertura de ports dinamica de srun i mpirun
iptables -A INPUT -p TCP -i $cluster_lan -j ACCEPT

# Habilitem ICMP
iptables -A INPUT -p ICMP  -i $cluster_lan -j ACCEPT
iptables -A OUTPUT -p ICMP  -o $cluster_lan -j ACCEPT

# Acceptem les entrades pel port 2049 NFS
iptables -A INPUT -p TCP --dport 2049 -i $cluster_lan -j ACCEPT
iptables -A INPUT -p UDP --dport 2049 -i $cluster_lan -j ACCEPT

# Habilitem el postrouitng a iptables per donar acces a internet a la xarxa interna
iptables -t nat -A POSTROUTING -o $internet -j MASQUERADE