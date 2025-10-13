#!/usr/bin/env bash
set -euo pipefail

# 1. 解锁目录
sudo chattr -i /snap /var/snap /var/cache/snapd
sudo rm -f /snap /var/snap /var/cache/snapd

# 2. 解除 mask 并允许安装
sudo systemctl unmask snapd.service snapd.socket snapd.seeded.service
sudo rm -f /etc/apt/preferences.d/nosnap /etc/apt/preferences.d/no-gnome-snap-plugin

# 3. 重装
sudo apt update
sudo apt install snapd -y

echo "Snap 已恢复，首次启动可能需要 sudo snap install core"
