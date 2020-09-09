#! /bin/bash

master_ip=$1
version=$2

mkdir /usr/local/src/slurm-$"version"
mkdir /usr/local/slurm
echo "${master_ip}:/usr/local/src/slurm-${version} /usr/local/src/slurm-${version} nfs rw,async,auto 0 0" >> /etc/fstab
mount -a

cd /usr/local/src/slurm-$"version"
make install

echo "${master_ip}:/usr/local/slurm /usr/local/slurm nfs rw,async,auto 0 0" >> /etc/fstab
mount -a

echo "export PATH=${PATH}:\"/usr/local/slurm/bin\"" >> /etc/profile
echo "export PATH=${PATH}:\"/usr/local/slurm/sbin\"" >> /etc/profile
bash -c "echo \"export PATH=${PATH}:\"/usr/local/slurm/bin\"\" >> /root/.profile"
bash -c "echo \"export PATH=${PATH}:\"/usr/local/slurm/sbin\"\" >> /root/.profile"

cp -ap /usr/local/src/slurm-20.02.4/etc/slurmd.service /etc/systemd/system/

systemctl enable slurmd
systemctl start slurmd