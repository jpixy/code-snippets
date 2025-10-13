#!/usr/bin/env bash
# enable-snap-u2404.sh - Re-enable Snap on Ubuntu 24.04
# Restores Snap functionality after using the disable script

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

# Remove apt preferences blocking snap
remove_apt_blocks() {
    step "Removing apt preference blocks..."
    
    local files_removed=0
    
    if [[ -f /etc/apt/preferences.d/nosnap ]]; then
        sudo rm -f /etc/apt/preferences.d/nosnap
        info "Removed: /etc/apt/preferences.d/nosnap"
        files_removed=$((files_removed + 1))
    fi
    
    if [[ -f /etc/apt/preferences.d/no-gnome-snap-plugin ]]; then
        sudo rm -f /etc/apt/preferences.d/no-gnome-snap-plugin
        info "Removed: /etc/apt/preferences.d/no-gnome-snap-plugin"
        files_removed=$((files_removed + 1))
    fi
    
    if [[ $files_removed -eq 0 ]]; then
        warn "No snap-related apt preference files found"
    else
        info "Removed $files_removed apt preference files"
    fi
}

# Restore snap directories permissions
restore_snap_dirs() {
    step "Restoring snap directories..."
    
    # Remove restrictive permissions and restore proper directory structure
    for dir in /snap /var/snap /var/cache/snapd; do
        if [[ -d "$dir" ]]; then
            # Remove any restrictive permissions
            sudo chmod 755 "$dir" 2>/dev/null || true
            sudo chattr -i "$dir" 2>/dev/null || true
            info "Restored permissions for: $dir"
        else
            # Create directory if it doesn't exist
            sudo mkdir -p "$dir"
            sudo chmod 755 "$dir"
            info "Created directory: $dir"
        fi
    done
    
    # Ensure proper ownership
    sudo chown root:root /snap /var/snap /var/cache/snapd 2>/dev/null || true
}

# Unmask and enable snap services
enable_snap_services() {
    step "Enabling snap services..."
    
    for unit in snapd.socket snapd.service snapd.seeded.service; do
        if systemctl list-unit-files | grep -q "$unit"; then
            # Unmask first
            sudo systemctl unmask "$unit" 2>/dev/null || true
            
            # Then enable and start
            sudo systemctl enable "$unit" 2>/dev/null || true
            
            info "Enabled service: $unit"
        else
            warn "Service $unit not found in systemd"
        fi
    done
    
    # Reload systemd
    sudo systemctl daemon-reload
}

# Install snapd package
install_snapd() {
    step "Installing snapd package..."
    
    # Update package list
    sudo apt update
    
    # Check if snapd is already installed
    if dpkg -l | grep -q "^ii  snapd "; then
        info "snapd is already installed"
        
        # Reinstall to ensure complete restoration
        sudo apt install --reinstall snapd -y
    else
        # Install fresh
        sudo apt install snapd -y
    fi
    
    # Install GNOME snap plugin if GNOME is present
    if dpkg -l | grep -q "gnome-shell"; then
        info "GNOME detected, installing snap plugin..."
        sudo apt install gnome-software-plugin-snap -y
    fi
    
    info "Snap packages installed"
}

# Start snap services
start_snap_services() {
    step "Starting snap services..."
    
    # Start the socket first (triggered by systemd on first use)
    if systemctl list-unit-files | grep -q "snapd.socket"; then
        sudo systemctl start snapd.socket
        info "Started snapd.socket"
        
        # Wait a moment for socket to be ready
        sleep 2
    fi
    
    # Start the main service
    if systemctl list-unit-files | grep -q "snapd.service"; then
        sudo systemctl start snapd.service
        info "Started snapd.service"
    fi
    
    # Start seeded service to initialize snap environment
    if systemctl list-unit-files | grep -q "snapd.seeded.service"; then
        sudo systemctl start snapd.seeded.service
        info "Started snapd.seeded.service"
    fi
}

# Initialize snap environment
initialize_snap() {
    step "Initializing snap environment..."
    
    # Wait for snapd to be ready
    local max_attempts=30
    local attempt=1
    
    info "Waiting for snapd to become ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if snap list &>/dev/null; then
            info "Snapd is ready after $attempt seconds"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            warn "Snapd did not become ready after $max_attempts seconds"
            warn "This may be normal - snap will initialize on first use"
            return 0
        fi
        
        sleep 1
        attempt=$((attempt + 1))
    done
    
    # Ensure snap core is installed
    if snap list 2>/dev/null | grep -q "^core22"; then
        info "Snap core is already installed"
    else
        info "Installing snap core..."
        sudo snap install core
    fi
}

# Verify snap restoration
verify_restoration() {
    step "Verifying snap restoration..."
    
    local verification_passed=true
    
    # Check if snap command is available
    if command -v snap &>/dev/null; then
        info "✓ snap command is available"
    else
        error "✗ snap command not found"
        verification_passed=false
    fi
    
    # Check if snap services are enabled
    for unit in snapd.socket snapd.service; do
        if systemctl is-enabled "$unit" &>/dev/null; then
            info "✓ Service $unit is enabled"
        else
            warn "✗ Service $unit is not enabled"
            verification_passed=false
        fi
    done
    
    # Check if snap directories are accessible
    for dir in /snap /var/snap /var/cache/snapd; do
        if [[ -d "$dir" && -r "$dir" && -w "$dir" ]]; then
            info "✓ Directory $dir is accessible"
        else
            warn "✗ Directory $dir is not accessible"
            verification_passed=false
        fi
    done
    
    # Test basic snap functionality
    if snap --version &>/dev/null; then
        info "✓ Snap version check works"
        
        # Test listing snaps (may be empty, that's OK)
        if snap list &>/dev/null; then
            local snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l)
            info "✓ Found $snap_count installed snaps"
        else
            warn "✗ Snap list command failed"
            verification_passed=false
        fi
    else
        error "✗ Snap version check failed"
        verification_passed=false
    fi
    
    if $verification_passed; then
        info "✓ All verification checks passed"
    else
        warn "Some verification checks failed - manual review recommended"
    fi
}

# Display usage information
show_usage() {
    echo "=================================================="
    echo "  Ubuntu 24.04 Snap Enable Script"
    echo "=================================================="
    echo ""
    echo "This script re-enables Snap functionality after it"
    echo "has been disabled by the disable-snap-u2404.sh script."
    echo ""
    echo "What it does:"
    echo "• Removes apt preference blocks"
    echo "• Restores snap directory permissions"
    echo "• Installs/reinstalls snapd package"
    echo "• Enables and starts snap services"
    echo "• Initializes snap environment"
    echo ""
    echo "Usage: ./enable-snap-u2404.sh"
    echo ""
}

# Main execution
main() {
    show_usage
    
    read -p "Do you want to continue enabling Snap? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled"
        exit 0
    fi
    
    preflight_checks
    remove_apt_blocks
    restore_snap_dirs
    install_snapd
    enable_snap_services
    start_snap_services
    initialize_snap
    verify_restoration
    
    echo ""
    echo "=================================================="
    info "Snap has been successfully re-enabled"
    info "You can now install snaps using: snap install <package>"
    warn "If you encounter any issues, try rebooting your system"
    echo "=================================================="
}

# Run main function
main
