#!/bin/bash
# Skylark Screen Translator - Linux 通用启动器 (Lubuntu 24.04 优化版)
# 支持 Ubuntu/Debian/CentOS/Fedora/Arch Linux 等主流发行版
# 自动检测系统、安装依赖、创建虚拟环境并启动应用
# 针对 Lubuntu 24.04 进行了专门优化和启动速度提升

set -e

SCRIPT_NAME="skylark_screen_translator.py"
VENV_DIR="venv"
LOG_FILE="/tmp/skylark_install.log"
APP_NAME="Skylark Screen Translator"
DESKTOP_FILE="skylark-translator.desktop"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TMP_DIR="$SCRIPT_DIR/tmp"
FAST_LAUNCHER="$SCRIPT_DIR/skylark_fast.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 初始化变量
LUBUNTU=false
LUBUNTU_24_04=false

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${PURPLE}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# 创建本地临时目录
setup_local_tmp() {
    mkdir -p "$LOCAL_TMP_DIR"
    log "创建本地临时目录: $LOCAL_TMP_DIR"
    
    # 显示临时目录信息
    if [[ -d "$LOCAL_TMP_DIR" ]]; then
        local tmp_size=$(du -sh "$LOCAL_TMP_DIR" 2>/dev/null | cut -f1 || echo "0")
        info "本地临时目录当前大小: $tmp_size"
        info "此目录用于存储 argostranslate 下载文件，请勿手动删除"
    fi
}

# 检测Linux发行版
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi
    
    log "检测到系统: $DISTRO ${VERSION:-unknown}"
}

# 检测 Lubuntu
detect_lubuntu() {
    if [[ "$DISTRO" == "ubuntu" && "$VERSION" == "24.04" ]]; then
        if grep -q "Lubuntu" /etc/os-release 2>/dev/null || 
           [[ "$XDG_CURRENT_DESKTOP" == *"LXQt"* ]] || 
           [[ "$DESKTOP_SESSION" == *"lubuntu"* ]]; then
            LUBUNTU=true
            LUBUNTU_24_04=true
            log "检测到 Lubuntu 24.04，启用特殊配置和优化"
        fi
    fi
}

# 检查包管理器和安装命令
setup_package_manager() {
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            PKG_MANAGER="apt"
            PKG_UPDATE="sudo apt update"
            PKG_INSTALL="sudo apt install -y"
            PKG_SEARCH="apt-cache show"
            PYTHON_PKG="python3"
            ;;
        fedora|centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_UPDATE="sudo dnf check-update || true"
                PKG_INSTALL="sudo dnf install -y"
                PKG_SEARCH="dnf info"
            else
                PKG_MANAGER="yum"
                PKG_UPDATE="sudo yum check-update || true"
                PKG_INSTALL="sudo yum install -y"
                PKG_SEARCH="yum info"
            fi
            PYTHON_PKG="python3"
            ;;
        arch|manjaro|endeavouros)
            PKG_MANAGER="pacman"
            PKG_UPDATE="sudo pacman -Sy"
            PKG_INSTALL="sudo pacman -S --noconfirm"
            PKG_SEARCH="pacman -Si"
            PYTHON_PKG="python"
            ;;
        opensuse*|suse)
            PKG_MANAGER="zypper"
            PKG_UPDATE="sudo zypper refresh"
            PKG_INSTALL="sudo zypper install -y"
            PKG_SEARCH="zypper info"
            PYTHON_PKG="python3"
            ;;
        *)
            error "不支持的发行版: $DISTRO"
            error "请手动安装依赖或联系开发者添加支持"
            exit 1
            ;;
    esac
    
    log "包管理器: $PKG_MANAGER"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "请不要使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检查脚本文件是否存在
check_script() {
    if [[ ! -f "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        error "找不到脚本文件: $SCRIPT_DIR/$SCRIPT_NAME"
        error "请确保 $SCRIPT_NAME 与此启动脚本在同一目录下"
        exit 1
    fi
    log "脚本文件检查通过: $SCRIPT_DIR/$SCRIPT_NAME"
}

# 检查系统包是否安装
check_system_package() {
    local package=$1
    case $PKG_MANAGER in
        apt)
            dpkg -l | grep -q "^ii.*$package " 2>/dev/null
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        zypper)
            zypper search -i "$package" | grep -q "^i " 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查命令是否存在
check_command() {
    command -v "$1" &> /dev/null
}

# 检查 Python 模块是否可导入
check_python_module() {
    local module=$1
    local venv_python="$SCRIPT_DIR/$VENV_DIR/bin/python3"
    
    if [[ -f "$venv_python" ]]; then
        "$venv_python" -c "import $module" 2>/dev/null
    else
        python3 -c "import $module" 2>/dev/null
    fi
}

# 检查虚拟环境
check_virtual_env() {
    local venv_path="$SCRIPT_DIR/$VENV_DIR"
    if [[ -d "$venv_path" ]] && [[ -f "$venv_path/bin/python3" ]]; then
        log "虚拟环境已存在: $venv_path"
        return 0
    else
        warn "虚拟环境不存在或损坏"
        return 1
    fi
}

# 获取发行版特定的包名
get_system_packages() {
    local packages=()
    
    case $PKG_MANAGER in
        apt)
            packages=(
                "python3" "python3-pip" "python3-venv" "python3-dev" "python3-tk"
                "build-essential" "pkg-config" "cmake"
                "qtbase5-dev" "qt5-qmake" "python3-pyqt5"
                "libxcb-xinerama0" "libxcb-cursor0" "libxkbcommon-x11-0"
                "libx11-dev" "libxext-dev" "libxrandr-dev" "libxi-dev" "libxss-dev"
                "libjpeg-dev" "zlib1g-dev" "libtiff-dev" "libpng-dev"
                "tesseract-ocr" "tesseract-ocr-eng" "libtesseract-dev" "libleptonica-dev"
                "libssl-dev" "libffi-dev" "fonts-dejavu-core" "fonts-liberation"
            )
            
            # Lubuntu 24.04 可能需要额外包
            if [[ "$LUBUNTU_24_04" == "true" ]]; then
                packages+=(
                    "libxcb-util1" "libxcb-icccm4" "libxcb-keysyms1" "libxcb-render-util0"
                    "libxcb-xfixes0-dev" "libxcb-shape0-dev" "libxcb-randr0-dev"
                )
            fi
            ;;
        dnf|yum)
            packages=(
                "python3" "python3-pip" "python3-venv" "python3-devel" "python3-tkinter"
                "gcc" "gcc-c++" "make" "pkgconfig" "cmake"
                "qt5-qtbase-devel" "python3-qt5" "python3-qt5-devel"
                "libX11-devel" "libXext-devel" "libXrandr-devel" "libXi-devel" "libXss-devel"
                "libjpeg-turbo-devel" "zlib-devel" "libtiff-devel" "libpng-devel"
                "tesseract" "tesseract-devel" "leptonica-devel"
                "openssl-devel" "libffi-devel" "dejavu-fonts" "liberation-fonts"
            )
            ;;
        pacman)
            packages=(
                "python" "python-pip" "python-virtualenv" "python-tkinter"
                "base-devel" "pkgconf" "cmake"
                "qt5-base" "python-pyqt5" "python-pyqt5-sip"
                "libx11" "libxext" "libxrandr" "libxi" "libxss"
                "libjpeg-turbo" "zlib" "libtiff" "libpng"
                "tesseract" "tesseract-data-eng" "leptonica"
                "openssl" "libffi" "ttf-dejavu" "ttf-liberation"
            )
            ;;
        zypper)
            packages=(
                "python3" "python3-pip" "python3-virtualenv" "python3-devel" "python3-tk"
                "gcc" "gcc-c++" "make" "pkg-config" "cmake"
                "libqt5-qtbase-devel" "python3-qt5" "python3-qt5-devel"
                "libX11-devel" "libXext-devel" "libXrandr-devel" "libXi-devel" "libXss-devel"
                "libjpeg8-devel" "zlib-devel" "libtiff-devel" "libpng16-devel"
                "tesseract-ocr" "tesseract-ocr-devel" "leptonica-devel"
                "libopenssl-devel" "libffi-devel" "dejavu-fonts" "liberation-fonts"
            )
            ;;
    esac
    
    echo "${packages[@]}"
}

# 检查所有系统依赖
check_system_dependencies() {
    local missing_packages=()
    local available_packages
    
    info "获取系统特定的包列表..."
    read -ra available_packages <<< "$(get_system_packages)"
    
    info "检查系统依赖包..."
    for package in "${available_packages[@]}"; do
        if ! check_system_package "$package"; then
            # 验证包是否真的可用
            if $PKG_SEARCH "$package" &>/dev/null; then
                missing_packages+=("$package")
            else
                warn "包 $package 在当前源中不可用，跳过"
            fi
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        warn "缺少以下系统包: ${missing_packages[*]}"
        return 1
    else
        log "所有系统依赖包已安装"
        return 0
    fi
}

# 安装系统依赖
install_system_dependencies() {
    info "准备安装系统依赖..."
    
    # 更新包列表
    log "更新包列表..."
    eval "$PKG_UPDATE"
    
    # 获取可用的包列表
    local available_packages
    read -ra available_packages <<< "$(get_system_packages)"
    
    # 过滤出真正可用的包
    local installable_packages=()
    info "验证包的可用性..."
    
    for package in "${available_packages[@]}"; do
        if $PKG_SEARCH "$package" &>/dev/null; then
            installable_packages+=("$package")
        else
            warn "✗ $package 不可用，跳过"
        fi
    done
    
    if [[ ${#installable_packages[@]} -eq 0 ]]; then
        error "没有找到可安装的包"
        return 1
    fi
    
    # 安装系统包
    log "安装 ${#installable_packages[@]} 个系统依赖包..."
    
    if eval "$PKG_INSTALL ${installable_packages[*]}"; then
        success "系统依赖安装完成"
    else
        error "系统依赖安装失败"
        return 1
    fi
}

# 创建和配置虚拟环境
setup_virtual_env() {
    local venv_path="$SCRIPT_DIR/$VENV_DIR"
    
    if ! check_virtual_env; then
        log "创建 Python 虚拟环境: $venv_path"
        cd "$SCRIPT_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    
    # 激活虚拟环境并升级 pip
    source "$venv_path/bin/activate"
    log "升级 pip..."
    pip install --upgrade pip setuptools wheel
    
    success "虚拟环境设置完成"
}

# 检查 Python 依赖
check_python_dependencies() {
    local missing_modules=()
    local modules=(
        "PyQt5"
        "PIL"
        "numpy"
        "cv2"
        "pytesseract"
        "mss"
        "requests"
        "pynput"
        "screeninfo"
    )
    
    info "检查核心 Python 依赖模块..."
    for module in "${modules[@]}"; do
        if ! check_python_module "$module"; then
            missing_modules+=("$module")
        fi
    done
    
    # 检查可选模块
    local optional_modules=("argostranslate")
    local missing_optional=()
    
    info "检查可选 Python 依赖模块..."
    for module in "${optional_modules[@]}"; do
        if ! check_python_module "$module"; then
            missing_optional+=("$module")
        fi
    done
    
    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        warn "缺少以下核心 Python 模块: ${missing_modules[*]}"
        return 1
    elif [[ ${#missing_optional[@]} -gt 0 ]]; then
        warn "缺少以下可选 Python 模块: ${missing_optional[*]}"
        warn "应用可正常运行，翻译功能需在应用内配置"
        log "所有核心 Python 依赖模块已安装"
        return 0
    else
        log "所有 Python 依赖模块已安装"
        return 0
    fi
}

# 检查磁盘空间
check_disk_space() {
    local required_space_gb=3
    local available_space
    
    # 获取脚本目录的可用空间（GB）
    available_space=$(df "$SCRIPT_DIR" | awk 'NR==2 {print int($4/1024/1024)}')
    
    info "检查磁盘空间..."
    info "当前目录: $SCRIPT_DIR"
    info "可用空间: ${available_space}GB"
    info "argostranslate 需要约 ${required_space_gb}GB 空间"
    
    if [[ $available_space -lt $required_space_gb ]]; then
        warn "磁盘空间不足，建议清理空间后再安装 argostranslate"
        warn "或者选择跳过翻译功能"
        return 1
    else
        log "磁盘空间充足"
        return 0
    fi
}

# 安装 Python 依赖（优化版本）
install_python_dependencies() {
    log "安装 Python 依赖包..."
    
    # 激活虚拟环境
    source "$SCRIPT_DIR/$VENV_DIR/bin/activate"
    
    # 第一阶段：安装核心依赖包（必需）
    local core_packages=(
        "PyQt5"
        "pillow"
        "numpy"
        "opencv-python-headless"
        "pytesseract"
        "mss"
        "requests"
        "screeninfo"
        "pynput"
        "ttkthemes"
        "pyinstaller"
        "tk"
    )
    
    # 安装核心包
    local failed_packages=()
    
    log "第一阶段：安装核心依赖包..."
    for package in "${core_packages[@]}"; do
        log "安装 $package..."
        if pip install "$package"; then
            log "✓ $package 安装成功"
        else
            warn "✗ $package 安装失败"
            failed_packages+=("$package")
        fi
    done
    
    # 第一阶段清理缓存
    log "清理缓存以释放空间..."
    pip cache purge
    
    # 设置临时目录为本地目录
    setup_local_tmp
    export TMPDIR="$LOCAL_TMP_DIR"
    info "设置临时目录为: $LOCAL_TMP_DIR"
    
    # 第二阶段：安装翻译功能（根据磁盘空间自动决定）
    local install_translation=false
    
    if check_disk_space; then
        install_translation=true
        info "磁盘空间充足，将自动安装翻译功能"
    else
        warn "磁盘空间不足，跳过翻译功能安装"
        info "您可以稍后手动安装：pip install argostranslate"
    fi
    
    # 第二阶段：安装翻译功能（如果空间充足）
    if [[ "$install_translation" == "true" ]]; then
        log "第二阶段：安装翻译引擎..."
        log "正在安装 argostranslate（这可能需要几分钟）..."
        info "临时文件保存在: $LOCAL_TMP_DIR"
        
        if pip install argostranslate; then
            success "✓ argostranslate 安装成功"
            info "提示：使用 argospm install translate-en_zh 下载语言包"
        else
            warn "✗ argostranslate 安装失败"
            warn "您可以稍后手动安装：pip install argostranslate"
        fi
    else
        info "跳过翻译功能，仅安装 OCR 功能"
        info "稍后可手动安装：pip install argostranslate"
    fi
    
    # 处理失败的核心包
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        warn "重试安装失败的核心包: ${failed_packages[*]}"
        for package in "${failed_packages[@]}"; do
            log "重试安装 $package..."
            pip install "$package" --no-cache-dir --force-reinstall
        done
    fi
    
    # 最终清理
    pip cache purge
    
    success "Python 依赖安装完成"
}

# 验证安装
verify_installation() {
    info "验证安装..."
    
    local verification_failed=false
    
    # 测试关键模块
    source "$SCRIPT_DIR/$VENV_DIR/bin/activate"
    
    local test_modules=(
        "PyQt5:PyQt5 GUI框架"
        "cv2:OpenCV 图像处理"
        "pytesseract:OCR 文字识别"
        "PIL:Pillow 图像库"
        "pynput:输入监听"
        "numpy:数值计算"
        "mss:屏幕截图"
        "requests:网络请求"
    )
    
    # 核心模块测试
    for test in "${test_modules[@]}"; do
        module=${test%%:*}
        description=${test##*:}
        
        if python3 -c "import $module" 2>/dev/null; then
            log "✓ $description ($module)"
        else
            error "✗ $description ($module) - 导入失败"
            verification_failed=true
        fi
    done
    
    # 可选模块测试
    if python3 -c "import argostranslate" 2>/dev/null; then
        log "✓ 离线翻译引擎 (argostranslate)"
        info "  提示：使用 argospm install translate-en_zh 下载语言包"
    else
        warn "△ 离线翻译引擎未安装，仅可使用 OCR 功能"
        info "  可稍后安装：pip install argostranslate"
    fi
    
    # 测试 Tesseract
    if command -v tesseract &> /dev/null; then
        local tesseract_version=$(tesseract --version 2>&1 | head -n1)
        log "✓ Testeract OCR: $tesseract_version"
        
        # 显示 OCR 语言包安装提示
        info "  OCR 语言包可在应用内下载，或手动安装："
        case $PKG_MANAGER in
            apt)
                info "    sudo apt install tesseract-ocr-chi-sim  # 简体中文"
                ;;
            dnf|yum)
                info "    sudo $PKG_MANAGER install tesseract-langpack-chi_sim"
                ;;
            pacman)
                info "    sudo pacman -S tesseract-data-chi_sim"
                ;;
            zypper)
                info "    sudo zypper install tesseract-ocr-traineddata-chinese_simplified"
                ;;
        esac
    else
        error "✗ Tesseract OCR 引擎未找到"
        verification_failed=true
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        error "核心组件验证失败"
        return 1
    else
        success "环境验证通过"
        return 0
    fi
}

# 创建极速启动脚本
create_fast_launcher() {
    log "创建极速启动脚本..."
    
    cat > "$FAST_LAUNCHER" << EOF
#!/bin/bash
# Skylark Screen Translator - 极速启动脚本
# 跳过所有检查，直接启动应用

cd "$SCRIPT_DIR"

# 设置关键环境变量
export ARGOS_PACKAGES_DIR="\$(pwd)/argos_packages"
export TESSDATA_PREFIX="\$(pwd)/tessdata"
export QT_QPA_PLATFORM=xcb
export XDG_CACHE_HOME="\$(pwd)/.cache"
export XDG_DATA_HOME="\$(pwd)/.local_share"

# 创建必要目录（如果不存在）
mkdir -p "\$ARGOS_PACKAGES_DIR" "\$TESSDATA_PREFIX" "\$XDG_CACHE_HOME" "\$XDG_DATA_HOME"

# 直接使用虚拟环境的 Python 解释器
exec "\$(pwd)/$VENV_DIR/bin/python3" "$SCRIPT_NAME"
EOF

    chmod +x "$FAST_LAUNCHER"
    success "极速启动脚本创建完成: $FAST_LAUNCHER"
}

# 创建预加载脚本
create_preload_script() {
    log "创建预加载脚本..."
    
    cat > "$SCRIPT_DIR/preload_modules.py" << 'EOF'
#!/usr/bin/env python3
"""
预加载常用模块以减少启动时间
"""
import importlib
import threading
import time

def preload_modules():
    """在后台预加载模块"""
    modules_to_preload = [
        "PyQt5.QtCore", "PyQt5.QtGui", "PyQt5.QtWidgets",
        "PIL.Image", "numpy", "cv2", "pytesseract"
    ]
    
    for module in modules_to_preload:
        try:
            importlib.import_module(module)
            print(f"预加载: {module}")
        except ImportError as e:
            print(f"预加载失败 {module}: {e}")

# 在后台线程中预加载
def background_preload():
    thread = threading.Thread(target=preload_modules, daemon=True)
    thread.start()

if __name__ == "__main__":
    background_preload()
EOF

    chmod +x "$SCRIPT_DIR/preload_modules.py"
    success "预加载脚本创建完成"
    
    # 添加预加载任务到 crontab（如果不存在）
    if ! crontab -l | grep -q "preload_modules.py"; then
        (crontab -l 2>/dev/null; echo "@reboot sleep 30 && cd '$SCRIPT_DIR' && '$VENV_DIR/bin/python3' preload_modules.py") | crontab -
        log "已添加预加载任务到 crontab"
    fi
}

# 创建桌面图标
create_desktop_icon() {
    local script_path="$SCRIPT_DIR/$SCRIPT_NAME"
    local venv_python="$SCRIPT_DIR/$VENV_DIR/bin/python3"
    local icon_path="$SCRIPT_DIR/icon.png"
    
    # 使用极速启动脚本作为桌面图标的执行目标
    local desktop_content="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=AI-powered screen translator with OCR
Exec=$FAST_LAUNCHER
Icon=$icon_path
Terminal=false
StartupNotify=true
Categories=Utility;Office;Translation;
Keywords=translate;ocr;screen;ai;
StartupWMClass=skylark-translator
Path=$SCRIPT_DIR"

    # 创建桌面图标文件
    local desktop_file_path="$HOME/Desktop/$DESKTOP_FILE"
    echo "$desktop_content" > "$desktop_file_path"
    chmod +x "$desktop_file_path"
    
    # 也创建到应用程序菜单
    local menu_dir="$HOME/.local/share/applications"
    mkdir -p "$menu_dir"
    cp "$desktop_file_path" "$menu_dir/$DESKTOP_FILE"
    
    success "桌面图标已创建: $desktop_file_path"
    info "双击桌面图标将使用极速启动脚本启动应用"
}

# 启动脚本
launch_script() {
    log "启动 $APP_NAME..."
    
    cd "$SCRIPT_DIR"
    
    # 激活虚拟环境
    source "$VENV_DIR/bin/activate"
    
    # 设置环境变量
    export TMPDIR="$LOCAL_TMP_DIR"
    export PATH="$(pwd)/$VENV_DIR/bin:$PATH"
    export ARGOS_PACKAGES_DIR="$(pwd)/argos_packages"
    export TESSDATA_PREFIX="$(pwd)/tessdata"
    export QT_QPA_PLATFORM=xcb
    
    # 创建必要目录
    mkdir -p "$ARGOS_PACKAGES_DIR" "$TESSDATA_PREFIX"
    
    # 启动前验证
    if python3 -c "import argostranslate" 2>/dev/null; then
        info "✓ 翻译功能可用"
    else
        warn "△ 翻译功能不可用，仅提供 OCR 功能"
    fi
    
    # 启动脚本
    python3 "$SCRIPT_NAME"
}

# 显示完成信息
show_completion_info() {
    echo
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $APP_NAME 安装完成！${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    echo -e "${GREEN}✓ 环境配置完成${NC}"
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
    echo -e "${GREEN}✓ 桌面图标已创建${NC}"
    echo -e "${GREEN}✓ 本地临时目录: $LOCAL_TMP_DIR${NC}"
    echo
    echo -e "${YELLOW}使用方法：${NC}"
    echo -e "  1. 双击桌面图标启动（极速模式）"
    echo -e "  2. 或运行: ${BLUE}$FAST_LAUNCHER${NC}（极速模式）"
    echo -e "  3. 或运行: ${BLUE}$(basename "$0")${NC}（完整模式）"
    echo -e "  4. 或在应用程序菜单中查找"
    echo
    echo -e "${YELLOW}功能说明：${NC}"
    echo -e "  • OCR 功能：已可用"
    echo -e "  • 翻译功能：需要时可手动安装 argostranslate"
    echo -e "  • 语言包：应用内可下载"
    echo -e "  • 临时文件：保存在 $LOCAL_TMP_DIR"
    echo -e "  • 详细日志：$LOG_FILE"
    echo
    echo -e "${BLUE}启动速度优化：${NC}"
    echo -e "  • 极速启动脚本: $FAST_LAUNCHER"
    echo -e "  • 预加载模块: $SCRIPT_DIR/preload_modules.py"
    echo
    echo -e "${BLUE}目录结构：${NC}"
    echo -e "  $SCRIPT_DIR/"
    echo -e "  ├── $SCRIPT_NAME           # 主程序"
    echo -e "  ├── venv/                   # Python 虚拟环境"
    echo -e "  ├── tmp/                    # 临时下载文件"
    echo -e "  ├── skylark_fast.sh         # 极速启动脚本"
    echo -e "  ├── preload_modules.py      # 预加载脚本"
    echo -e "  └── $(basename "$0")      # 安装配置脚本"
    echo
}

# 清理安装临时文件
cleanup_installation_temp() {
    if [[ -d "$LOCAL_TMP_DIR" ]]; then
        local tmp_size=$(du -sh "$LOCAL_TMP_DIR" 2>/dev/null | cut -f1)
        
        echo
        read -p "是否删除安装临时文件夹 tmp/ (大小: $tmp_size)？ (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$LOCAL_TMP_DIR"
            success "已删除临时文件夹: $LOCAL_TMP_DIR"
        else
            info "保留临时文件夹: $LOCAL_TMP_DIR"
        fi
    fi
}

# 清理函数（仅清理系统临时目录）
cleanup_old_temp() {
    # 静默清理系统临时目录中的相关文件
    local system_tmp_patterns=(
        "/tmp/pip-*"
        "/tmp/tmp*argos*"
        "$HOME/tmp/pip-*"
    )
    
    for pattern in "${system_tmp_patterns[@]}"; do
        if ls $pattern 2>/dev/null | head -1 >/dev/null; then
            rm -rf $pattern 2>/dev/null || true
            log "已清理系统临时文件: $pattern"
        fi
    done
    
    # 显示本地临时目录使用情况（不清理）
    if [[ -d "$LOCAL_TMP_DIR" ]]; then
        local tmp_size=$(du -sh "$LOCAL_TMP_DIR" 2>/dev/null | cut -f1)
        info "本地临时目录大小: $tmp_size ($LOCAL_TMP_DIR)"
    fi
}

# 主函数
main() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $APP_NAME Linux 启动器${NC}"
    echo -e "${CYAN}  通用版本 - 支持所有主流发行版${NC}"
    echo -e "${CYAN}  Lubuntu 24.04 优化版本${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    
    # 清理旧日志
    > "$LOG_FILE"
    
    # 系统检测
    detect_distro
    detect_lubuntu
    setup_package_manager
    
    # 基础检查
    check_root
    check_script
    
    # 创建本地临时目录
    setup_local_tmp
    
    # 环境检查
    local need_system_install=false
    local need_python_install=false
    local need_venv_setup=false
    
    # 检查系统依赖
    if ! check_system_dependencies; then
        need_system_install=true
    fi
    
    # 检查虚拟环境
    if ! check_virtual_env; then
        need_venv_setup=true
        need_python_install=true
    else
        # 检查 Python 依赖
        if ! check_python_dependencies; then
            need_python_install=true
        fi
    fi
    
    # 执行安装
    if [[ "$need_system_install" == "true" ]]; then
        echo
        info "需要安装系统依赖，需要管理员权限..."
        read -p "是否继续安装？ (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            error "用户取消安装"
            exit 1
        fi
        install_system_dependencies
    fi
    
    if [[ "$need_venv_setup" == "true" ]]; then
        setup_virtual_env
    fi
    
    if [[ "$need_python_install" == "true" ]]; then
        # 清理旧的临时文件
        cleanup_old_temp
        install_python_dependencies
    fi
    
    # 验证安装
    if ! verify_installation; then
        error "环境验证失败"
        exit 1
    fi
    
    # 创建极速启动脚本和预加载脚本
    create_fast_launcher
    create_preload_script
    
    # 创建桌面图标
    create_desktop_icon
    
    # 显示完成信息
    show_completion_info
    cleanup_installation_temp
    
    # 询问是否立即启动
    echo
    read -p "是否立即启动应用？ (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo
        launch_script
    else
        success "安装完成！可随时通过桌面图标启动应用。"
    fi
}

# 信号处理
trap 'error "脚本被中断"; exit 1' INT TERM

# 运行主函数
main "$@"