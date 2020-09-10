#! /bin/bash

if [ $(echo "$PATH" | grep "$(dirname $0)" | wc -l) -eq 0 ]; then
        export PATH="$(dirname $0):${PATH}"
fi

# Carreguem el script network_api.sh com a una llibreria, per 
#	poder fer servir les seves funcions
source network_api.sh

VERSION="20.02.4"

ip=$1
mask=$2

cd /usr/local/src/

wget https://download.schedmd.com/slurm/slurm-"$VERSION".tar.bz2
tar --bzip -x -f slurm*tar.bz2 && rm slurm*tar.bz2

cd slurm-"$VERSION"/

mkdir /usr/local/slurm 
./configure --prefix=/usr/local/slurm

apt-get  install libfreeipmi-dev libhwloc-dev freeipmi libmunge-dev -y

make -j25
make install

mkdir -p /usr/local/slurm/etc/cgroup
cp /usr/local/src/slurm-"$VERSION"/etc/cgroup.conf.example  /usr/local/slurm/etc/cgroup/cgroup.release_common
ln -s /usr/local/slurm/etc/cgroup/cgroup.release_common /usr/local/slurm/etc/cgroup/release_devices
ln -s /usr/local/slurm/etc/cgroup/cgroup.release_common /usr/local/slurm/etc/cgroup/release_cpuset
ln -s /usr/local/slurm/etc/cgroup/cgroup.release_common /usr/local/slurm/etc/cgroup/release_freezer

echo "/dev/null 
/dev/urandom 
/dev/zero 
/dev/cpu/*/* 
/dev/pts/*" > /usr/local/slurm/etc/allowed_devices.conf

echo "# slurm.conf file generated by configurator easy.html.
# Put this file on all nodes of your cluster. 
# See the slurm.conf man page for more information. 
# 
SlurmctldHost=odroid 
# 
#MailProg=/bin/mail 
MpiDefault=none 
#MpiParams=ports=#-# 
ProctrackType=proctrack/cgroup 
ReturnToService=1 
SlurmctldPidFile=/var/run/slurmctld.pid 
#SlurmctldPort=6817 
SlurmdPidFile=/var/run/slurmd.pid
#SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
#SlurmdUser=root
StateSaveLocation=/var/spool
SwitchType=switch/none
TaskPlugin=task/cgroup
#
#
# TIMERS 
#KillWait=30 
#MinJobAge=300 
#SlurmctldTimeout=120 
#SlurmdTimeout=300 
# 
# 
# SCHEDULING 
SchedulerType=sched/builtin 
SelectType=select/cons_tres 
SelectTypeParameters=CR_Core 
# 
# 
# LOGGING AND ACCOUNTING 
AccountingStorageType=accounting_storage/none 
ClusterName=cluster 
#JobAcctGatherFrequency=30 
JobAcctGatherType=jobacct_gather/linux 
#SlurmctldDebug=info 
#SlurmctldLogFile= 
#SlurmdDebug=info 
#SlurmdLogFile= 
# 
# 
# COMPUTE NODES 
NodeName=odroid[1-32] CPUs=4 RealMemory=1727 Sockets=4 CoresPerSocket=1 ThreadsPerCore=1 State=UNKNOWN 
PartitionName=debug Nodes=odroid[1-32] Default=YES MaxTime=30 State=UP" > /usr/local/slurm/etc/slurm.conf

echo "CgroupAutomount=yes
CgroupReleaseAgentDir=\"/usr/local/slurm/etc/cgroup\" 
ConstrainCores=yes 
TaskAffinity=yes 
ConstrainDevices=yes 
AllowedDevicesFile=\"/usr/local/slurm/etc/allowed_devices.conf\" 
ConstrainRAMSpace=no" > /usr/local/slurm/etc/cgroup.conf

echo "/usr/local/src/slurm-${VERSION} $(calculate_network_ip $ip $mask)$(mask_to_cidr $mask)(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports
echo "/usr/local/slurm/etc $(calculate_network_ip $ip $mask)$(mask_to_cidr $mask)(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports


echo "export PATH=${PATH}:\"/usr/local/slurm/bin\"" >> /etc/profile
echo "export PATH=${PATH}:\"/usr/local/slurm/sbin\"" >> /etc/profile
bash -c "echo \"export PATH=${PATH}:\"/usr/local/slurm/bin\"\" >> /root/.profile"
bash -c "echo \"export PATH=${PATH}:\"/usr/local/slurm/sbin\"\" >> /root/.profile"

cp -ap /usr/local/src/slurm-20.02.4/etc/slurmctld.service /etc/systemd/system/

systemctl enable slurmctld
systemctl start slurmctld