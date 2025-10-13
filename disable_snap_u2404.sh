#!/usr/bin/env bash
# disable-snap-u2404.sh - Completely disable Snap on Ubuntu 24.04
# Enhanced version with better error handling, safety checks, and rollback capability

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Rollback function
rollback() {
    warn "Rolling back changes due to error..."
    
    # Remove apt preferences
    sudo rm -f /etc/apt/preferences.d/nosnap /etc/apt/preferences.d/no-gnome-snap-plugin 2>/dev/null || true
    
    # Unmask services
    for unit in snapd.service snapd.socket snapd.seeded.service; do
        sudo systemctl unmask "$unit" 2>/dev/null || true
    done
    
    # Remove immutable attributes
    sudo chattr -i /snap /var/snap /var/cache/snapd 2>/dev/null || true
    
    # Restore directories if they were removed
    sudo mkdir -p /snap /var/snap /var/cache/snapd 2>/dev/null || true
    sudo chmod 755 /snap /var/snap /var/cache/snapd 2>/dev/null || true
    
    error "Rollback completed. Script execution failed."
    exit 1
}

# Set trap for error rollback
trap rollback ERR

# Pre-flight checks
preflight_checks() {
    step "Running pre-flight checks..."
    
    # Check if running on Ubuntu 24.04
    if ! grep -q "24.04" /etc/os-release 2>/dev/null; then
        error "This script is designed for Ubuntu 24.04 only"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "Please run as normal user, not root"
        exit 1
    fi
    
    # Check for sudo privileges
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges"
        exit 1
    fi
    
    info "Pre-flight checks passed"
}

# Backup existing configuration
backup_config() {
    step "Backing up existing configuration..."
    
    local backup_dir="/etc/apt/preferences.d.bak.$(date +%F-%H%M%S)"
    if [[ -d /etc/apt/preferences.d ]]; then
        sudo cp -a /etc/apt/preferences.d "$backup_dir"
        info "Backup created at: $backup_dir"
    else
        warn "No existing preferences.d directory found"
    fi
}

# Configure apt preferences to block snap
configure_apt_preferences() {
    step "Configuring apt preferences to block snap..."
    
    # Block snapd
    cat <<'EOF' | sudo tee /etc/apt/preferences.d/nosnap >/dev/null
Package: snapd
Pin: release *
Pin-Priority: -10
EOF
    
    # Block GNOME snap plugin
    cat <<'EOF' | sudo tee /etc/apt/preferences.d/no-gnome-snap-plugin >/dev/null
Package: gnome-software-plugin-snap
Pin: release *
Pin-Priority: -10
EOF
    
    info "Apt preferences configured"
}

# Remove all installed snaps
remove_snaps() {
    step "Removing installed snaps..."
    
    if ! command -v snap &>/dev/null; then
        warn "snap command not found, skipping snap removal"
        return 0
    fi
    
    local snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l)
    if [[ $snap_count -eq 0 ]]; then
        info "No snaps installed"
        return 0
    fi
    
    info "Found $snap_count installed snaps"
    
    # Remove disabled revisions first
    snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | \
    while read -r snapname revision; do
        if [[ -n "$snapname" && -n "$revision" ]]; then
            info "Removing disabled snap: $snapname (revision: $revision)"
            sudo snap remove "$snapname" --revision="$revision" 2>/dev/null || true
        fi
    done
    
    # Remove all other snaps (excluding snapd itself first)
    snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^snapd$' | \
    while read -r snapname; do
        if [[ -n "$snapname" ]]; then
            info "Removing snap: $snapname"
            sudo snap remove --purge "$snapname" 2>/dev/null || true
        fi
    done
    
    # Remove snapd itself last
    if snap list 2>/dev/null | grep -q '^snapd'; then
        info "Removing snapd core"
        sudo snap remove --purge snapd 2>/dev/null || true
    fi
    
    info "Snap removal completed"
}

# Stop and disable snap services
stop_snap_services() {
    step "Stopping and disabling snap services..."
    
    for unit in snapd.service snapd.socket snapd.seeded.service; do
        if systemctl list-unit-files | grep -q "$unit"; then
            info "Processing service: $unit"
            sudo systemctl stop "$unit" 2>/dev/null || true
            sudo systemctl disable "$unit" 2>/dev/null || true
            sudo systemctl mask "$unit" 2>/dev/null || true
        else
            warn "Service $unit not found"
        fi
    done
    
    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    
    info "Snap services stopped and disabled"
}

# Unmount any lingering snap mounts
unmount_snap_dirs() {
    step "Unmounting snap directories..."
    
    local mounted_snaps=$(mount | grep '/snap' | awk '{print $3}' | wc -l)
    if [[ $mounted_snaps -gt 0 ]]; then
        info "Found $mounted_snaps mounted snap directories"
        mount | grep '/snap' | awk '{print $3}' | \
        while read -r mountpoint; do
            info "Unmounting: $mountpoint"
            sudo umount -lf "$mountpoint" 2>/dev/null || true
        done
    else
        info "No mounted snap directories found"
    fi
}

# Purge snap packages
purge_snap_packages() {
    step "Purging snap packages..."
    
    # Update package list first
    sudo apt update
    
    # Purge snap-related packages
    local packages_to_purge="snapd gnome-software-plugin-snap"
    
    for pkg in $packages_to_purge; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            info "Purging package: $pkg"
        else
            warn "Package $pkg not installed, skipping"
        fi
    done
    
    sudo apt purge -y $packages_to_purge
    sudo apt autoremove --purge -y
    
    info "Snap packages purged"
}

# Clean up snap directories
cleanup_snap_dirs() {
    step "Cleaning up snap directories..."
    
    # Remove snap directories
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /root/snap /home/*/snap 2>/dev/null || true
    
    # Create empty directories with restrictive permissions to prevent recreation
    for dir in /snap /var/snap /var/cache/snapd; do
        sudo mkdir -p "$dir"
        sudo chmod 000 "$dir"
        info "Secured directory: $dir"
    done
    
    info "Snap directories cleaned up"
}

# Verify snap removal
verify_removal() {
    step "Verifying snap removal..."
    
    local verification_passed=true
    
    # Check if snap command is removed
    if command -v snap &>/dev/null; then
        warn "snap command still present"
        verification_passed=false
    else
        info "✓ snap command removed"
    fi
    
    # Check if snap services are stopped
    for unit in snapd.service snapd.socket snapd.seeded.service; do
        if systemctl is-active "$unit" &>/dev/null; then
            warn "Service $unit is still active"
            verification_passed=false
        else
            info "✓ Service $unit is stopped"
        fi
    done
    
    # Check if snap directories are secured
    for dir in /snap /var/snap /var/cache/snapd; do
        if [[ -d "$dir" ]]; then
            local perms=$(stat -c "%a" "$dir" 2>/dev/null || echo "unknown")
            if [[ "$perms" == "000" ]]; then
                info "✓ Directory $dir is secured (perms: 000)"
            else
                warn "Directory $dir has perms: $perms (expected: 000)"
                verification_passed=false
            fi
        else
            warn "Directory $dir does not exist"
            verification_passed=false
        fi
    done
    
    if $verification_passed; then
        info "✓ All verification checks passed"
    else
        warn "Some verification checks failed - manual review recommended"
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "  Ubuntu 24.04 Snap Disable Script - Enhanced"
    echo "=================================================="
    echo ""
    
    preflight_checks
    backup_config
    configure_apt_preferences
    remove_snaps
    stop_snap_services
    unmount_snap_dirs
    purge_snap_packages
    cleanup_snap_dirs
    verify_removal
    
    echo ""
    echo "=================================================="
    info "Snap has been successfully disabled"
    info "During future 'apt upgrade', snapd may be listed as 'kept back' - this is expected"
    warn "Please reboot your system to ensure all changes take effect"
    echo "=================================================="
}

# Run main function
main
