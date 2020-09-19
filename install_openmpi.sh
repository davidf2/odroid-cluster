#! /bin/bash

if [ $(echo "$PATH" | grep "$(dirname $0)" | wc -l) -eq 0 ]; then
        export PATH="$(dirname $0):${PATH}"
fi

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_api.sh


ip=$1
mask=$2

export CC=gcc
export CXX=g++
export FC=gfortran

VERSION="4.0.1"

cd /usr/local/src/

wget -N https://download.open-mpi.org/release/open-mpi/v"$(echo $VERSION  | cut -d. -f1-2)"/openmpi-"$VERSION".tar.bz2
tar --bzip -x -f openmpi*tar.bz2 && rm openmpi-*.tar.bz2
cd openmpi-"$VERSION"

mkdir /usr/local/openmpi
./configure --prefix=/usr/local/openmpi --enable-mpirun-prefix-by-default

make -j25 all

ln -s /usr/local/openmpi/bin/* /usr/bin/

echo "/usr/local/src/openmpi-${VERSION} $(calculate_network_ip $ip $mask)$(mask_to_cidr $mask)(rw,no_root_squash,no_subtree_check)" >> /etc/exports
exportfs -a
