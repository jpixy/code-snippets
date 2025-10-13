#!/usr/bin/env bash
# disable-snap-u2404.sh  --  Completely disable Snap on Ubuntu 24.04 (English output)
set -euo pipefail

#############################
# 0.  Backup apt preferences
#############################
sudo cp -a /etc/apt/preferences.d "/etc/apt/preferences.d.bak.$(date +%F)"

#############################
# 1.  Pin snapd so it never comes back
#############################
cat <<'EOF' | sudo tee /etc/apt/preferences.d/nosnap
Package: snapd
Pin: release *
Pin-Priority: -10
EOF

#############################
# 2.  Stop, disable and mask snapd units (quietly)
#############################
for unit in snapd.service snapd.socket snapd.seeded.service; do
    sudo systemctl stop    "$unit" 2>/dev/null || true
    sudo systemctl disable "$unit" 2>/dev/null || true
    sudo systemctl mask    "$unit" 2>/dev/null || true
done

#############################
# 3.  Remove all installed snaps (if snap cmd still works)
#############################
if command -v snap &>/dev/null; then
    # drop disabled revisions first
    snap list --all | awk '/disabled/{print $1, $3}' | \
    while read -r snapname revision; do
        sudo snap remove "$snapname" --revision="$revision" 2>/dev/null || true
    done
    # purge remaining snaps
    snap list | tail -n +2 | awk '{print $1}' | \
    xargs -r -I{} sudo snap remove --purge {} 2>/dev/null || true
fi

#############################
# 4.  Purge snapd package itself
#############################
sudo apt purge snapd gnome-software-plugin-snap -y
sudo apt autoremove --purge -y

#############################
# 5.  Clean up leftover mount units
#############################
sudo systemctl daemon-reload
sudo systemctl reset-failed

#############################
# 6.  Unmount any lingering /snap mounts
#############################
while read -r mp; do
    sudo umount -lf "$mp" 2>/dev/null || true
done < <(mount | grep '/snap' | awk '{print $3}')

#############################
# 7.  Block re-creation of snap directories
#############################
sudo rm -rf /snap /var/snap /var/cache/snapd
sudo touch /snap /var/snap /var/cache/snapd
sudo chattr +i /snap /var/snap /var/cache/snapd

#############################
# 8.  Pin GNOME snap plugin as well
#############################
cat <<'EOF' | sudo tee /etc/apt/preferences.d/no-gnome-snap-plugin
Package: gnome-software-plugin-snap
Pin: release *
Pin-Priority: -10
EOF

#############################
# 9.  Final message
#############################
echo "Snap has been disabled. During future 'apt upgrade' snapd may be listed as 'kept back' -- this is expected."
