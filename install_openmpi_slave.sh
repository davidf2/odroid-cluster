#! /bin/bash

master_ip=$1
version=$2

mkdir /usr/local/src/openmpi-"$version"
mkdir /usr/local/openmpi
mount "$master_ip":/usr/local/src/openmpi-"$version" /usr/local/src/openmpi-"$version"

cd /usr/local/src/openmpi-"$version"

make install

ln -s /usr/local/openmpi/bin/* /usr/bin/

umount /usr/local/src/slurm-"$version