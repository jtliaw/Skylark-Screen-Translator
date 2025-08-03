#!/bin/bash
# Skylark Screen Translator - 简化卸载脚本
# 只提供3个主要卸载选项

set -e

APP_NAME="Skylark Screen Translator"
SCRIPT_NAME="skylark_screen_translator.py"
VENV_DIR="venv"
DESKTOP_FILE="skylark-translator.desktop"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

success() {
    echo -e "${PURPLE}[$(date +'%H:%M:%S')] SUCCESS:${NC} $1"
}

# 检测Linux发行版
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi
    
    log "检测到系统: $DISTRO"
}

# 检查包管理器
setup_package_manager() {
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            PKG_MANAGER="apt"
            PKG_REMOVE="sudo apt remove -y"
            PKG_AUTOREMOVE="sudo apt autoremove -y"
            ;;
        fedora|centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_REMOVE="sudo dnf remove -y"
            else
                PKG_MANAGER="yum"
                PKG_REMOVE="sudo yum remove -y"
            fi
            PKG_AUTOREMOVE="$PKG_REMOVE"
            ;;
        arch|manjaro|endeavouros)
            PKG_MANAGER="pacman"
            PKG_REMOVE="sudo pacman -R --noconfirm"
            PKG_AUTOREMOVE="sudo pacman -Rns --noconfirm"
            ;;
        opensuse*|suse)
            PKG_MANAGER="zypper"
            PKG_REMOVE="sudo zypper remove -y"
            PKG_AUTOREMOVE="$PKG_REMOVE"
            ;;
        *)
            warn "不支持的发行版: $DISTRO，跳过系统包操作"
            PKG_MANAGER="unknown"
            ;;
    esac
}

# 检查虚拟环境是否存在
check_venv() {
    [[ -d "$SCRIPT_DIR/$VENV_DIR" ]]
}

# 删除桌面图标和启动器
remove_desktop_items() {
    log "删除桌面图标和启动器..."
    
    local files_to_remove=(
        "$HOME/Desktop/$DESKTOP_FILE"
        "$HOME/.local/share/applications/$DESKTOP_FILE"
        "$SCRIPT_DIR/skylark_direct.sh"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            log "删除: $file"
            rm -f "$file"
        fi
    done
    
    success "桌面图标和启动器已删除"
}

# 清理 argostranslate 用户数据
clean_argos_user_data() {
    log "清理 argostranslate 用户数据..."
    
    local user_argos_dirs=(
        "$HOME/.argosmodel"
        "$HOME/.local/share/argos-translate"
        "$HOME/.cache/argos-translate"
        "$HOME/.argostranslate"
    )
    
    for dir in "${user_argos_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "未知")
            log "清理目录: $dir (大小: $dir_size)"
            rm -rf "$dir"
        fi
    done
    
    success "argostranslate 用户数据清理完成"
}

# 1. 仅卸载 argostranslate（包括语言包、虚拟环境、桌面图标）
uninstall_argostranslate_only() {
    log "=== 卸载 argostranslate 翻译功能 ==="
    
    # 删除虚拟环境（argostranslate 就在其中）
    if check_venv; then
        local venv_size=$(du -sh "$SCRIPT_DIR/$VENV_DIR" 2>/dev/null | cut -f1 || echo "未知")
        log "删除虚拟环境: $SCRIPT_DIR/$VENV_DIR (大小: $venv_size)"
        rm -rf "$SCRIPT_DIR/$VENV_DIR"
        success "虚拟环境已删除"
    else
        warn "虚拟环境不存在"
    fi
    
    # 清理 argostranslate 用户数据
    clean_argos_user_data
    
    # 删除桌面图标
    remove_desktop_items
    
    # 清理旧的 tmp 目录（如果存在）
    local tmp_dir="$SCRIPT_DIR/tmp"
    if [[ -d "$tmp_dir" ]]; then
        local tmp_size=$(du -sh "$tmp_dir" 2>/dev/null | cut -f1 || echo "未知")
        log "删除临时文件目录: $tmp_dir (大小: $tmp_size)"
        rm -rf "$tmp_dir"
    fi
    
    success "argostranslate 翻译功能卸载完成"
    info "系统 OCR 功能和依赖包已保留"
}

# 2. 仅卸载 OCR 相关组件
uninstall_ocr_only() {
    log "=== 卸载 OCR 相关组件 ==="
    
    # 删除虚拟环境（OCR 相关 Python 包在其中）
    if check_venv; then
        local venv_size=$(du -sh "$SCRIPT_DIR/$VENV_DIR" 2>/dev/null | cut -f1 || echo "未知")
        log "删除虚拟环境: $SCRIPT_DIR/$VENV_DIR (大小: $venv_size)"
        rm -rf "$SCRIPT_DIR/$VENV_DIR"
        success "虚拟环境已删除"
    else
        warn "虚拟环境不存在"
    fi
    
    # 删除桌面图标
    remove_desktop_items
    
    # 询问是否卸载系统 Tesseract OCR
    if [[ "$PKG_MANAGER" != "unknown" ]] && command -v tesseract &> /dev/null; then
        echo
        warn "检测到系统安装的 Tesseract OCR"
        warn "卸载后将影响所有使用 OCR 的应用程序"
        read -p "是否卸载系统 Tesseract OCR？ (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "卸载系统 Tesseract OCR..."
            case $PKG_MANAGER in
                apt)
                    eval "$PKG_REMOVE tesseract-ocr tesseract-ocr-* libtesseract-dev libleptonica-dev" 2>/dev/null || warn "部分包卸载失败"
                    ;;
                dnf|yum)
                    eval "$PKG_REMOVE tesseract tesseract-* leptonica-devel" 2>/dev/null || warn "部分包卸载失败"
                    ;;
                pacman)
                    eval "$PKG_REMOVE tesseract tesseract-data-* leptonica" 2>/dev/null || warn "部分包卸载失败"
                    ;;
                zypper)
                    eval "$PKG_REMOVE tesseract-ocr tesseract-ocr-* leptonica-devel" 2>/dev/null || warn "部分包卸载失败"
                    ;;
            esac
            success "系统 Tesseract OCR 已卸载"
        else
            info "保留系统 Tesseract OCR"
        fi
    else
        info "未检测到系统 Tesseract OCR 或包管理器不支持"
    fi
    
    success "OCR 组件卸载完成"
    info "argostranslate 用户数据已保留"
}

# 3. 完全卸载
uninstall_complete() {
    log "=== 完全卸载 $APP_NAME ==="
    
    # 删除虚拟环境
    if check_venv; then
        local venv_size=$(du -sh "$SCRIPT_DIR/$VENV_DIR" 2>/dev/null | cut -f1 || echo "未知")
        log "删除虚拟环境: $SCRIPT_DIR/$VENV_DIR (大小: $venv_size)"
        rm -rf "$SCRIPT_DIR/$VENV_DIR"
        success "虚拟环境已删除"
    else
        warn "虚拟环境不存在"
    fi
    
    # 清理 argostranslate 用户数据
    clean_argos_user_data
    
    # 删除桌面图标
    remove_desktop_items
    
    # 清理旧的 tmp 目录
    local tmp_dir="$SCRIPT_DIR/tmp"
    if [[ -d "$tmp_dir" ]]; then
        local tmp_size=$(du -sh "$tmp_dir" 2>/dev/null | cut -f1 || echo "未知")
        log "删除临时文件目录: $tmp_dir (大小: $tmp_size)"
        rm -rf "$tmp_dir"
    fi
    
    # 询问是否卸载系统依赖
    if [[ "$PKG_MANAGER" != "unknown" ]]; then
        echo
        warn "是否卸载系统依赖包？"
        warn "注意：这些包可能被其他应用程序使用"
        read -p "卸载系统依赖包？ (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "卸载系统依赖包..."
            
            case $PKG_MANAGER in
                apt)
                    local packages=(
                        "tesseract-ocr" "tesseract-ocr-*" "libtesseract-dev" "libleptonica-dev"
                        "python3-pyqt5" "qtbase5-dev" "qt5-qmake"
                        "python3-dev" "build-essential" "cmake"
                        "libx11-dev" "libxext-dev" "libxrandr-dev" "libxi-dev" "libxss-dev"
                        "libjpeg-dev" "zlib1g-dev" "libtiff-dev" "libpng-dev"
                    )
                    ;;
                dnf|yum)
                    local packages=(
                        "tesseract" "tesseract-*" "leptonica-devel"
                        "python3-qt5" "python3-qt5-devel" "qt5-qtbase-devel"
                        "python3-devel" "gcc" "gcc-c++" "cmake"
                        "libX11-devel" "libXext-devel" "libXrandr-devel" "libXi-devel" "libXss-devel"
                        "libjpeg-turbo-devel" "zlib-devel" "libtiff-devel" "libpng-devel"
                    )
                    ;;
                pacman)
                    local packages=(
                        "tesseract" "tesseract-data-*" "leptonica"
                        "python-pyqt5" "python-pyqt5-sip" "qt5-base"
                        "base-devel" "cmake"
                        "libx11" "libxext" "libxrandr" "libxi" "libxss"
                        "libjpeg-turbo" "zlib" "libtiff" "libpng"
                    )
                    ;;
                zypper)
                    local packages=(
                        "tesseract-ocr" "tesseract-ocr-*" "leptonica-devel"
                        "python3-qt5" "python3-qt5-devel" "libqt5-qtbase-devel"
                        "python3-devel" "gcc" "gcc-c++" "cmake"
                        "libX11-devel" "libXext-devel" "libXrandr-devel" "libXi-devel" "libXss-devel"
                        "libjpeg8-devel" "zlib-devel" "libtiff-devel" "libpng16-devel"
                    )
                    ;;
            esac
            
            for package in "${packages[@]}"; do
                eval "$PKG_REMOVE $package" 2>/dev/null || true
            done
            
            # 自动清理
            log "清理未使用的依赖..."
            eval "$PKG_AUTOREMOVE" 2>/dev/null || true
            
            success "系统依赖包卸载完成"
        else
            info "保留系统依赖包"
        fi
    else
        info "跳过系统依赖包卸载（不支持的包管理器）"
    fi
    
    success "完全卸载完成"
}

# 显示当前安装状态
show_status() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $APP_NAME 安装状态${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    
    # 检查虚拟环境
    if check_venv; then
        local venv_size=$(du -sh "$SCRIPT_DIR/$VENV_DIR" 2>/dev/null | cut -f1 || echo "未知")
        log "✓ 虚拟环境存在 (大小: $venv_size)"
        
        # 检查关键模块
        if [[ -f "$SCRIPT_DIR/$VENV_DIR/bin/python3" ]]; then
            source "$SCRIPT_DIR/$VENV_DIR/bin/activate"
            echo "  主要组件："
            
            if python3 -c "import argostranslate" 2>/dev/null; then
                echo "    ✓ argostranslate 翻译引擎"
            else
                echo "    ✗ argostranslate 翻译引擎"
            fi
            
            if python3 -c "import pytesseract" 2>/dev/null; then
                echo "    ✓ pytesseract OCR"
            else
                echo "    ✗ pytesseract OCR"
            fi
            
            if python3 -c "import PyQt5" 2>/dev/null; then
                echo "    ✓ PyQt5 GUI"
            else
                echo "    ✗ PyQt5 GUI"
            fi
        fi
    else
        warn "✗ 虚拟环境不存在"
    fi
    
    echo
    
    # 检查系统 OCR
    if command -v tesseract &> /dev/null; then
        local tesseract_version=$(tesseract --version 2>&1 | head -n1)
        log "✓ 系统 Tesseract: $tesseract_version"
    else
        warn "✗ 系统 Tesseract 未安装"
    fi
    
    # 检查桌面图标
    if [[ -f "$HOME/Desktop/$DESKTOP_FILE" ]]; then
        log "✓ 桌面图标存在"
    else
        warn "✗ 桌面图标不存在"
    fi
    
    # 检查 argostranslate 数据
    local argos_dirs=(
        "$HOME/.argosmodel"
        "$HOME/.local/share/argos-translate"
        "$HOME/.cache/argos-translate"
    )
    
    local has_argos_data=false
    for dir in "${argos_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            has_argos_data=true
            local dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "未知")
            log "✓ argostranslate 数据: $dir (大小: $dir_size)"
        fi
    done
    
    if [[ "$has_argos_data" == "false" ]]; then
        warn "✗ 未发现 argostranslate 数据目录"
    fi
    
    # 检查临时目录
    local tmp_dir="$SCRIPT_DIR/tmp"
    if [[ -d "$tmp_dir" ]]; then
        local tmp_size=$(du -sh "$tmp_dir" 2>/dev/null | cut -f1 || echo "未知")
        log "✓ 临时文件目录存在 (大小: $tmp_size)"
    else
        info "○ 临时文件目录不存在"
    fi
    
    echo
}

# 显示菜单
show_menu() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $APP_NAME 卸载工具${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo
    echo "请选择卸载选项："
    echo
    echo "1) 仅卸载 argostranslate 翻译功能"
    echo "   (删除虚拟环境、语言包、桌面图标，保留系统OCR)"
    echo
    echo "2) 仅卸载 OCR 相关组件"
    echo "   (删除虚拟环境、桌面图标，保留argostranslate数据)"
    echo
    echo "3) 完全卸载"
    echo "   (删除所有组件、数据、图标，可选删除系统依赖)"
    echo
    echo "4) 显示当前安装状态"
    echo
    echo "0) 退出"
    echo
}

# 主函数
main() {
    detect_distro
    setup_package_manager
    
    while true; do
        show_menu
        read -p "请输入选项 (0-4): " choice
        echo
        
        case $choice in
            1)
                echo "=== 卸载 argostranslate 翻译功能 ==="
                echo "这将删除："
                echo "• 整个虚拟环境（包含所有Python包）"
                echo "• 所有语言包和模型文件"
                echo "• 桌面图标和启动器"
                echo "• 临时文件目录"
                echo "• 保留系统OCR和依赖包"
                echo
                read -p "确认执行？ (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    uninstall_argostranslate_only
                else
                    info "取消操作"
                fi
                ;;
            2)
                echo "=== 卸载 OCR 相关组件 ==="
                echo "这将删除："
                echo "• 整个虚拟环境（包含所有Python包）"
                echo "• 桌面图标和启动器"
                echo "• 可选删除系统Tesseract OCR"
                echo "• 保留argostranslate语言包数据"
                echo
                read -p "确认执行？ (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    uninstall_ocr_only
                else
                    info "取消操作"
                fi
                ;;
            3)
                echo "=== 完全卸载 ==="
                echo "警告：这将删除所有相关文件和数据！"
                echo "包括："
                echo "• 整个虚拟环境"
                echo "• 所有语言包和模型文件"
                echo "• 桌面图标和启动器"
                echo "• 临时文件目录"
                echo "• 可选删除系统依赖包"
                echo
                read -p "确认执行完全卸载？ (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    uninstall_complete
                else
                    info "取消完全卸载"
                fi
                ;;
            4)
                show_status
                ;;
            0)
                log "退出卸载工具"
                exit 0
                ;;
            *)
                error "无效选项，请重新选择"
                ;;
        esac
        
        echo
        read -p "按 Enter 键继续..." -r
        clear
    done
}

# 信号处理
trap 'error "脚本被中断"; exit 1' INT TERM

# 运行主函数
main "$@"