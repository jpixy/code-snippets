#!/usr/bin/env bash
set -euo pipefail

# 0. 先备份，别手滑
sudo cp -a /etc/apt/preferences.d /etc/apt/preferences.d.bak.$(date +%F)

# 1. 把 snapd 包本身钉死，禁止任何升级再把它拉回来
cat <<'EOF' | sudo tee /etc/apt/preferences.d/nosnap
Package: snapd
Pin: release *
Pin-Priority: -10
EOF

# 2. 停服务、卸软件、清目录（顺序不能反）
sudo systemctl stop snapd.service snapd.socket snapd.seeded.service
sudo systemctl disable snapd.service snapd.socket snapd.seeded.service
sudo systemctl mask snapd.service snapd.socket snapd.seeded.service

# 3. 卸载所有 snap 包（先删应用，最后才删 core）
snap list --all | awk '/disabled/{print $1, $3}' | \
  while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done
snap list | tail -n +2 | awk '{print $1}' | xargs -r sudo snap remove --purge

# 4. 彻底清除 snapd 本体
sudo apt purge snapd -y
sudo apt autoremove --purge -y

# 5. 删掉残余 mount 单元（24.04 新增，不删会报 loop）
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 6. 把 /snap 和 /var/snap 做成空文件，阻止 apt 再建
sudo rm -rf /snap /var/snap /var/cache/snapd
sudo touch /snap /var/snap /var/cache/snapd
sudo chattr +i /snap /var/snap /var/cache/snapd

# 7. 锁定 gnome-software 插件（24.04 软件商店会偷偷装回 snapd）
sudo apt purge gnome-software-plugin-snap -y || true
cat <<'EOF' | sudo tee /etc/apt/preferences.d/no-gnome-snap-plugin
Package: gnome-software-plugin-snap
Pin: release *
Pin-Priority: -10
EOF

echo "Snap 已禁用。下次 apt upgrade 若看到 snapd 被 kept back 属正常现象。"
