#!/bin/bash

# install_bash_power_universal.sh (Enhanced Version)
# Advanced Bash Environment Installation Script (RHEL/Ubuntu/Debian Compatible)
# Features: Starship, fzf, ble.sh, bash-completion, modern CLI tools

set -e

echo "🚀 Starting Advanced Bash Environment Deployment..."

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Get Bash Version
get_bash_version() {
    bash --version | head -n1 | grep -oP '\d+\.\d+' | head -n1
}

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
                build-essential \
                gawk
            
            # Try to install bash-completion extras
            sudo apt-get install -y bash-completion-extras 2>/dev/null || log_info "bash-completion-extras not available, skipping"
            
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
                    util-linux-user \
                    gawk
                
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
                    util-linux-user \
                    gawk
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
    log_info "Installing Starship prompt..."
    
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
    log_info "Installing fzf (fuzzy finder)..."
    
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

# Install ble.sh (Bash Line Editor)
install_blesh() {
    log_info "Installing ble.sh (Bash Line Editor)..."
    
    local blesh_dir="$HOME/.local/share/blesh"
    
    if [ -f "$blesh_dir/ble.sh" ]; then
        log_success "ble.sh already installed"
        return 0
    fi
    
    # Check Bash version
    local bash_version=$(get_bash_version)
    local bash_major=$(echo "$bash_version" | cut -d. -f1)
    
    if [ "$bash_major" -lt 4 ]; then
        log_warning "ble.sh requires Bash 4.0+, current: $bash_version, skipping installation"
        return 1
    fi
    
    log_info "Bash version $bash_version detected, proceeding with ble.sh installation..."
    
    # Ensure required dependencies are available
    if ! command_exists git; then
        log_error "Git not available, cannot install ble.sh"
        return 1
    fi
    
    if ! command_exists make; then
        log_error "Make not available, cannot install ble.sh"
        return 1
    fi
    
    # Create directory
    mkdir -p "$HOME/.local/share"
    
    log_info "Cloning ble.sh repository (this may take a moment)..."
    if git clone --recursive --depth 1 --shallow-submodules \
        https://github.com/akinomyoga/ble.sh.git "$blesh_dir" 2>/dev/null; then
        
        log_info "Building ble.sh..."
        if make -C "$blesh_dir" install PREFIX="$HOME/.local" 2>/dev/null; then
            log_success "ble.sh installed successfully"
            return 0
        else
            log_warning "ble.sh build failed, but files are available"
            return 0
        fi
    else
        log_error "ble.sh clone failed"
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
    local has_blesh=$([ -f "$HOME/.local/share/blesh/ble.sh" ] && echo "true" || echo "false")
    
    # Handle Ubuntu's fd command name difference
    local fd_cmd="fd"
    if command_exists fdfind && ! command_exists fd; then
        fd_cmd="fdfind"
    fi
    
    # Start creating the bashrc file
    cat > ~/.bashrc.enhanced << 'BASHRC_HEADER'
#!/bin/bash
# =============================================
# Advanced Bash Configuration (Universal)
# Auto-generated - Do not edit this header
# =============================================

# === ble.sh Early Loading (Phase 1) ===
# ble.sh must be loaded early with --noattach, then attached at the end
if [[ $- == *i* ]] && [ -f ~/.local/share/blesh/ble.sh ]; then
    source ~/.local/share/blesh/ble.sh --noattach
fi

BASHRC_HEADER

    # Add metadata with variable expansion
    cat >> ~/.bashrc.enhanced << EOF
# Generated on: $(date)
# OS Type: $OS_TYPE
# Bash Version: $(get_bash_version)
# 
# Tools Installed:
#   - fzf: $has_fzf
#   - bat: $has_bat
#   - starship: $has_starship
#   - ble.sh: $has_blesh
# =============================================

EOF

    # Add main configuration
    cat >> ~/.bashrc.enhanced << 'EOF'
# === Basic Configuration ===
export EDITOR='vim'
export VISUAL='vim'
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%F %T "

# Bash shell options
shopt -s histappend      # Append to history file
shopt -s checkwinsize    # Update LINES and COLUMNS after each command
shopt -s globstar 2>/dev/null  # Enable ** recursive globbing (Bash 4+)
shopt -s cdspell 2>/dev/null   # Auto-correct cd typos
shopt -s dirspell 2>/dev/null  # Auto-correct directory spelling

# === Color Support ===
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Enable color support for ls and grep (preserve original commands)
if ls --color=auto &>/dev/null; then
    alias ls='ls --color=auto'
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# === Core Aliases (Enhanced, Non-Destructive) ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -laht'        # Sort by time, newest first
alias ltr='ls -lahtr'      # Sort by time, oldest first
alias lss='ls -lhSr'       # Sort by size

EOF

    # Conditionally add bat aliases (NON-DESTRUCTIVE)
    if [ "$has_bat" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === bat Integration (Non-Destructive) ===
if command -v bat >/dev/null 2>&1; then
    alias ccat='bat --paging=never'           # Colorful cat
    alias bless='bat --paging=always'         # Colorful less
    alias bathelp='bat --plain --language=help'
    
    # Helper function for man pages with bat
    if command -v batcat >/dev/null 2>&1; then
        export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
    else
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    fi
fi

EOF
    fi

    # Add Git aliases (non-destructive)
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
alias gap='git add -p'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gll='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gps='git push'
alias gpl='git pull'
alias gf='git fetch'
alias gfp='git fetch --prune'
alias gcl='git clone'
alias gsw='git switch'
alias gswc='git switch -c'
alias grh='git reset --hard'
alias grs='git reset --soft'
alias grb='git rebase'
alias grbi='git rebase -i'
alias gm='git merge'
alias gsh='git stash'
alias gshp='git stash pop'
alias gshl='git stash list'

# === Directory Navigation ===
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# Quick directory bookmarks
alias cdl='cd ~/.local'
alias cdc='cd ~/.config'
alias cdd='cd ~/Downloads'
alias cdh='cd ~'

# === Development Tool Aliases ===
# Docker
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs -f'

# NPM/Yarn
alias nr='npm run'
alias ni='npm install'
alias nid='npm install --save-dev'
alias ns='npm start'
alias nt='npm test'
alias nci='npm ci'
alias y='yarn'
alias yr='yarn run'
alias ys='yarn start'
alias yi='yarn install'

# Python
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate || source .venv/bin/activate'

# === System Monitoring Aliases ===
alias cpucore='grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown"'
alias meminfo='free -h 2>/dev/null || top -l 1 | grep PhysMem'
alias diskusage='df -h'
alias folderusage='du -sh ./* 2>/dev/null | sort -hr'
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'
alias myip='curl -s https://ifconfig.me'
alias localip='hostname -I 2>/dev/null || ipconfig getifaddr en0'

# === Utility Functions ===
# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick find
qfind() {
    find . -iname "*$1*"
}

# Process grep
psgrep() {
    ps aux | grep -v grep | grep -i -e VSZ -e "$1"
}

EOF

    # Add fzf configuration (if available)
    if [ "$has_fzf" = "true" ]; then
        # This part needs double quotes to expand fd_cmd
        cat >> ~/.bashrc.enhanced << EOF
# === fzf Configuration ===
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --inline-info'
export FZF_DEFAULT_COMMAND='$fd_cmd --type f --hidden --follow --exclude .git 2>/dev/null || find . -type f'
export FZF_CTRL_T_COMMAND="\$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='$fd_cmd --type d --hidden --follow --exclude .git 2>/dev/null || find . -type d'

# fzf: History search
fh() {
  local selected_command
  selected_command=\$(history | fzf +s --tac --tiebreak=index | sed 's/ *[0-9]* *//')
  if [ -n "\$selected_command" ]; then
    eval "\$selected_command"
  fi
}

# fzf: Directory navigation
fcd() {
  local dir
  dir=\$($fd_cmd --type d --hidden --follow --exclude .git 2>/dev/null | fzf --preview 'tree -C {} | head -50')
  [ -n "\$dir" ] && cd "\$dir"
}

# fzf: File search and edit
fe() {
  local file
  file=\$(fzf --preview 'bat --color=always --line-range :500 {} 2>/dev/null || cat {}')
  [ -n "\$file" ] && \${EDITOR:-vim} "\$file"
}

# fzf: Process kill
fkill() {
  local pid
  pid=\$(ps aux | sed 1d | fzf -m | awk '{print \$2}')
  if [ -n "\$pid" ]; then
    echo "\$pid" | xargs kill -\${1:-9}
  fi
}

# fzf: Git branch checkout
fgb() {
  local branch
  branch=\$(git branch --all | grep -v HEAD | sed 's/^..//' | sed 's#remotes/origin/##' | sort -u | fzf)
  [ -n "\$branch" ] && git checkout "\$branch"
}

# fzf: Git log browser
fgl() {
  git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "\$@" | \
  fzf --ansi --no-sort --reverse --tiebreak=index --preview \
  'echo {} | grep -o "[a-f0-9]\{7\}" | head -1 | xargs -I % git show --color=always %' \
  --bind "enter:execute:echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % git show --color=always % | less -R"
}

EOF
    fi

    # Add bash-completion configuration
    cat >> ~/.bashrc.enhanced << 'EOF'
# === Auto-completion (bash-completion) ===
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  elif [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
  fi
fi

# Load additional completions
if [ -d /usr/share/bash-completion/completions ]; then
    for completion in /usr/share/bash-completion/completions/*; do
        [ -f "$completion" ] && . "$completion" 2>/dev/null
    done
fi

# Git auto-completion
if [ -f /usr/share/bash-completion/completions/git ]; then
    . /usr/share/bash-completion/completions/git
elif [ -f /etc/bash_completion.d/git ]; then
    . /etc/bash_completion.d/git
fi

# Docker completion
if command -v docker >/dev/null 2>&1; then
    if [ -f /usr/share/bash-completion/completions/docker ]; then
        . /usr/share/bash-completion/completions/docker
    fi
fi

EOF

    # Add Starship or fallback prompt
    if [ "$has_starship" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === Starship Prompt ===
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

EOF
    else
        cat >> ~/.bashrc.enhanced << 'EOF'
# === Fallback Prompt (Enhanced) ===
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Color codes
PS1_USER_COLOR='\[\033[01;32m\]'
PS1_HOST_COLOR='\[\033[01;32m\]'
PS1_PATH_COLOR='\[\033[01;34m\]'
PS1_GIT_COLOR='\[\033[01;31m\]'
PS1_RESET='\[\033[00m\]'

PS1="${PS1_USER_COLOR}\u${PS1_RESET}@${PS1_HOST_COLOR}\h${PS1_RESET}:${PS1_PATH_COLOR}\w${PS1_GIT_COLOR}\$(parse_git_branch)${PS1_RESET}\$ "

EOF
    fi

    # Add ble.sh attachment at the very end
    if [ "$has_blesh" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === ble.sh Attachment (Phase 2 - Must be at the end) ===
# Attach ble.sh if it was loaded earlier
[[ ${BLE_VERSION-} ]] && ble-attach

EOF
    fi

    # Add local configuration and welcome message
    cat >> ~/.bashrc.enhanced << EOF
# === Local Configuration Override ===
# Add your custom aliases and functions here
[ -f ~/.bash_aliases.local ] && source ~/.bash_aliases.local

# === Welcome Message ===
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;32m🚀 Advanced Bash Environment Loaded!\033[0m"
echo -e "\033[0;36m   OS: $OS_TYPE | Bash: \$(get_bash_version 2>/dev/null || echo \$BASH_VERSION)\033[0m"
echo -e "\033[1;33m   Features:\033[0m"
[ "$has_starship" = "true" ] && echo -e "\033[0;32m   ✓ Starship Prompt\033[0m"
[ "$has_fzf" = "true" ] && echo -e "\033[0;32m   ✓ fzf Fuzzy Finder\033[0m"
[ "$has_bat" = "true" ] && echo -e "\033[0;32m   ✓ bat Syntax Highlighter\033[0m"
[ "$has_blesh" = "true" ] && echo -e "\033[0;32m   ✓ ble.sh Line Editor\033[0m"
echo -e "\033[1;33m   Quick Commands:\033[0m gst | fh | fcd | fe | ccat"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
EOF

    log_success "Enhanced .bashrc created successfully"
}

# Create Starship Configuration
create_starship_config() {
    log_info "Creating Starship configuration..."
    
    mkdir -p ~/.config
    
    cat > ~/.config/starship.toml << 'EOF'
# =============================================
# Starship Configuration (Optimized)
# =============================================

# Overall format
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$git_state\
$python\
$nodejs\
$rust\
$golang\
$docker_context\
$cmd_duration\
$line_break\
$jobs\
$battery\
$character"""

# Prompt character
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
vicmd_symbol = "[←](bold green)"

# Directory
[directory]
truncation_length = 3
truncate_to_repo = true
style = "bold cyan"
read_only = " 🔒"
read_only_style = "red"

# Git branch
[git_branch]
format = "[$symbol$branch]($style) "
symbol = " "
style = "bold purple"

# Git status
[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'
conflicted = "="
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
untracked = "?${count}"
stashed = "$${count}"
modified = "!${count}"
staged = "+${count}"
renamed = "»${count}"
deleted = "✘${count}"
style = "bold yellow"

# Git state (rebase, merge, etc.)
[git_state]
format = '[\($state( $progress_current of $progress_total)\)]($style) '
style = "bright-black"

# Command duration
[cmd_duration]
min_time = 2000
format = "took [$duration]($style) "
style = "bold yellow"

# Programming Languages
[python]
format = '[${symbol}${pyenv_prefix}(${version} )(\($virtualenv\) )]($style)'
symbol = " "
style = "yellow"

[nodejs]
format = "[$symbol($version )]($style)"
symbol = " "
style = "green"

[rust]
format = "[$symbol($version )]($style)"
symbol = " "
style = "red"

[golang]
format = "[$symbol($version )]($style)"
symbol = " "
style = "cyan"

# Docker
[docker_context]
format = "[$symbol$context]($style) "
symbol = " "
style = "blue"

# Battery
[battery]
full_symbol = "🔋"
charging_symbol = "⚡"
discharging_symbol = "💀"
display = [
    { threshold = 10, style = "bold red" },
    { threshold = 30, style = "bold yellow" },
]

# Jobs
[jobs]
symbol = "✦"
style = "bold blue"
number_threshold = 1

# Memory usage
[memory_usage]
disabled = false
threshold = 75
format = "mem: $ram( | swap: $swap) "
style = "white dimmed"

# Time
[time]
disabled = false
format = "[$time]($style) "
style = "bright-black"
time_format = "%T"

# Username
[username]
style_user = "bold green"
style_root = "bold red"
format = "[$user]($style)"
disabled = false
show_always = false

# Hostname
[hostname]
ssh_only = true
format = "@[$hostname]($style) "
style = "bold green"
disabled = false
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
    
    # Create local aliases file if it doesn't exist
    if [ ! -f ~/.bash_aliases.local ]; then
        cat > ~/.bash_aliases.local << 'EOF'
#!/bin/bash
# =============================================
# Local Bash Aliases and Functions
# Add your custom configurations here
# =============================================

# Example custom aliases:
# alias myserver='ssh user@server.com'
# alias myproject='cd ~/projects/myproject'

# Example custom functions:
# hello() {
#     echo "Hello, $1!"
# }

EOF
        chmod 600 ~/.bash_aliases.local
        log_success "Created local aliases file: ~/.bash_aliases.local"
    fi
}

# Verify Installation
verify_installation() {
    log_info "Verifying installation results..."
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🔧 Installation Verification Report${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${BLUE}System Information:${NC}"
    echo "  • OS Type: $OS_TYPE"
    echo "  • Bash Version: $(get_bash_version)"
    echo
    echo -e "${BLUE}Core Tools:${NC}"
    command_exists starship && echo -e "  ${GREEN}✓${NC} Starship: $(starship --version | head -n1)" || echo -e "  ${YELLOW}⚠${NC}  Starship: Not installed"
    command_exists fzf && echo -e "  ${GREEN}✓${NC} fzf: $(fzf --version)" || echo -e "  ${YELLOW}⚠${NC}  fzf: Not installed"
    [ -f "$HOME/.local/share/blesh/ble.sh" ] && echo -e "  ${GREEN}✓${NC} ble.sh: Installed" || echo -e "  ${YELLOW}⚠${NC}  ble.sh: Not installed"
    echo
    echo -e "${BLUE}Additional Tools:${NC}"
    command_exists bat && echo -e "  ${GREEN}✓${NC} bat: $(bat --version | head -n1)" || echo -e "  ${YELLOW}⚠${NC}  bat: Not installed"
    command_exists rg && echo -e "  ${GREEN}✓${NC} ripgrep: $(rg --version | head -n1)" || echo -e "  ${YELLOW}⚠${NC}  ripgrep: Not installed"
    (command_exists fd || command_exists fdfind) && echo -e "  ${GREEN}✓${NC} fd: Installed" || echo -e "  ${YELLOW}⚠${NC}  fd: Not installed"
    echo
    echo -e "${BLUE}Configuration Files:${NC}"
    [ -f ~/.bashrc ] && echo -e "  ${GREEN}✓${NC} .bashrc: Updated" || echo -e "  ${RED}✗${NC} .bashrc: Failed"
    [ -f ~/.config/starship.toml ] && echo -e "  ${GREEN}✓${NC} starship.toml: Created" || echo -e "  ${YELLOW}⚠${NC}  starship.toml: Not created"
    [ -f ~/.bash_aliases.local ] && echo -e "  ${GREEN}✓${NC} .bash_aliases.local: Ready" || echo -e "  ${YELLOW}⚠${NC}  .bash_aliases.local: Missing"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 Deployment Completed Successfully!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}📖 Next Steps:${NC}"
    echo "   1. Run: ${CYAN}source ~/.bashrc${NC}"
    echo "   2. Or restart your terminal"
    echo
    echo -e "${YELLOW}🎯 Test Commands:${NC}"
    echo "   • ${CYAN}gst${NC}      Git status"
    echo "   • ${CYAN}fh${NC}       Fuzzy history search"
    echo "   • ${CYAN}fcd${NC}      Fuzzy directory navigation"
    echo "   • ${CYAN}fe${NC}       Fuzzy file edit"
    echo "   • ${CYAN}ccat${NC}     Colorful cat (bat)"
    echo "   • ${CYAN}fgl${NC}      Fuzzy git log browser"
    echo
    echo -e "${YELLOW}🔧 Customization:${NC}"
    echo "   • Edit ${CYAN}~/.bash_aliases.local${NC} for personal aliases"
    echo "   • Edit ${CYAN}~/.config/starship.toml${NC} for prompt customization"
    echo
    echo -e "${YELLOW}📚 Key Features:${NC}"
    echo "   • Syntax highlighting and auto-suggestions (ble.sh)"
    echo "   • Fuzzy finding for files, directories, history (fzf)"
    echo "   • Beautiful prompt with git integration (starship)"
    echo "   • Extensive aliases and functions"
    echo "   • Smart completion (bash-completion)"
    echo
}

# Main Execution Flow
main() {
    log_info "Starting advanced Bash environment deployment..."
    log_info "Detected system type: $OS_TYPE"
    
    if [ "$OS_TYPE" = "unknown" ]; then
        log_error "Unrecognized operating system type, exiting"
        exit 1
    fi
    
    # Check Bash version
    local bash_version=$(get_bash_version)
    log_info "Bash version: $bash_version"
    
    # Install all dependencies first
    if ! install_dependencies; then
        log_error "Dependency installation failed, exiting deployment"
        exit 1
    fi
    
    # Backup existing configuration
    backup_config
    
    # Continue with other installation steps (allow partial failures)
    install_starship || log_warning "Starship installation failed, will use basic prompt"
    install_fzf || log_warning "fzf installation failed, some features unavailable"
    install_blesh || log_warning "ble.sh installation failed, no line editing enhancements"
    
    # Create configuration files
    create_enhanced_bashrc || { log_error "Configuration file creation failed"; exit 1; }
    
    if command_exists starship; then
        create_starship_config
    fi
    
    # Complete installation
    complete_installation
    
    # Verify and display results
    verify_installation
    
    log_success "🎊 All components installed successfully!"
}

# Execute main function
main "$@"
