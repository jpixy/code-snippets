#!/bin/bash

sudo useradd -m -d /localhome/keystone -s /bin/bash keystone

for group in wheel adm; do
    sudo usermod -aG $group keystone 2>/dev/null && echo "Added to $group" || echo "Group $group not found"
done

echo "keystone:changeit" | sudo chpasswd

sudo chmod 0440 /etc/sudoers.d/* 2>/dev/null || true

{
    [[ $(getent group wheel) ]] && echo '%wheel ALL=(ALL:ALL) NOPASSWD:ALL'
    [[ $(getent group admin) ]] && echo '%admin ALL=(ALL:ALL) NOPASSWD:ALL' 
    [[ $(getent group sudo) ]] && echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL'
} | sudo tee /etc/sudoers.d/nopasswd-groups

sudo chmod 0440 /etc/sudoers.d/nopasswd-groups
sudo visudo -c
