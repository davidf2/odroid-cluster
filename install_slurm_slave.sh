#! /bin/bash

SLURM_ETC=/etc/slurm-llnl

master_ip=$1

if [ $(munge -n | unmunge | grep ENCODE_HOST | grep \(0.0.0.0\) | wc -l) -eq 1 ]; then
	apt remove --purge munge -y
	apt install munge -y
	dd if=/home/munge.key of=/etc/munge/munge.key
	systemctl restart munge
	if [ $(munge -n | unmunge | grep ENCODE_HOST | grep \(0.0.0.0\) | wc -l) -eq 1 ]; then
		echo "Could not fix error in munge:
	ENCODE_HOST: ??? (0.0.0.0)

You can check if the problem persists with the command:
	munge -n | unmunge" 2>&1
		exit 1
	fi
fi

# Instal.lem dependencies
apt-get  install libfreeipmi-dev libhwloc-dev freeipmi libmunge-dev libz-dev -y

# Instal.lem slurm-wlm
apt install slurm-wlm -y

if [ $(cat /etc/fstab | grep "${SLURM_ETC}" | wc -l) -eq 0 ]; then
	echo "${master_ip}:${SLURM_ETC} ${SLURM_ETC} nfs rw,auto,_netdev 0 0" >> /etc/fstab
fi

mount ${SLURM_ETC}

mkdir /var/spool/slurmd
chown slurm: /var/spool/slurmd

systemctl enable slurmd
systemctl start slurmd
