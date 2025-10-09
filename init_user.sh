#!/bin/bash

sudo useradd -m -d /localhome/keystone -s /bin/bash keystone
sudo usermod -aG sudo keystone
sudo usermod -aG wheel keystone
sudo usermod -aG adm keystone
sudo usermod -aG admin keystone
echo "changeit" | sudo passwd --stdin $USER
echo -e '\n%wheel ALL=(ALL:ALL) NOPASSWD:ALL\n%admin ALL=(ALL:ALL) NOPASSWD:ALL\n%sudo ALL=(ALL:ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers.d/nopasswd-groups && sudo visudo -c
