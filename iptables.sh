#!/bin/bash

cluester_lan=$1
internet=$2

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

# Acceptem conexions SSH d'entrada i sortida nomes cap a la xarxa interna
iptables -A INPUT -p TCP --dport 22 -j ACCEPT
iptables -A OUTPUT -p TCP --dport 22 -o $cluester_lan -j ACCEPT

# Acceptem conexions DNS
iptables -A INPUT -p TCP --dport 53 -i $cluester_lan -j ACCEPT
iptables -A INPUT -p UDP --dport 53 -i $cluester_lan -j ACCEPT

