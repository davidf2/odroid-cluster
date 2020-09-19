#! /bin/bash


master_ip=$1
version=$2

useradd -M slurm --shell /usr/sbin/nologin --home-dir /nonexistent --password "*"

# Instal.lem dependencies
apt-get  install libfreeipmi-dev libhwloc-dev freeipmi libmunge-dev -y

mkdir /usr/local/src/slurm-"$version"
mkdir /usr/local/slurm
mount "$master_ip":/usr/local/src/slurm-"$version" /usr/local/src/slurm-"$version"

cd /usr/local/src/slurm-"$version"
make install

mkdir /usr/local/slurm/etc
if [ $(cat /etc/exports | grep "/usr/local/slurm/etc" | wc -l) -eq 0 ]; then
	echo "${master_ip}:/usr/local/slurm/etc /usr/local/slurm/etc nfs rw,auto 0 0" >> /etc/fstab
fi
mount /usr/local/slurm/etc

# Creem enllaços simbolics per a poder executar comandes de slurm mitjançant qualsevol usuari
ln -s /usr/local/slurm/sbin/* /usr/sbin/
ln -s /usr/local/slurm/bin/* /usr/bin/

# Copiem el slurmd.service al directori pertinent
cp -ap /usr/local/src/slurm-20.02.4/etc/slurmd.service /etc/systemd/system/

mkdir /var/spool/slurmd
chown slurm: /var/spool/slurmd

systemctl enable slurmd
systemctl start slurmd

umount /usr/local/src/slurm-"$version