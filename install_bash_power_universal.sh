#!/bin/bash

# install_bash_power_universal.sh (English Version)
# Enhanced Bash Environment Installation Script (RHEL/Ubuntu Compatible)

set -e

echo "🚀 Starting Enhanced Bash Environment Deployment (RHEL/Ubuntu Compatible)..."

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect Operating System Type
detect_os() {
    if [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
        echo "ubuntu"
    elif [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ $ID == "rhel" || $ID == "centos" || $ID == "fedora" ]]; then
            echo "rhel"
        elif [[ $ID == "ubuntu" || $ID == "debian" ]]; then
            echo "ubuntu"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

# Check if Command Exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Generic Function to Install Binary from GitHub (with Retry)
install_binary_from_github() {
    local tool_name="$1"
    local download_url="$2"
    local binary_name="$3"
    local extract_dir="$4"
    
    log_info "Downloading $tool_name from GitHub..."
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir" || return 1
    
    if curl -fsSL "$download_url" -o package.tar.gz; then
        tar -xzf package.tar.gz
        
        # Find binary file
        local binary_path=$(find . -name "$binary_name" -type f | head -n 1)
        if [ -n "$binary_path" ]; then
            sudo install -m 755 "$binary_path" /usr/local/bin/
            rm -rf "$tmp_dir"
            log_success "$tool_name installed successfully"
            return 0
        fi
    fi
    
    rm -rf "$tmp_dir"
    log_error "$tool_name installation failed"
    return 1
}

# Install All Dependencies
install_dependencies() {
    log_info "Installing system dependencies (OS: $OS_TYPE)..."
    
    case $OS_TYPE in
        "ubuntu"|"debian")
            log_info "Updating apt package list..."
            if ! sudo apt-get update; then
                log_warning "apt update failed, continuing with installation..."
            fi
            
            log_info "Installing core dependencies..."
            sudo apt-get install -y \
                curl \
                git \
                bash-completion \
                tree \
                htop \
                ncdu \
                wget \
                unzip \
                zip \
                make \
                build-essential
            
            # Try to install modern tools (allow failures)
            sudo apt-get install -y bat ripgrep fd-find 2>/dev/null || log_warning "Some modern tools failed to install via apt, will use alternative methods"
            
            # Create fd symlink (Ubuntu calls it fdfind)
            if command_exists fdfind && ! command_exists fd; then
                sudo ln -sf $(which fdfind) /usr/local/bin/fd
                log_success "Created fd symlink"
            fi
            ;;
            
        "rhel"|"centos"|"fedora")
            # Detect RHEL version
            local rhel_version=""
            if [ -f /etc/redhat-release ]; then
                rhel_version=$(grep -oP '(?<=release )\d+' /etc/redhat-release | head -n1)
            fi
            
            # Install EPEL repository
            if [ -n "$rhel_version" ] && [ "$rhel_version" -ge 7 ]; then
                log_info "Detected RHEL/CentOS $rhel_version, installing EPEL repository..."
                if command_exists dnf; then
                    sudo dnf install -y epel-release 2>/dev/null || log_warning "EPEL installation failed"
                else
                    sudo yum install -y epel-release 2>/dev/null || log_warning "EPEL installation failed"
                fi
            fi
            
            if command_exists dnf; then
                log_info "Installing dependencies using dnf..."
                sudo dnf install -y \
                    curl \
                    git \
                    bash-completion \
                    tree \
                    htop \
                    ncdu \
                    wget \
                    unzip \
                    zip \
                    make \
                    gcc \
                    gcc-c++ \
                    util-linux-user
                
                # Try to install modern tools
                sudo dnf install -y bat ripgrep fd-find 2>/dev/null || log_warning "Some modern tools need manual installation"
            else
                log_info "Installing dependencies using yum..."
                sudo yum install -y \
                    curl \
                    git \
                    bash-completion \
                    tree \
                    htop \
                    ncdu \
                    wget \
                    unzip \
                    zip \
                    make \
                    gcc \
                    gcc-c++ \
                    util-linux-user
            fi
            
            # RHEL7/CentOS7 special handling - manually install modern tools
            if [ "$rhel_version" = "7" ]; then
                log_info "RHEL/CentOS 7 detected, manually installing modern tools..."
                
                # Install bat
                if ! command_exists bat; then
                    install_binary_from_github "bat" \
                        "https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-x86_64-unknown-linux-gnu.tar.gz" \
                        "bat" \
                        "bat-*"
                fi
                
                # Install ripgrep
                if ! command_exists rg; then
                    install_binary_from_github "ripgrep" \
                        "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz" \
                        "rg" \
                        "ripgrep-*"
                fi
                
                # Install fd
                if ! command_exists fd; then
                    install_binary_from_github "fd" \
                        "https://github.com/sharkdp/fd/releases/download/v9.0.0/fd-v9.0.0-x86_64-unknown-linux-gnu.tar.gz" \
                        "fd" \
                        "fd-*"
                fi
            fi
            ;;
        *)
            log_error "Unknown system type: $OS_TYPE"
            return 1
            ;;
    esac
    
    # Verify core dependencies
    log_info "Verifying core dependencies installation..."
    local missing_deps=()
    
    for dep in curl git; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "The following core dependencies failed to install: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All dependencies installed successfully"
    return 0
}

# Backup Existing Configuration
backup_config() {
    log_info "Backing up existing configuration..."
    
    # Create backup directory
    local backup_dir="$HOME/.bash_config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup .bashrc
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc "$backup_dir/bashrc"
        log_success "Backed up .bashrc"
    fi
    
    # Backup .bash_profile
    if [ -f ~/.bash_profile ]; then
        cp ~/.bash_profile "$backup_dir/bash_profile"
        log_success "Backed up .bash_profile"
    fi
    
    # Backup Starship configuration
    if [ -f ~/.config/starship.toml ]; then
        mkdir -p "$backup_dir/.config"
        cp ~/.config/starship.toml "$backup_dir/.config/"
        log_success "Backed up Starship configuration"
    fi
    
    echo "All backup files saved in: $backup_dir"
}

# Install Starship
install_starship() {
    log_info "Installing Starship..."
    
    if command_exists starship; then
        log_success "Starship already installed"
        return 0
    fi
    
    # Method 1: Use official installation script (preferred)
    log_info "Installing Starship using official script..."
    if curl -fsSL https://starship.rs/install.sh | sh -s -- -y; then
        log_success "Starship installation completed"
        return 0
    fi
    
    # Method 2: Use package manager
    log_info "Trying to install via package manager..."
    case $OS_TYPE in
        "ubuntu"|"debian")
            if command_exists apt && sudo apt install -y starship 2>/dev/null; then
                log_success "Starship installed via apt"
                return 0
            fi
            ;;
        "rhel"|"centos"|"fedora")
            if command_exists dnf && sudo dnf install -y starship 2>/dev/null; then
                log_success "Starship installed via dnf"
                return 0
            elif command_exists yum && sudo yum install -y starship 2>/dev/null; then
                log_success "Starship installed via yum"
                return 0
            fi
            ;;
    esac
    
    # Method 3: Manual binary download
    log_info "Trying manual Starship installation..."
    local starship_binary="/usr/local/bin/starship"
    if sudo curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz | \
       sudo tar -xzf - -C /usr/local/bin; then
        sudo chmod +x "$starship_binary"
        log_success "Starship installed manually"
        return 0
    fi
    
    log_warning "Starship installation failed, will use fallback prompt"
    return 1
}

# Install fzf
install_fzf() {
    log_info "Installing fzf..."
    
    if command_exists fzf; then
        log_success "fzf already installed"
        return 0
    fi
    
    # Method 1: Use package manager
    case $OS_TYPE in
        "ubuntu"|"debian")
            if sudo apt-get install -y fzf 2>/dev/null; then
                log_success "fzf installed via apt"
                return 0
            fi
            ;;
        "rhel"|"centos"|"fedora")
            if command_exists dnf && sudo dnf install -y fzf 2>/dev/null; then
                log_success "fzf installed via dnf"
                return 0
            elif command_exists yum && sudo yum install -y fzf 2>/dev/null; then
                log_success "fzf installed via yum"
                return 0
            fi
            ;;
    esac
    
    # Method 2: Install using Git
    log_info "Installing fzf using Git..."
    if ! command_exists git; then
        log_error "Git not available, cannot install fzf"
        return 1
    fi
    
    local fzf_dir="$HOME/.fzf"
    if [ -d "$fzf_dir" ]; then
        log_info "Updating existing fzf installation..."
        (cd "$fzf_dir" && git pull && ./install --all --no-update-rc)
    else
        log_info "Cloning fzf repository..."
        if git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"; then
            "$fzf_dir/install" --all --no-update-rc
        else
            log_error "fzf clone failed"
            return 1
        fi
    fi
    
    if command_exists fzf; then
        log_success "fzf installation completed"
        return 0
    else
        log_warning "fzf installation failed"
        return 1
    fi
}

# Create Enhanced bashrc Configuration
create_enhanced_bashrc() {
    log_info "Creating enhanced Bash configuration..."
    
    # Detect tool availability
    local has_fzf=$(command_exists fzf && echo "true" || echo "false")
    local has_bat=$(command_exists bat && echo "true" || echo "false")
    local has_starship=$(command_exists starship && echo "true" || echo "false")
    
    # Handle Ubuntu's fd command name difference
    local fd_cmd="fd"
    if command_exists fdfind && ! command_exists fd; then
        fd_cmd="fdfind"
    fi
    
    # Use double-quoted heredoc for variable expansion
    cat > ~/.bashrc.enhanced << EOF
#!/bin/bash
# =============================================
# Enhanced Bash Configuration (RHEL/Ubuntu Compatible)
# Auto-generated on $(date)
# OS: $OS_TYPE
# =============================================

# === Basic Configuration ===
export EDITOR='vim'
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar

# === Color Support ===
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# === Core Aliases ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -laht'
alias ltr='ls -lahtr'

EOF

    # Conditionally add bat aliases
    if [ "$has_bat" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === bat Replaces cat ===
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat --paging=always'
fi

EOF
    fi

    # Add Git aliases
    cat >> ~/.bashrc.enhanced << 'EOF'
# === Git Aliases ===
alias gst='git status'
alias gco='git checkout'
alias gc='git commit'
alias gcm='git commit -m'
alias gcam='git commit -am'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gaa='git add .'
alias gb='git branch'
alias gba='git branch -a'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gps='git push'
alias gpl='git pull'
alias gfp='git fetch --prune'
alias gcl='git clone'
alias gsw='git switch'
alias gswc='git switch -c'
alias grh='git reset --hard'

# === Directory Navigation ===
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# === Development Tool Aliases ===
alias nr='npm run'
alias ni='npm install'
alias nid='npm install --save-dev'
alias ns='npm start'
alias nt='npm test'
alias y='yarn'
alias yr='yarn run'
alias ys='yarn start'

# === System Monitoring ===
alias cpucore='grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown"'
alias meminfo='free -h 2>/dev/null || echo "free command not available"'
alias diskusage='df -h'
alias folderusage='du -sh ./* 2>/dev/null || du -sh * 2>/dev/null'

EOF

    # Add fzf configuration (if available)
    if [ "$has_fzf" = "true" ]; then
        # This part needs double quotes to expand fd_cmd
        cat >> ~/.bashrc.enhanced << EOF
# === fzf Configuration ===
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# fzf history search
fh() {
  local selected_command
  selected_command=\$(history | fzf +s --tac | sed 's/ *[0-9]* *//')
  [ -n "\$selected_command" ] && eval "\$selected_command"
}

# fzf directory navigation
fcd() {
  local dir
  dir=\$($fd_cmd --type d 2>/dev/null | fzf)
  [ -n "\$dir" ] && cd "\$dir"
}

# fzf file editing
fe() {
  local file
  file=\$(fzf --preview 'head -100 {}') && \${EDITOR:-vim} "\$file"
}

EOF
    fi

    # Add auto-completion
    cat >> ~/.bashrc.enhanced << 'EOF'
# === Auto-completion ===
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  elif [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
  fi
fi

# Git auto-completion
if [ -f /usr/share/bash-completion/completions/git ]; then
    . /usr/share/bash-completion/completions/git
elif [ -f /etc/bash_completion.d/git ]; then
    . /etc/bash_completion.d/git
fi

EOF

    # Add Starship or fallback prompt
    if [ "$has_starship" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === Starship Prompt ===
eval "$(starship init bash)"

EOF
    else
        cat >> ~/.bashrc.enhanced << 'EOF'
# === Fallback Prompt ===
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;31m\]$(parse_git_branch)\[\033[00m\]\$ '

EOF
    fi

    # Add local configuration and welcome message - use double quotes to expand OS_TYPE
    cat >> ~/.bashrc.enhanced << EOF
# === Local Configuration ===
[ -f ~/.bash_aliases.local ] && source ~/.bash_aliases.local

# === Welcome Message ===
echo -e "\033[1;32m🚀 Enhanced Bash Environment Loaded! ($OS_TYPE)\033[0m"
echo -e "Available commands: \033[1;33mgst, fh, fcd, fe\033[0m"
EOF

    log_success "Enhanced .bashrc created successfully"
}

# Create Starship Configuration
create_starship_config() {
    log_info "Creating Starship configuration..."
    
    mkdir -p ~/.config
    
    cat > ~/.config/starship.toml << 'EOF'
# Starship Configuration - RHEL/Ubuntu Compatible

format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = false
style = "bold blue"

[git_branch]
format = "[$branch]($style) "
style = "bold purple"

[git_status]
conflicted = "═"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕"
untracked = "?${count}"
modified = "!${count}"
staged = "+${count}"
style = "bold yellow"

[cmd_duration]
format = "took [$duration]($style) "
style = "yellow"
min_time = 2000

[memory_usage]
disabled = false
threshold = 75
format = "mem: $ram "

[time]
disabled = false
format = "[$time]($style) "
style = "bright-black"
EOF

    log_success "Starship configuration created successfully"
}

# Complete Installation
complete_installation() {
    log_info "Completing installation..."
    
    # Replace original bashrc
    if [ -f ~/.bashrc.enhanced ]; then
        mv ~/.bashrc.enhanced ~/.bashrc
        log_success "Updated .bashrc"
    fi
    
    # Create local aliases file
    if [ ! -f ~/.bash_aliases.local ]; then
        touch ~/.bash_aliases.local
        chmod 600 ~/.bash_aliases.local
        log_success "Created local aliases file: ~/.bash_aliases.local"
    fi
}

# Verify Installation
verify_installation() {
    log_info "Verifying installation results..."
    
    echo
    echo "🔧 Installation Verification:"
    echo "✅ System Type: $OS_TYPE"
    command_exists starship && echo "✅ Starship: Installed" || echo "⚠️  Starship: Not installed"
    command_exists fzf && echo "✅ fzf: Installed" || echo "⚠️  fzf: Not installed"
    command_exists bat && echo "✅ bat: Installed" || echo "⚠️  bat: Not installed"
    command_exists rg && echo "✅ ripgrep: Installed" || echo "⚠️  ripgrep: Not installed"
    (command_exists fd || command_exists fdfind) && echo "✅ fd: Installed" || echo "⚠️  fd: Not installed"
    [ -f ~/.bashrc ] && echo "✅ Bash Config: Updated" || echo "❌ Bash Config: Failed"
    [ -f ~/.config/starship.toml ] && echo "✅ Starship Config: Created" || echo "⚠️  Starship Config: Not created"
    
    echo
    log_success "🎉 Deployment Completed!"
    echo
    echo "📖 Usage Instructions:"
    echo "   Run: source ~/.bashrc"
    echo "   Or restart your terminal"
    echo
    echo "🎯 Test Commands:"
    echo "   gst    # Git status"
    echo "   fh     # History search (requires fzf)"
    echo "   fcd    # Directory navigation (requires fzf + fd)"
    echo "   fe     # File editing (requires fzf)"
    echo
    echo "🔧 Customization:"
    echo "   Edit ~/.bash_aliases.local to add personal aliases"
    echo "   Edit ~/.config/starship.toml to customize prompt"
}

# Main Execution Flow
main() {
    log_info "Starting enhanced Bash environment deployment..."
    log_info "Detected system type: $OS_TYPE"
    
    if [ "$OS_TYPE" = "unknown" ]; then
        log_error "Unrecognized operating system type, exiting"
        exit 1
    fi
    
    # Install all dependencies first
    if ! install_dependencies; then
        log_error "Dependency installation failed, exiting deployment"
        exit 1
    fi
    
    # Continue with other installation steps (allow partial failures)
    backup_config
    install_starship || log_warning "Starship installation failed, will use basic prompt"
    install_fzf || log_warning "fzf installation failed, some features unavailable"
    create_enhanced_bashrc || { log_error "Configuration file creation failed"; exit 1; }
    
    if command_exists starship; then
        create_starship_config
    fi
    
    complete_installation
    verify_installation
    
    log_success "🎊 All components installed successfully!"
}

# Execute main function
main "$@"

