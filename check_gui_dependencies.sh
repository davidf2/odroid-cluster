#! /bin/bash

system=$(cat dependencies | grep ^system | cut -d: -f2-)
python=$(cat dependencies | grep ^python3 | cut -d: -f2-)

IFS=':' read -a sys_array <<< "$system"
IFS=':' read -a py_array <<< "$python"

for i in "${sys_array[@]}"; do
	if [ $(dpkg -l $i &>/dev/null ; echo $?) -eq 1 ]; then
		exit 1
	fi
done


pip3_list=$(pip3 list)
for i in "${py_array[@]}"; do
	if [ $(echo "$pip3_list" | grep "\<${i}\>" | wc -l) -eq 0 ]; then
		exit 1
	fi
done


exit 0
