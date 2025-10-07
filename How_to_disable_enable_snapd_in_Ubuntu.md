# How to disable / Enable snap in Ubuntu

## Disable

run

```shell
sudo tee /usr/local/bin/disable-snap.sh > /dev/null <<'EOF'
#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本: sudo $0"
    exit 1
fi

echo "开始禁用 Snap 并配置系统使用 APT..."
echo "=========================================="

# 函数：打印步骤信息
print_step() {
    echo "[$(date +%T)] $1"
}

# 1. 停止并禁用 snap 服务
print_step "停止并禁用 Snap 服务..."
systemctl stop snapd.socket snapd.service 2>/dev/null
systemctl disable snapd.socket snapd.service 2>/dev/null
systemctl mask snapd.socket snapd.service 2>/dev/null

# 2. 卸载所有 snap 包
print_step "卸载所有 Snap 包..."
if command -v snap >/dev/null 2>&1; then
    # 获取已安装的 snap 包列表（排除核心包）
    SNAP_LIST=$(snap list | awk 'NR>1 {print $1}' | grep -v -E '^(snapd|core|core20|core22)$')
    
    for snap_pkg in $SNAP_LIST; do
        echo "正在卸载: $snap_pkg"
        snap remove --purge "$snap_pkg" 2>/dev/null
    done
    
    # 卸载核心 snap 包
    snap remove --purge snapd 2>/dev/null
fi

# 3. 完全移除 snapd
print_step "完全移除 Snapd..."
apt autoremove --purge -y snapd gnome-software-plugin-snap
apt-mark hold snapd

# 4. 清理 snap 目录和缓存
print_step "清理 Snap 目录和缓存..."
rm -rf /var/cache/snapd/
find /home -type d -name "snap" -exec rm -rf {} + 2>/dev/null
find /root -type d -name "snap" -exec rm -rf {} + 2>/dev/null

# 5. 配置 APT 偏好设置
print_step "配置 APT 偏好设置..."
cat > /etc/apt/preferences.d/no-snap.pref <<'PREFEOF'
Package: snapd
Pin: release *
Pin-Priority: -10

Package: chromium*
Pin: release *
Pin-Priority: -10

Package: firefox*
Pin: release *
Pin-Priority: 1000
PREFEOF

# 6. 配置阻止自动安装 snap
cat > /etc/apt/apt.conf.d/99no-snap <<'APTEOP'
APT::Get::AllowUnauthenticated "false";
APT::Install-Suggests "false";
APT::AutoRemove::SuggestsImportant "false";
APT::AutoRemove::RecommendsImportant "false";
DPkg::Post-Invoke { "if [ -d /var/cache/snapd ]; then rm -rf /var/cache/snapd; fi"; };
APTEOP

# 7. 配置 Firefox 使用 deb 版本
print_step "配置 Firefox deb 版本..."
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null

cat > /etc/apt/preferences.d/mozilla-firefox <<'FFEOF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
FFEOF

# 8. 从 sources.list 中移除 snap 相关源
print_step "清理软件源中的 Snap 源..."
sed -i '/snap/d' /etc/apt/sources.list
sed -i '/snapd/d' /etc/apt/sources.list.d/* 2>/dev/null

# 9. 更新系统
print_step "更新系统包列表..."
apt update

# 10. 安装 Firefox deb 版本（如果之前有 snap 版本）
print_step "安装 Firefox deb 版本..."
apt install -y firefox

# 11. 验证配置
print_step "验证配置..."
echo "=== 验证 Snap 状态 ==="
if ! command -v snap >/dev/null 2>&1; then
    echo "✓ Snap 已完全移除"
else
    echo "⚠ Snap 命令仍然存在，但已被禁用"
fi

echo "=== 检查 Snap 服务 ==="
systemctl status snapd 2>/dev/null | grep -E "(Active:|Loaded:)" | head -2

echo "=== 检查已安装的 Snap 包 ==="
if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null || echo "无 Snap 包"
else
    echo "Snap 命令不存在"
fi

echo "=========================================="
echo "配置完成！系统现在只使用 APT 包管理器。"
echo "注意事项："
echo "1. 某些软件（如 Firefox）已切换为 deb 版本"
echo "2. 软件中心可能无法使用某些功能"
echo "3. 建议使用: sudo apt update && sudo apt upgrade 更新系统"
echo "4. 如需安装软件，请使用: sudo apt install <package-name>"
EOF

# 设置脚本权限
sudo chmod +x /usr/local/bin/disable-snap.sh
```


## Enable

run

```shell
sudo tee /usr/local/bin/enable-snap.sh > /dev/null <<'EOF'
#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本: sudo $0"
    exit 1
fi

echo "恢复 Snap 支持..."

# 取消禁用服务
systemctl unmask snapd.socket snapd.service
systemctl enable snapd.socket snapd.service

# 移除配置文件
rm -f /etc/apt/preferences.d/no-snap.pref
rm -f /etc/apt/apt.conf.d/99no-snap
rm -f /etc/apt/preferences.d/mozilla-firefox

# 移除阻止标记
apt-mark unhold snapd

# 重新安装 snapd
apt update
apt install -y snapd

echo "Snap 支持已恢复，建议重启系统。"
EOF

sudo chmod +x /usr/local/bin/enable-snap.sh
```
