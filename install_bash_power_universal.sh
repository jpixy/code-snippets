#!/bin/bash
# install_bash_power_universal.sh

set -e

echo "🚀 开始部署增强版 Bash 环境 (RHEL/Ubuntu 兼容版)..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检测系统类型
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

# 检查命令是否存在
command_exists() { command -v "$1" >/dev/null 2>&1; }

# 提前安装所有依赖
install_dependencies() {
    log_info "安装系统依赖 (OS: $OS_TYPE)..."
    
    case $OS_TYPE in
        "ubuntu"|"debian")
            log_info "更新 apt 包列表..."
            sudo apt-get update || true
            
            log_info "安装核心依赖..."
            sudo apt-get install -y \
                curl \
                git \
                bat \
                ripgrep \
                fd-find \
                bash-completion \
                tree \
                htop \
                ncdu \
                wget \
                unzip \
                zip \
                make \
                build-essential
            
            # 创建 fd 的符号链接（Ubuntu 中叫 fdfind）
            if command_exists fdfind && ! command_exists fd; then
                sudo ln -sf $(which fdfind) /usr/local/bin/fd
                log_success "创建 fd 符号链接"
            fi
            ;;
            
        "rhel"|"centos"|"fedora")
            # 安装 EPEL 仓库（RHEL/CentOS 需要）
            if [ -f /etc/redhat-release ] && grep -q "release 7" /etc/redhat-release; then
                log_info "RHEL/CentOS 7 检测到，安装 EPEL 仓库..."
                sudo yum install -y epel-release || true
            elif command_exists dnf && [ -f /etc/redhat-release ]; then
                log_info "安装 EPEL 仓库..."
                sudo dnf install -y epel-release || true
            fi
            
            if command_exists dnf; then
                log_info "使用 dnf 安装依赖..."
                sudo dnf install -y \
                    curl \
                    git \
                    bat \
                    ripgrep \
                    fd-find \
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
            elif command_exists yum; then
                log_info "使用 yum 安装依赖..."
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
                
                # RHEL7/CentOS7 的额外处理
                if grep -q "release 7" /etc/redhat-release 2>/dev/null; then
                    log_info "安装 RHEL7/CentOS7 的额外工具..."
                    sudo yum install -y https://github.com/sharkdp/bat/releases/download/v0.18.0/bat-v0.18.0-x86_64-unknown-linux-gnu.tar.gz || true
                    sudo yum install -y https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep-13.0.0-x86_64-unknown-linux-musl.tar.gz || true
                fi
            fi
            ;;
        *)
            log_warning "未知系统类型，跳过依赖安装"
            return 1
            ;;
    esac
    
    # 验证核心依赖
    log_info "验证核心依赖安装..."
    local missing_deps=()
    
    for dep in curl git; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "以下核心依赖安装失败: ${missing_deps[*]}"
        return 1
    fi
    
    log_success "所有依赖安装完成"
    return 0
}

# 备份原有配置
backup_config() {
    log_info "备份原有配置..."
    
    # 创建备份目录
    local backup_dir="$HOME/.bash_config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份 .bashrc
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc "$backup_dir/bashrc"
        log_success "已备份 .bashrc"
    fi
    
    # 备份 .bash_profile
    if [ -f ~/.bash_profile ]; then
        cp ~/.bash_profile "$backup_dir/bash_profile"
        log_success "已备份 .bash_profile"
    fi
    
    # 备份 Starship 配置
    if [ -f ~/.config/starship.toml ]; then
        mkdir -p "$backup_dir/.config"
        cp ~/.config/starship.toml "$backup_dir/.config/"
        log_success "已备份 Starship 配置"
    fi
    
    echo "所有备份文件保存在: $backup_dir"
}

# 安装 Starship
install_starship() {
    log_info "安装 Starship..."
    
    if command_exists starship; then
        log_success "Starship 已安装"
        return 0
    fi
    
    # 方法1: 使用官方安装脚本（首选）
    log_info "使用官方脚本安装 Starship..."
    if curl -fsSL https://starship.rs/install.sh | sh -s -- -y; then
        log_success "Starship 安装完成"
        return 0
    fi
    
    # 方法2: 使用包管理器
    log_info "尝试使用包管理器安装..."
    case $OS_TYPE in
        "ubuntu"|"debian")
            if command_exists apt && sudo apt install -y starship 2>/dev/null; then
                log_success "通过 apt 安装 Starship 完成"
                return 0
            fi
            ;;
        "rhel"|"centos"|"fedora")
            if command_exists dnf && sudo dnf install -y starship 2>/dev/null; then
                log_success "通过 dnf 安装 Starship 完成"
                return 0
            elif command_exists yum && sudo yum install -y starship 2>/dev/null; then
                log_success "通过 yum 安装 Starship 完成"
                return 0
            fi
            ;;
    esac
    
    # 方法3: 手动下载二进制文件
    log_info "尝试手动安装 Starship..."
    local starship_binary="/usr/local/bin/starship"
    if sudo curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz | \
       sudo tar -xzf - -C /usr/local/bin; then
        sudo chmod +x "$starship_binary"
        log_success "手动安装 Starship 完成"
        return 0
    fi
    
    log_error "Starship 安装失败"
    return 1
}

# 安装 fzf
install_fzf() {
    log_info "安装 fzf..."
    
    if command_exists fzf; then
        log_success "fzf 已安装"
        return 0
    fi
    
    # 方法1: 使用包管理器
    case $OS_TYPE in
        "ubuntu"|"debian")
            if sudo apt-get install -y fzf; then
                log_success "通过 apt 安装 fzf 完成"
                return 0
            fi
            ;;
        "rhel"|"centos"|"fedora")
            if command_exists dnf && sudo dnf install -y fzf; then
                log_success "通过 dnf 安装 fzf 完成"
                return 0
            elif command_exists yum && sudo yum install -y fzf; then
                log_success "通过 yum 安装 fzf 完成"
                return 0
            fi
            ;;
    esac
    
    # 方法2: 使用 Git 安装
    log_info "使用 Git 安装 fzf..."
    if ! command_exists git; then
        log_error "Git 不可用，无法安装 fzf"
        return 1
    fi
    
    local fzf_dir="$HOME/.fzf"
    if [ -d "$fzf_dir" ]; then
        log_info "更新现有 fzf 安装..."
        cd "$fzf_dir" && git pull && ./install --all --no-update-rc
    else
        log_info "克隆 fzf 仓库..."
        if git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"; then
            "$fzf_dir/install" --all --no-update-rc
        else
            log_error "fzf 克隆失败"
            return 1
        fi
    fi
    
    if command_exists fzf; then
        log_success "fzf 安装完成"
        return 0
    else
        log_error "fzf 安装失败"
        return 1
    fi
}

# 创建增强的 bashrc 配置
create_enhanced_bashrc() {
    log_info "创建增强版 Bash 配置..."
    
    # 检测工具可用性
    local has_fzf=$(command_exists fzf && echo "true" || echo "false")
    local has_bat=$(command_exists bat && echo "true" || echo "false")
    local has_starship=$(command_exists starship && echo "true" || echo "false")
    
    # 处理 Ubuntu 的 fd 命令名差异
    local fd_cmd="fd"
    if command_exists fdfind && ! command_exists fd; then
        fd_cmd="fdfind"
    fi
    
    cat > ~/.bashrc.enhanced << EOF
#!/bin/bash
# =============================================
# 增强版 Bash 配置 (兼容 RHEL/Ubuntu)
# 自动生成于 $(date)
# OS: $OS_TYPE
# =============================================

# === 基础配置 ===
export EDITOR='vim'
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar

# === 颜色支持 ===
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# === 核心别名 ===
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -laht'
alias ltr='ls -lahtr'

# === 增强工具别名 ===
EOF

    # 条件性添加 bat 别名
    if [ "$has_bat" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# bat 替代 cat（如果可用）
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat --paging=always'
fi
EOF
    fi

    # 添加 Git 别名
    cat >> ~/.bashrc.enhanced << 'EOF'

# === Git 别名 ===
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

# === 目录导航 ===
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# === 开发工具别名 ===
alias nr='npm run'
alias ni='npm install'
alias nid='npm install --save-dev'
alias ns='npm start'
alias nt='npm test'
alias y='yarn'
alias yr='yarn run'
alias ys='yarn start'

# === 系统监控 ===
alias cpucore='grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown"'
alias meminfo='free -h || echo "free command not available"'
alias diskusage='df -h'
alias folderusage='du -sh ./* 2>/dev/null || du -sh * 2>/dev/null'

EOF

    # 添加 fzf 配置（如果可用）
    if [ "$has_fzf" = "true" ]; then
        cat >> ~/.bashrc.enhanced << EOF

# === fzf 配置 ===
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# fzf 历史命令搜索
fh() {
  local selected_command
  selected_command=\$(history | fzf +s --tac | sed 's/ *[0-9]* *//')
  [ -n "\$selected_command" ] && eval "\$selected_command"
}

# fzf 目录切换
fd() {
  local dir
  dir=\$($fd_cmd --type d 2>/dev/null | fzf)
  [ -n "\$dir" ] && cd "\$dir"
}

# fzf 文件编辑
fe() {
  local file
  file=\$(fzf --preview 'head -100 {}') && \${EDITOR:-vim} "\$file"
}
EOF
    fi

    # 添加自动补全
    cat >> ~/.bashrc.enhanced << 'EOF'

# === 自动补全 ===
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  elif [ -f /usr/local/etc/bash_completion ]; then
    . /usr/local/etc/bash_completion
  fi
fi

# Git 自动补全
if [ -f /usr/share/bash-completion/completions/git ]; then
    . /usr/share/bash-completion/completions/git
elif [ -f /etc/bash_completion.d/git ]; then
    . /etc/bash_completion.d/git
fi

EOF

    # 添加 Starship 或备用提示符
    if [ "$has_starship" = "true" ]; then
        cat >> ~/.bashrc.enhanced << 'EOF'
# === Starship 提示符 ===
eval "$(starship init bash)"
EOF
    else
        cat >> ~/.bashrc.enhanced << 'EOF'
# === 备用提示符 ===
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;31m\]$(parse_git_branch)\[\033[00m\]\$ '
EOF
    fi

    # 添加本地配置和欢迎信息
    cat >> ~/.bashrc.enhanced << 'EOF'

# === 本地配置 ===
[ -f ~/.bash_aliases.local ] && source ~/.bash_aliases.local

# === 欢迎信息 ===
echo -e "\033[1;32m🚀 增强版 Bash 环境已加载! ($OS_TYPE)\033[0m"
echo -e "可用命令: \033[1;33mgst, fh, fd, fe\033[0m"
EOF

    log_success "增强版 .bashrc 创建完成"
}

# 创建 Starship 配置
create_starship_config() {
    log_info "创建 Starship 配置..."
    
    mkdir -p ~/.config
    
    cat > ~/.config/starship.toml << 'EOF'
# Starship 配置 - 兼容 RHEL/Ubuntu

format = """
$username$hostname$directory$git_branch$git_status
$character"""

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = false
style = "bold blue"

[git_branch]
format = "[$branch]($style)"
style = "bold purple"

[git_status]
conflicted = "═"
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
untracked = "?"
modified = "!"
staged = "+"

[cmd_duration]
format = "[$duration]($style)" 
style = "yellow"

[memory_usage]
disabled = false
EOF

    log_success "Starship 配置创建完成"
}

# 完成安装
complete_installation() {
    log_info "完成安装..."
    
    # 替换原有 bashrc
    if [ -f ~/.bashrc.enhanced ]; then
        mv ~/.bashrc.enhanced ~/.bashrc
        log_success "已更新 .bashrc"
    fi
    
    # 创建本地别名文件
    touch ~/.bash_aliases.local
    chmod 600 ~/.bash_aliases.local
    
    log_success "创建本地别名文件: ~/.bash_aliases.local"
}

# 验证安装
verify_installation() {
    log_info "验证安装结果..."
    
    echo
    echo "🔧 安装验证:"
    echo "✅ 系统类型: $OS_TYPE"
    command_exists starship && echo "✅ Starship: 已安装" || echo "⚠️  Starship: 未安装"
    command_exists fzf && echo "✅ fzf: 已安装" || echo "⚠️  fzf: 未安装"
    command_exists bat && echo "✅ bat: 已安装" || echo "⚠️  bat: 未安装"
    command_exists rg && echo "✅ ripgrep: 已安装" || echo "⚠️  ripgrep: 未安装"
    [ -f ~/.bashrc ] && echo "✅ Bash 配置: 已更新" || echo "❌ Bash 配置: 失败"
    [ -f ~/.config/starship.toml ] && echo "✅ Starship 配置: 已创建" || echo "⚠️  Starship 配置: 未创建"
    
    echo
    log_success "🎉 部署完成！"
    echo
    echo "📖 使用说明:"
    echo "   运行: source ~/.bashrc"
    echo "   或重新打开终端"
    echo
    echo "🎯 测试命令:"
    echo "   gst    # Git 状态"
    echo "   fh     # 历史命令搜索"
    echo "   fd     # 目录切换"
    echo "   fe     # 文件编辑"
    echo
    echo "🔧 自定义配置:"
    echo "   编辑 ~/.bash_aliases.local 添加个人别名"
    echo "   编辑 ~/.config/starship.toml 调整提示符"
}

# 主执行流程
main() {
    log_info "开始部署增强版 Bash 环境..."
    log_info "检测到系统类型: $OS_TYPE"
    
    # 提前安装所有依赖
    if ! install_dependencies; then
        log_error "依赖安装失败，退出部署"
        exit 1
    fi
    
    # 继续其他安装步骤
    backup_config
    install_starship
    install_fzf
    create_enhanced_bashrc
    create_starship_config
    complete_installation
    verify_installation
    
    log_success "🎊 所有组件安装完成！"
}

# 执行主函数
main "$@"
