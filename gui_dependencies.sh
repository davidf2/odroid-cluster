#! /bin/bash

system=$(cat dependencies | grep ^system | cut -d: -f2-)
python=$(cat dependencies | grep ^python3 | cut -d: -f2-)


apt install $(echo ${system//:/ })  -y

pip3 install $(echo ${python//:/ })