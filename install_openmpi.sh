#! /bin/bash

# Carreguem el script network_lib.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_lib.sh


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
./configure --prefix=/usr/local/openmpi --enable-mpirun-prefix-by-default --with-ucx=no --with-slurm --with-pmi=/usr/local/slurm/include/slurm/pmi.h

make -j4 all
make install

ln -s /usr/local/openmpi/bin/* /usr/bin/
if [ $(cat /etc/exports | grep "/usr/local/src/openmpi-${VERSION}" | wc -l) -eq 0 ]; then
	echo "/usr/local/src/openmpi-${VERSION} $(calculate_network_ip $ip $mask)$(mask_to_cidr $mask)(rw,no_root_squash,no_subtree_check)" >> /etc/exports
fi
exportfs -a
