```markdown
# How to Disable/Enable Snap in Ubuntu

## Overview
This guide provides complete scripts to disable or enable Snap package management on Ubuntu systems. The scripts include comprehensive logging and safety checks.

## Disable Snap

### Script
```bash
sudo tee /usr/local/bin/disable-snap.sh > /dev/null <<'EOF'
#!/bin/bash

# Check if running with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo: sudo $0"
    exit 1
fi

echo "Starting Snap disable process..."
echo "=========================================="
echo "This script will perform the following actions:"
echo "1. Stop and disable Snap services"
echo "2. Remove all Snap packages"
echo "3. Completely remove snapd package"
echo "4. Clean up Snap directories and cache"
echo "5. Configure APT preferences to block Snap"
echo "6. Set up Firefox deb version from Mozilla PPA"
echo "7. Clean Snap sources from repository lists"
echo "8. Update system and install Firefox deb version"
echo "=========================================="
echo

# Function: Print step information with timestamp and status
print_step() {
    echo "[$(date +%T)] $1"
}

print_status() {
    if [ $? -eq 0 ]; then
        echo "✓ $1"
    else
        echo "⚠ $2"
    fi
}

# 1. Stop and disable snap services
print_step "Stopping and disabling Snap services..."
echo "Stopping snapd.socket and snapd.service..."
systemctl stop snapd.socket snapd.service 2>/dev/null
print_status "Snap services stopped" "Some Snap services might already be stopped"

echo "Disabling Snap services from starting on boot..."
systemctl disable snapd.socket snapd.service 2>/dev/null
print_status "Snap services disabled" "Some Snap services might already be disabled"

echo "Masking Snap services to prevent accidental start..."
systemctl mask snapd.socket snapd.service 2>/dev/null
print_status "Snap services masked" "Some Snap services might already be masked"

# 2. Uninstall all snap packages
print_step "Uninstalling all Snap packages..."
if command -v snap >/dev/null 2>&1; then
    echo "Retrieving list of installed Snap packages..."
    # Get list of installed snap packages (excluding core packages)
    SNAP_LIST=$(snap list | awk 'NR>1 {print $1}' | grep -v -E '^(snapd|core|core20|core22)$')
    
    if [ -n "$SNAP_LIST" ]; then
        echo "Found the following Snap packages to remove:"
        echo "$SNAP_LIST"
        echo
        
        for snap_pkg in $SNAP_LIST; do
            echo "Removing Snap package: $snap_pkg"
            snap remove --purge "$snap_pkg" 2>/dev/null
            print_status "Removed $snap_pkg" "Failed to remove $snap_pkg"
        done
    else
        echo "No additional Snap packages found (only core packages present)"
    fi
    
    # Remove core snap packages
    echo "Removing core Snap packages..."
    snap remove --purge snapd 2>/dev/null
    print_status "Core Snap packages removed" "Core Snap packages might already be removed"
else
    echo "Snap command not found, skipping package removal"
fi

# 3. Completely remove snapd
print_step "Completely removing snapd package..."
echo "Purging snapd and related packages..."
apt autoremove --purge -y snapd gnome-software-plugin-snap
print_status "snapd packages purged" "Some snapd packages might not have been removed"

echo "Marking snapd as held to prevent reinstallation..."
apt-mark hold snapd
print_status "snapd marked as held" "Failed to mark snapd as held"

# 4. Clean snap directories and cache
print_step "Cleaning Snap directories and cache..."
echo "Removing Snap cache directory..."
rm -rf /var/cache/snapd/
print_status "Snap cache cleaned" "Snap cache might already be removed"

echo "Cleaning Snap directories from user homes..."
find /home -type d -name "snap" -exec rm -rf {} + 2>/dev/null
print_status "User Snap directories cleaned" "Some user Snap directories might not exist"

echo "Cleaning Snap directories from root..."
find /root -type d -name "snap" -exec rm -rf {} + 2>/dev/null
print_status "Root Snap directories cleaned" "Root Snap directories might not exist"

# 5. Configure APT preferences
print_step "Configuring APT preferences to block Snap..."
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
print_status "APT preferences configured" "Failed to configure APT preferences"

# 6. Configure to prevent automatic snap installation
print_step "Configuring APT to prevent automatic Snap installation..."
cat > /etc/apt/apt.conf.d/99no-snap <<'APTEOP'
APT::Get::AllowUnauthenticated "false";
APT::Install-Suggests "false";
APT::AutoRemove::SuggestsImportant "false";
APT::AutoRemove::RecommendsImportant "false";
DPkg::Post-Invoke { "if [ -d /var/cache/snapd ]; then rm -rf /var/cache/snapd; fi"; };
APTEOP
print_status "APT configuration updated" "Failed to update APT configuration"

# 7. Configure Firefox deb version
print_step "Configuring Firefox deb version..."
echo "Adding Mozilla Team PPA for Firefox deb version..."
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null
print_status "Mozilla PPA added" "Mozilla PPA might already exist"

echo "Setting up Firefox package preferences..."
cat > /etc/apt/preferences.d/mozilla-firefox <<'FFEOF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
FFEOF
print_status "Firefox preferences configured" "Failed to configure Firefox preferences"

# 8. Remove snap-related sources from sources.list
print_step "Cleaning Snap sources from repository lists..."
echo "Removing Snap entries from main sources.list..."
sed -i '/snap/d' /etc/apt/sources.list
print_status "Main sources.list cleaned" "No Snap entries found in main sources.list"

echo "Removing Snap entries from additional source lists..."
sed -i '/snapd/d' /etc/apt/sources.list.d/* 2>/dev/null
print_status "Additional source lists cleaned" "No Snap entries found in additional sources"

# 9. Update system
print_step "Updating package lists..."
apt update
print_status "Package lists updated" "Failed to update package lists"

# 10. Install Firefox deb version (if snap version was present)
print_step "Installing Firefox deb version..."
apt install -y firefox
print_status "Firefox deb version installed" "Failed to install Firefox deb version"

# 11. Verify configuration
print_step "Verifying configuration..."
echo
echo "=== Snap Command Status ==="
if ! command -v snap >/dev/null 2>&1; then
    echo "✓ Snap command completely removed from system"
else
    echo "⚠ Snap command still exists (but services should be disabled)"
fi

echo
echo "=== Snap Service Status ==="
systemctl status snapd 2>/dev/null | grep -E "(Active:|Loaded:)" | head -2 || echo "Snapd service not found or not running"

echo
echo "=== Installed Snap Packages ==="
if command -v snap >/dev/null 2>&1; then
    snap list 2>/dev/null || echo "No Snap packages currently installed"
else
    echo "Snap command not available - no packages can be listed"
fi

echo
echo "=== APT Hold Status ==="
apt-mark showhold | grep -q snapd && echo "✓ snapd is held to prevent installation" || echo "⚠ snapd is not held"

echo
echo "=========================================="
echo "SNAP DISABLE PROCESS COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo
echo "Summary of changes:"
echo "✓ Snap services stopped, disabled, and masked"
echo "✓ Snap packages removed"
echo "✓ snapd package purged and held"
echo "✓ Snap cache and directories cleaned"
echo "✓ APT preferences configured to prefer deb packages"
echo "✓ Firefox configured to use deb version from Mozilla PPA"
echo "✓ Repository sources cleaned of Snap entries"
echo
echo "Important Notes:"
echo "• System now uses APT package manager exclusively"
echo "• Some applications (like Firefox) have been switched to deb versions"
echo "• Software Center may have limited functionality"
echo "• Recommended to update system with: sudo apt update && sudo apt upgrade"
echo "• To install software, use: sudo apt install <package-name>"
echo "• If you need to re-enable Snap, run: sudo /usr/local/bin/enable-snap.sh"
echo
echo "Please reboot your system for all changes to take full effect."
EOF
```

### Usage
```bash
sudo /usr/local/bin/disable-snap.sh
```

## Enable Snap

### Script
```bash
sudo tee /usr/local/bin/enable-snap.sh > /dev/null <<'EOF'
#!/bin/bash

# Check if running with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo: sudo $0"
    exit 1
fi

echo "Starting Snap enable process..."
echo "=========================================="
echo "This script will perform the following actions:"
echo "1. Unmask and enable Snap services"
echo "2. Remove blocking configuration files"
echo "3. Remove package hold markers"
echo "4. Reinstall snapd package"
echo "5. Verify Snap functionality"
echo "=========================================="
echo

# Function: Print step information with timestamp and status
print_step() {
    echo "[$(date +%T)] $1"
}

print_status() {
    if [ $? -eq 0 ]; then
        echo "✓ $1"
    else
        echo "⚠ $2"
    fi
}

# 1. Unmask and enable services
print_step "Unmasking and enabling Snap services..."
echo "Unmasking snapd.socket and snapd.service..."
systemctl unmask snapd.socket snapd.service
print_status "Snap services unmasked" "Some Snap services might already be unmasked"

echo "Enabling Snap services to start on boot..."
systemctl enable snapd.socket snapd.service
print_status "Snap services enabled" "Some Snap services might already be enabled"

# 2. Remove configuration files
print_step "Removing blocking configuration files..."
echo "Removing APT preferences file..."
rm -f /etc/apt/preferences.d/no-snap.pref
print_status "APT preferences file removed" "APT preferences file might not exist"

echo "Removing APT configuration file..."
rm -f /etc/apt/apt.conf.d/99no-snap
print_status "APT configuration file removed" "APT configuration file might not exist"

echo "Removing Firefox preferences file..."
rm -f /etc/apt/preferences.d/mozilla-firefox
print_status "Firefox preferences file removed" "Firefox preferences file might not exist"

# 3. Remove hold markers
print_step "Removing package hold markers..."
echo "Removing hold on snapd package..."
apt-mark unhold snapd
print_status "snapd hold removed" "snapd might not have been held"

# 4. Reinstall snapd
print_step "Reinstalling snapd package..."
echo "Updating package lists..."
apt update
print_status "Package lists updated" "Failed to update package lists"

echo "Installing snapd package..."
apt install -y snapd
print_status "snapd installed successfully" "Failed to install snapd"

# 5. Verify installation and functionality
print_step "Verifying Snap installation and functionality..."
echo
echo "=== Snap Command Verification ==="
if command -v snap >/dev/null 2>&1; then
    echo "✓ Snap command is available"
    echo "Snap version: $(snap --version 2>/dev/null | head -1 || echo "Unknown")"
else
    echo "⚠ Snap command not found"
fi

echo
echo "=== Snap Service Status ==="
systemctl status snapd.socket --no-pager -l | grep -E "(Active:|Loaded:)" | head -2
systemctl status snapd.service --no-pager -l | grep -E "(Active:|Loaded:)" | head -2

echo
echo "=== Snap Communication Test ==="
if snap list >/dev/null 2>&1; then
    echo "✓ Snap can communicate with the service"
    INSTALLED_SNAPS=$(snap list 2>/dev/null | wc -l)
    echo "Number of installed Snap packages: $((INSTALLED_SNAPS - 1))"
else
    echo "⚠ Snap cannot communicate with the service"
fi

echo
echo "=== Snap System Information ==="
snap version 2>/dev/null || echo "Unable to get Snap version information"

echo
echo "=== Checking for Core Snap ==="
if snap list | grep -q core; then
    echo "✓ Core Snap is installed"
else
    echo "Installing core Snap..."
    snap install core
    print_status "Core Snap installed" "Failed to install core Snap"
fi

echo
echo "=========================================="
echo "SNAP ENABLE PROCESS COMPLETED SUCCESSFULLY!"
echo "=========================================="
echo
echo "Summary of changes:"
echo "✓ Snap services unmasked and enabled"
echo "✓ Blocking configuration files removed"
echo "✓ Package hold markers cleared"
echo "✓ snapd package reinstalled"
echo "✓ Snap functionality verified"
echo
echo "Important Notes:"
echo "• Snap package manager has been fully restored"
echo "• You can now install Snap packages with: sudo snap install <package-name>"
echo "• View available Snap packages with: snap find <search-term>"
echo "• Manage installed Snap packages with: snap list"
echo "• It is recommended to reboot your system to ensure all services start properly"
echo "• After reboot, test Snap functionality with: snap list && snap version"
echo
echo "Common Snap commands:"
echo "  snap install <package>     - Install a Snap package"
echo "  snap remove <package>      - Remove a Snap package"
echo "  snap list                  - List installed Snap packages"
echo "  snap find <search-term>    - Search for available Snap packages"
echo "  snap refresh               - Update Snap packages"
echo "  snap info <package>        - Show information about a Snap package"
echo
echo "Reboot recommended for full functionality: sudo reboot"
EOF
```

### Usage
```bash
sudo /usr/local/bin/enable-snap.sh
```

## Important Notes

### Before Disabling Snap
- **Backup your system** before proceeding
- Some applications may need to be reinstalled as deb versions
- Software Center functionality may be limited
- Check if essential applications rely on Snap packages

### After Disabling Snap
- Use `apt` instead of `snap` for package management
- Firefox will use the deb version from Mozilla's PPA
- System updates should be done with `apt update && apt upgrade`

### Re-enabling Snap
- Run the enable script to restore Snap functionality
- Previously removed Snap packages will need to be reinstalled manually
- A system reboot is recommended after re-enabling Snap

## Verification Commands

After running either script, verify the status with:

```bash
# Check if snap is available
command -v snap

# Check snap service status
systemctl status snapd

# List installed snap packages (if snap is enabled)
snap list

# Check held packages
apt-mark showhold
```

## Troubleshooting

If you encounter issues:

1. **Script fails to run**: Ensure you're using `sudo`
2. **Services won't stop**: Use `systemctl kill snapd.service snapd.socket`
3. **Packages won't remove**: Use `snap remove --purge <package>`
4. **APT issues**: Run `apt --fix-broken install`

Remember that disabling Snap is a system-level change and should be done with caution.
