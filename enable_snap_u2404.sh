#!/usr/bin/env bash
# enable-snap-u2404.sh  --  Re-enable Snap on Ubuntu 24.04 (English output)
set -euo pipefail

########################################
# 1.  Unlock and remove blocked directories
########################################
sudo chattr -i /snap /var/snap /var/cache/snapd 2>/dev/null || true
sudo rm -rf /snap /var/snap /var/cache/snapd

########################################
# 2.  Unmask snapd units
########################################
for unit in snapd.service snapd.socket snapd.seeded.service; do
    sudo systemctl unmask "$unit" 2>/dev/null || true
done

########################################
# 3.  Remove apt pins
########################################
sudo rm -f /etc/apt/preferences.d/nosnap \
           /etc/apt/preferences.d/no-gnome-snap-plugin

########################################
# 4.  Install snapd
########################################
sudo apt update
sudo apt install snapd -y

########################################
# 5.  Start and enable snapd now
########################################
sudo systemctl enable --now snapd.service snapd.socket

########################################
# 6.  Final message
########################################
echo "Snap has been re-enabled. You may run 'sudo snap install core' to bootstrap the store."
