#!/bin/bash

# ============================================================
# Skylark-Screen-Translator AppImage 打包脚本
# ============================================================
# 说明：
# 本脚本用于一键打包 Skylark-Screen-Translator 为 AppImage。
# 用户只需修改下方 "选择要打包的语言对" 部分，即可定制需要的 OCR & 翻译语言。
#
# 修改方法：
# 1. 找到以下代码：
#       # 选择要打包的语言对（可自行增减）
#       desired_langs = ['en', 'zh', 'ja', 'ko']
#       target_packages = [
#           pkg for pkg in available_packages
#           if pkg.from_code in desired_langs and pkg.to_code in desired_langs
#       ]
#
# 2. 在 desired_langs 列表中添加或删除语言代码。
#    例如：
#       desired_langs = ['en', 'zh', 'ja']  # 英文、中文、日文
#       desired_langs = ['en', 'de', 'it']  # 英文、德语、意大利语
#
# 3. 支持的语言代码对照表（Tesseract OCR / Argos Translate）：
# ------------------------------------------------------------
# 'en'  英文         English
# 'zh'  中文         Chinese
# 'ja'  日文         Japanese
# 'ko'  韩文         Korean
# 'de'  德语         German
# 'fr'  法语         French
# 'it'  意大利语     Italian
# 'es'  西班牙语     Spanish
# 'pt'  葡萄牙语     Portuguese
# 'ru'  俄语         Russian
# 'ar'  阿拉伯语     Arabic
# 'hi'  印地语       Hindi
# 'tr'  土耳其语     Turkish
# 'vi'  越南语       Vietnamese
# 'th'  泰语         Thai
# 'id'  印度尼西亚语 Indonesian
# 'ms'  马来语       Malay
# 'fa'  波斯语       Persian
# 'nl'  荷兰语       Dutch
# 'uk'  乌克兰语     Ukrainian
# 'pl'  波兰语       Polish
# 'sv'  瑞典语       Swedish
# 'fi'  芬兰语       Finnish
# 'cs'  捷克语       Czech
# 'el'  希腊语       Greek
# ------------------------------------------------------------
#
# 注意：
# - Argos Translate 并非所有语言都互译，请查看 Argos 官方支持的语言对。
# - Tesseract OCR 仅影响文字识别，翻译由 Argos Translate / 在线翻译完成。
# - 修改完 desired_langs 后，运行本脚本即可生成对应语言版本的 AppImage。
#
# GitHub 项目地址: https://github.com/jtliaw/Skylark-Screen-Translator
# ============================================================

# 离线翻译专用 AppImage 构建脚本
# 专门解决argostranslate安装和PIL.ImageGrab问题，包含所有依赖模块
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }

# 设置大容量临时目录
setup_large_temp_dir() {
    log_info "设置大容量临时目录..."
    
    # 创建临时目录在用户家目录（通常有更多空间）
    LARGE_TEMP_DIR="$HOME/skylark_build_temp"
    mkdir -p "$LARGE_TEMP_DIR"
    
    # 设置所有临时目录相关的环境变量
    export TMPDIR="$LARGE_TEMP_DIR"
    export TMP="$LARGE_TEMP_DIR" 
    export TEMP="$LARGE_TEMP_DIR"
    export PIP_CACHE_DIR="$LARGE_TEMP_DIR/pip_cache"
    export XDG_CACHE_HOME="$LARGE_TEMP_DIR/cache"
    
    # 创建pip缓存目录
    mkdir -p "$PIP_CACHE_DIR"
    mkdir -p "$XDG_CACHE_HOME"
    
    # 显示空间信息
    home_space=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    current_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    
    log_info "当前目录可用空间: ${current_space}GB"
    log_info "家目录可用空间: ${home_space}GB"
    log_info "临时目录设置为: $LARGE_TEMP_DIR"
    
    if [ "$home_space" -lt 10 ]; then
        log_error "家目录空间不足10GB，可能无法完成构建"
        exit 1
    fi
    
    log_success "大容量临时目录设置完成"
}

# 清理磁盘空间
cleanup_disk_space() {
    log_info "清理磁盘空间为argostranslate腾出空间..."
    
    # 清理apt缓存
    sudo apt clean || true
    
    # 清理Python缓存
    find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    
    # 清理旧的构建文件
    rm -rf build dist *.spec venv AppDir 2>/dev/null || true
    rm -rf ~/.cache/pip 2>/dev/null || true
    
    # 清理之前的临时目录
    rm -rf "$HOME/skylark_build_temp" 2>/dev/null || true
    
    log_success "磁盘空间清理完成"
}

# 安装系统依赖（修复版）
install_system_deps() {
    log_info "安装系统依赖（包括tkinter支持）..."
    
    # 更新包列表
    sudo apt update
    
    # 安装编译工具和库，特别添加tkinter和相关GUI支持
    sudo apt install -y \
        build-essential \
        python3-dev \
        python3-venv \
        python3-pip \
        python3-tk \
        libxcb1 \
        libxcb-xinerama0 \
        libxcb-cursor0 \
        tesseract-ocr \
        tesseract-ocr-chi-sim \
        tesseract-ocr-chi-tra \
        libtesseract-dev \
        pkg-config \
        wget \
        curl \
        git \
        tk-dev \
        tcl-dev \
        libtk8.6 \
        libtcl8.6 || {
        log_warn "某些系统依赖安装失败，继续尝试..."
    }
    
    # 验证tkinter是否可用
    log_info "验证tkinter安装..."
    python3 -c "
try:
    import tkinter
    print('✅ tkinter 可用')
    from tkinter import TkVersion
    print(f'Tk version: {TkVersion}')
except ImportError as e:
    print(f'❌ tkinter 不可用: {e}')
    exit(1)
"
    
    if [ $? -eq 0 ]; then
        log_success "系统依赖安装完成，tkinter验证通过"
    else
        log_error "tkinter验证失败，可能影响ttkthemes安装"
        # 尝试替代方案
        log_info "尝试安装替代方案..."
        sudo apt install -y python3-tk tk8.6-dev tcl8.6-dev
    fi
}

# 创建优化的虚拟环境（修复版）
create_optimized_venv() {
    log_info "创建优化的虚拟环境（支持离线翻译）..."
    
    # 在大容量目录创建虚拟环境
    VENV_DIR="$LARGE_TEMP_DIR/venv"
    python3 -m venv "$VENV_DIR" --system-site-packages
    source "$VENV_DIR/bin/activate"
    
    # 升级pip到最新版本
    pip install --upgrade pip setuptools wheel
    
    # 设置pip使用国内镜像和大缓存目录
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple/
    pip config set global.cache-dir "$PIP_CACHE_DIR"
    pip config set global.timeout 300
    
    log_info "安装核心依赖（顺序很重要）..."
    
    # 1. 先安装PyQt5（较小）
    log_info "安装PyQt5..."
    pip install --no-cache-dir PyQt5==5.15.10
    
    # 2. 安装图像处理库（完整版PIL）
    log_info "安装完整版Pillow（支持ImageGrab）..."
    pip install --no-cache-dir "Pillow>=9.0.0"
    
    # 3. 安装数值计算
    log_info "安装NumPy..."
    pip install --no-cache-dir "numpy>=1.21.0"
    
    # 4. 安装OpenCV（无头版本节省空间）
    log_info "安装OpenCV..."
    pip install --no-cache-dir opencv-python-headless
    
    # 5. 安装其他工具（分别安装以处理可能的错误）
    log_info "安装工具库..."
    
    # 逐个安装以便于调试
    pip install --no-cache-dir pytesseract
    pip install --no-cache-dir mss
    pip install --no-cache-dir pynput
    pip install --no-cache-dir requests
    pip install --no-cache-dir screeninfo
    pip install --no-cache-dir certifi
    pip install --no-cache-dir pyinstaller
    
    # 尝试安装ttkthemes，如果失败则跳过
    log_info "尝试安装ttkthemes（如果失败将跳过）..."
    if ! pip install --no-cache-dir ttkthemes; then
        log_warn "ttkthemes安装失败，将跳过此依赖"
        log_info "应用仍可正常运行，只是可能缺少某些主题支持"
    else
        log_success "ttkthemes安装成功"
    fi
    
    log_success "核心依赖安装完成"
}

# 专门安装argostranslate（使用CPU版本避免CUDA依赖）
install_argostranslate() {
    log_info "专门安装argostranslate离线翻译库（CPU版本）..."
    
    source "$VENV_DIR/bin/activate"
    
    # 设置环境变量强制使用CPU版本
    export FORCE_CUDA="0"
    export USE_CUDA="0"
    
    # 增加超时时间和重试次数
    export PIP_TIMEOUT=600
    export PIP_DEFAULT_TIMEOUT=600
    export PIP_RETRIES=3
    
    log_info "分步安装翻译依赖（避免大文件下载）..."
    
    # 先安装较小的依赖
    log_info "安装基础依赖..."
    pip install --no-cache-dir PyYAML requests packaging six
    
    # 安装句子分割库
    log_info "安装sentencepiece..."
    pip install --no-cache-dir sentencepiece
    
    # 安装CPU版本的PyTorch（避免CUDA依赖）
    log_info "安装CPU版本的PyTorch..."
    pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    
    # 安装stanza（使用CPU版本）
    log_info "安装stanza（NLP库，CPU版本）..."
    pip install --no-cache-dir stanza
    
    # 安装ctranslate2（CPU版本）
    log_info "安装ctranslate2（翻译引擎，CPU版本）..."
    pip install --no-cache-dir ctranslate2
    
    # 最后安装argostranslate
    log_info "安装argostranslate主包..."
    pip install --no-cache-dir argostranslate
    
    # 验证安装
    log_info "验证argostranslate安装..."
    python3 -c "
try:
    import argostranslate.package
    import argostranslate.translate
    print('✅ argostranslate安装成功')
    try:
        packages = argostranslate.package.get_available_packages()
        print(f'可用包数量: {len(packages)}')
    except Exception as e:
        print(f'获取包列表失败: {e}，但基本功能可用')
    print('✅ 安装验证通过')
except ImportError as e:
    print(f'❌ argostranslate安装失败: {e}')
    exit(1)
"
    
    if [ $? -eq 0 ]; then
        log_success "argostranslate安装成功！"
        return 0
    else
        log_error "argostranslate安装失败"
        return 1
    fi
}

# 预下载语言包到临时目录
download_language_packages() {
    log_info "预下载中英翻译包到临时目录..."
    
    source "$VENV_DIR/bin/activate"
    
    # 设置argostranslate包目录到临时目录
    ARGOS_PACKAGES_DIR="$LARGE_TEMP_DIR/argos_packages"
    mkdir -p "$ARGOS_PACKAGES_DIR"
    export ARGOS_PACKAGES_DIR
    
    python3 << 'EOF'
import os
import argostranslate.package
import argostranslate.translate
import sys

# 确保包目录存在
packages_dir = os.environ.get('ARGOS_PACKAGES_DIR')
if packages_dir:
    os.makedirs(packages_dir, exist_ok=True)
    print(f"包目录设置为: {packages_dir}")

try:
    print("更新包索引...")
    argostranslate.package.update_package_index()
    
    print("查找可用语言包...")
    available_packages = argostranslate.package.get_available_packages()
    print(f"找到 {len(available_packages)} 个可用包")
    
    # 选择要打包的语言对（可自行增减）
    desired_langs = ['en']
    target_packages = [
        pkg for pkg in available_packages
        if pkg.from_code in desired_langs and pkg.to_code in desired_langs
    ]

    print(f"准备下载 {len(target_packages)} 个包...")
    installed_count = 0
    for pkg in target_packages:
        try:
            print(f"下载并安装: {pkg.from_code} -> {pkg.to_code}")
            download_path = pkg.download()
            argostranslate.package.install_from_path(download_path)
            print(f"✅ 安装成功: {pkg.from_code} -> {pkg.to_code}")
            installed_count += 1
        except Exception as e:
            print(f"❌ 安装失败: {e}")
    
    # 检查已安装的包
    installed_packages = argostranslate.package.get_installed_packages()
    print(f"\n已安装语言包数量: {len(installed_packages)}")
    for pkg in installed_packages:
        print(f"  - {pkg.from_code} -> {pkg.to_code}")
    
    # 测试翻译功能
    if installed_packages:
        test_pkg = installed_packages[0]
        try:
            test_text = "Hello world"
            if test_pkg.from_code == 'zh':
                test_text = "你好世界"
            
            result = argostranslate.translate.translate(
                test_text, 
                test_pkg.from_code, 
                test_pkg.to_code
            )
            print(f"\n测试翻译:")
            print(f"原文: {test_text}")
            print(f"译文: {result}")
            print("✅ 翻译功能测试成功！")
        except Exception as e:
            print(f"❌ 翻译测试失败: {e}")
    else:
        print("⚠️  未安装任何语言包，但基础框架可用")
        
except Exception as e:
    print(f"语言包下载过程出错: {e}")
    print("但argostranslate基础功能仍然可用")
EOF
    
    log_success "语言包下载完成"
}

# 检查并增强现有的online_translator.py
enhance_online_translator() {
    log_info "检查并增强online_translator.py..."
    
    if [ ! -f "online_translator.py" ]; then
        log_error "找不到online_translator.py文件"
        log_error "请确保该文件在当前目录中"
        exit 1
    fi
    
    # 创建备份
    cp "online_translator.py" "online_translator.py.backup"
    log_info "已备份原文件为 online_translator.py.backup"
    
    # 检查是否已有get_available_translators方法
    if grep -q "get_available_translators" "online_translator.py"; then
        log_info "online_translator.py 已包含 get_available_translators 方法"
        return 0
    fi
    
    log_info "为online_translator.py添加缺失的方法..."
    
    # 在文件末尾添加缺失的方法
    cat >> "online_translator.py" <<'EOF'

# =============================================================================
# 以下是为支持主应用而添加的增强方法
# =============================================================================

def get_available_translators(self):
    """
    获取可用的翻译器列表（兼容主应用）
    返回格式: [{'name': 'translator_name', 'display_name': 'Display Name'}]
    """
    try:
        import argostranslate.package
        
        translators = []
        installed_packages = argostranslate.package.get_installed_packages()
        
        # 基于已安装的包创建翻译器列表
        for pkg in installed_packages:
            translator_name = f"argos_{pkg.from_code}_to_{pkg.to_code}"
            from_lang_name = _get_language_name(pkg.from_code)
            to_lang_name = _get_language_name(pkg.to_code)
            display_name = f"Argos: {from_lang_name} → {to_lang_name}"
            
            translators.append({
                'name': translator_name,
                'display_name': display_name,
                'from_lang': pkg.from_code,
                'to_lang': pkg.to_code
            })
        
        # 如果没有安装包，返回默认选项
        if not translators:
            translators = [
                {
                    'name': 'argos_auto', 
                    'display_name': 'Argos (离线翻译)', 
                    'from_lang': 'auto', 
                    'to_lang': 'auto'
                },
            ]
        
        # 如果原有的翻译器类存在，也添加它们
        if 'default_translator' in globals() and hasattr(default_translator, 'name'):
            translators.insert(0, {
                'name': 'original_translator',
                'display_name': default_translator.name,
                'from_lang': 'auto',
                'to_lang': 'auto'
            })
        
        logger.info(f"返回 {len(translators)} 个可用翻译器")
        return translators
        
    except Exception as e:
        logger.error(f"获取翻译器列表失败: {e}")
        return [
            {
                'name': 'fallback_translator', 
                'display_name': '离线翻译 (备用)', 
                'from_lang': 'auto', 
                'to_lang': 'auto'
            }
        ]

def _get_language_name(lang_code):
    """获取语言代码对应的显示名称"""
    lang_names = {
        'en': 'English',
        'zh': '中文',
        'es': 'Español',
        'fr': 'Français',
        'de': 'Deutsch',
        'ja': '日本語',
        'ko': '한국어',
        'ru': 'Русский',
        'it': 'Italiano',
        'pt': 'Português',
        'ar': 'العربية',
        'hi': 'हिन्दी',
        'th': 'ไทย',
        'vi': 'Tiếng Việt',
        'tr': 'Türkçe',
        'pl': 'Polski',
        'nl': 'Nederlands',
        'sv': 'Svenska',
        'da': 'Dansk',
        'no': 'Norsk',
        'fi': 'Suomi',
    }
    return lang_names.get(lang_code, lang_code.upper())

# 为OnlineTranslator类添加缺失的方法（如果类存在）
if 'OnlineTranslator' in locals() or 'OnlineTranslator' in globals():
    # 动态添加方法到现有类
    def _add_missing_methods():
        """为现有的OnlineTranslator类添加缺失的方法"""
        try:
            # 获取OnlineTranslator类
            translator_class = globals().get('OnlineTranslator') or locals().get('OnlineTranslator')
            if not translator_class:
                return
            
            # 添加get_available_translators方法
            if not hasattr(translator_class, 'get_available_translators'):
                def get_available_translators(self):
                    return get_available_translators()
                translator_class.get_available_translators = get_available_translators
            
            # 添加get_translator_languages方法
            if not hasattr(translator_class, 'get_translator_languages'):
                def get_translator_languages(self, translator_name):
                    try:
                        supported_langs = self.get_supported_languages() if hasattr(self, 'get_supported_languages') else {}
                        return {
                            'source_languages': supported_langs,
                            'target_languages': supported_langs
                        }
                    except:
                        default_langs = {'en': 'English', 'zh': '中文', 'auto': '自动检测'}
                        return {
                            'source_languages': default_langs,
                            'target_languages': default_langs
                        }
                translator_class.get_translator_languages = get_translator_languages
            
            # 添加is_available方法
            if not hasattr(translator_class, 'is_available'):
                def is_available(self):
                    try:
                        return len(getattr(self, 'installed_packages', [])) > 0
                    except:
                        return True
                translator_class.is_available = is_available
            
            logger.info("已为OnlineTranslator类添加缺失的方法")
            
        except Exception as e:
            logger.error(f"添加方法失败: {e}")
    
    # 执行方法添加
    _add_missing_methods()

# 为兼容性创建全局函数
def get_translator_languages(translator_name):
    """获取翻译器支持的语言"""
    try:
        if 'default_translator' in globals() and hasattr(default_translator, 'get_supported_languages'):
            supported_langs = default_translator.get_supported_languages()
        else:
            supported_langs = {'en': 'English', 'zh': '中文', 'auto': '自动检测'}
        
        return {
            'source_languages': supported_langs,
            'target_languages': supported_langs
        }
    except Exception as e:
        logger.error(f"获取翻译器语言失败: {e}")
        default_langs = {'en': 'English', 'zh': '中文', 'auto': '自动检测'}
        return {
            'source_languages': default_langs,
            'target_languages': default_langs
        }

def is_translator_available(translator_name=None):
    """检查翻译器是否可用"""
    try:
        if 'default_translator' in globals() and hasattr(default_translator, 'is_available'):
            return default_translator.is_available()
        return True  # 假设总是可用
    except:
        return True

# 日志记录增强
import logging
logger = logging.getLogger(__name__)
logger.info("online_translator.py 增强完成，已添加主应用兼容方法")

EOF
    
    log_success "online_translator.py 增强完成"
}

# 检查并复制必要的脚本文件  
check_and_copy_scripts() {
    log_info "检查并复制必要的脚本文件..."
    
    # 检查必要文件是否存在
    required_files=("skylark_screen_translator.py" "online_translator.py")
    optional_files=("skylark.png")
    
    missing_required=()
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_required+=("$file")
        fi
    done
    
    if [ ${#missing_required[@]} -gt 0 ]; then
        log_error "缺少必要文件:"
        for file in "${missing_required[@]}"; do
            log_error "  - $file"
        done
        log_error "请确保以下文件在当前目录中:"
        log_error "  - skylark_screen_translator.py (主脚本)"
        log_error "  - online_translator.py (翻译模块)"
        exit 1
    fi
    
    # 增强现有的online_translator.py
    enhance_online_translator
    
    # 检查可选文件
    missing_optional=()
    for file in "${optional_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_optional+=("$file")
        fi
    done
    
    if [ ${#missing_optional[@]} -gt 0 ]; then
        log_warn "缺少可选文件，将创建默认版本:"
        for file in "${missing_optional[@]}"; do
            log_warn "  - $file"
        done
    fi
    
    log_success "脚本文件检查和增强完成"
}

# 修复PIL.ImageGrab问题的启动器
create_fixed_launcher() {
    log_info "创建修复PIL问题的启动器..."
    
    cat > "offline_skylark_launcher.py" <<'EOF'
#!/usr/bin/env python3
"""
Skylark Screen Translator - 离线翻译版启动器
修复PIL.ImageGrab问题，确保argostranslate可用
"""

#!/usr/bin/env python3
import os
import sys
import traceback

# ========== 必要的环境修复 ==========
def fix_pil_imagegrab():
    """修复 Linux 下 PIL.ImageGrab 在 X11 环境下的导入问题"""
    try:
        from PIL import ImageGrab
    except ImportError:
        try:
            import ImageGrab
        except ImportError:
            print("⚠️  PIL.ImageGrab 不可用，请检查 pillow 安装。")

def setup_offline_environment():
    """设置离线翻译运行所需环境变量"""
    app_dir = os.path.dirname(os.path.abspath(__file__))
    internal_dir = os.path.join(app_dir, "_internal")

    # 设置 SSL 证书
    cert_path = os.path.join(internal_dir, "certifi", "cacert.pem")
    if os.path.isfile(cert_path):
        os.environ["SSL_CERT_FILE"] = cert_path

    # 设置 argostranslate 包目录
    argos_dir = os.path.join(internal_dir, "argos_packages")
    if os.path.isdir(argos_dir):
        os.environ["ARGOS_PACKAGES_DIR"] = argos_dir

    # 设置 Qt 平台插件目录
    qt_plugins = os.path.join(internal_dir, "PyQt5", "Qt5", "plugins")
    if os.path.isdir(qt_plugins):
        os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = qt_plugins
        os.environ["QT_QPA_PLATFORM"] = "xcb"

# ========== 启动主程序 ==========
def main():
    try:
        fix_pil_imagegrab()
        setup_offline_environment()

        # 启动主应用
        app_dir = os.path.dirname(os.path.abspath(__file__))
        main_script = os.path.join(app_dir, "skylark_screen_translator.py")
        if not os.path.isfile(main_script):
            print(f"❌ 找不到主程序: {main_script}")
            sys.exit(1)

        with open(main_script, "rb") as f:
            code = compile(f.read(), main_script, "exec")
            exec(code, globals(), globals())

    except Exception:
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    log_success "离线翻译启动器创建完成"
}

# 创建离线翻译spec文件
create_offline_spec() {
    log_info "创建离线翻译spec文件..."
    
    cat > "offline_skylark.spec" <<EOF
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

# 离线翻译完整隐藏导入
hiddenimports = [
    # PyQt5
    'PyQt5.QtCore',
    'PyQt5.QtGui', 
    'PyQt5.QtWidgets',
    'PyQt5.sip',
    'sip',
    
    # 图像处理（完整版）
    'PIL',
    'PIL.Image',
    'PIL.ImageGrab',
    'PIL.ImageTk',
    'cv2',
    'numpy',
    'numpy.core._methods',
    'numpy.lib.format',
    
    # OCR和屏幕
    'pytesseract',
    'mss',
    'mss.linux',
    'pynput',
    'pynput.keyboard',
    'pynput.mouse',
    'pynput.keyboard._xorg',
    'pynput.mouse._xorg',
    'screeninfo',
    
    # 网络
    'requests',
    'requests.packages.urllib3',
    'certifi',
    
    # 离线翻译核心
    'argostranslate',
    'argostranslate.package',
    'argostranslate.translate',
    'argostranslate.settings',
    'argostranslate.utils',
    
    # 翻译依赖
    'stanza',
    'ctranslate2',
    'sentencepiece',
    'torch',
    
    # 自定义模块
    'online_translator',
    
    # 标准库
    'json',
    'hashlib',
    'uuid',
    'pkg_resources.py2_warn',
]

# 数据文件
datas = [
    ('skylark_screen_translator.py', '.'),
    ('online_translator.py', '.'),
]

# 图标文件（如果存在）
try:
    import os
    if os.path.exists('skylark.png'):
        datas.append(('skylark.png', '.'))
except:
    pass

# SSL证书
try:
    import certifi
    datas.append((certifi.where(), 'certifi'))
except:
    pass

# argostranslate数据（从临时目录）
try:
    import argostranslate
    import os
    argos_path = os.path.dirname(argostranslate.__file__)
    datas.append((argos_path, 'argostranslate'))
    
    # 语言包目录（从环境变量获取）
    argos_packages_dir = os.environ.get('ARGOS_PACKAGES_DIR')
    if argos_packages_dir and os.path.exists(argos_packages_dir):
        datas.append((argos_packages_dir, 'argos_packages'))
        print(f"包含argos包目录: {argos_packages_dir}")
        
except Exception as e:
    print(f"Warning: Could not include argostranslate data: {e}")

a = Analysis(
    ['offline_skylark_launcher.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'matplotlib',
        'scipy', 
        'pandas',
        'jupyter',
        'PyQt5.QtWebEngine',
        'PyQt5.QtWebEngineWidgets',
        'tensorflow',
        'keras',
        'ttkthemes',  # 排除ttkthemes避免tkinter问题
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Skylark_Online_Translation',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='Skylark_Online_Translation',
)
EOF

    log_success "离线翻译spec文件创建完成"
}

# 构建离线版本
build_offline_version() {
    log_info "构建离线翻译版本..."
    
    source "$VENV_DIR/bin/activate"
    
    create_offline_spec
    
    # 确保argos包目录环境变量可用
    export ARGOS_PACKAGES_DIR="$LARGE_TEMP_DIR/argos_packages"
    
    if pyinstaller offline_skylark.spec --clean --noconfirm; then
        log_success "离线版本构建成功"
        return 0
    else
        log_error "构建失败"
        return 1
    fi
}

# 创建离线AppDir
create_offline_appdir() {
    log_info "创建离线翻译AppDir..."
    
    rm -rf AppDir 2>/dev/null || true
    mkdir -p AppDir/usr/{bin,share/{applications,icons/hicolor/256x256/apps}}
    
    # 复制应用
    if [ -d "dist/Skylark_Online_Translation" ]; then
        cp -r dist/Skylark_Online_Translation/* AppDir/usr/bin/
        log_success "应用文件复制成功"
    else
        log_error "找不到构建的应用文件"
        return 1
    fi
    
    # 复制原始脚本和依赖模块
    for script in skylark_screen_translator.py online_translator.py; do
        if [ -f "$script" ]; then
            cp "$script" AppDir/usr/bin/
            log_info "已复制: $script"
        else
            log_warn "找不到: $script"
        fi
    done
    
    # 创建图标
    if [ -f "skylark.png" ]; then
        cp skylark.png AppDir/usr/share/icons/hicolor/256x256/apps/skylark-translation.png
    else
        log_info "创建默认图标..."
        python3 -c "
try:
    from PIL import Image
    img = Image.new('RGB', (256, 256), (30, 144, 255))
    img.save('AppDir/usr/share/icons/hicolor/256x256/apps/skylark-translation.png')
    print('图标创建成功')
except Exception as e:
    print(f'图标创建失败: {e}')
    # 创建一个简单的占位符
    import os
    os.system('touch AppDir/usr/share/icons/hicolor/256x256/apps/skylark-translation.png')
"
    fi
    
    # 创建图标符号链接
    ln -sf usr/share/icons/hicolor/256x256/apps/skylark-translation.png AppDir/skylark-translation.png
    
    # Desktop文件
    cat > AppDir/skylark-translation.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Skylark Translation (Offline)
Comment=Screen translator with offline argostranslate
Exec=Skylark_Online_Translation
Icon=skylark-translation
Terminal=false
Categories=Utility;Accessibility;
Keywords=translate;translation;OCR;offline;argostranslate;
StartupNotify=true
EOF
    
    cp AppDir/skylark-translation.desktop AppDir/usr/share/applications/
    
    # AppRun启动脚本
    cat > AppDir/AppRun <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"

export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin:${LD_LIBRARY_PATH}"
export PATH="${HERE}/usr/bin:${PATH}"
export PYTHONPATH="${HERE}/usr/bin:${HERE}/usr/bin/_internal:${PYTHONPATH}"

# Qt环境
if [ -n "$DISPLAY" ]; then
    export QT_QPA_PLATFORM="xcb"
else
    export QT_QPA_PLATFORM="minimal"
fi

export QT_AUTO_SCREEN_SCALE_FACTOR=0

# Qt插件
for plugin_dir in "${HERE}/usr/bin/_internal/PyQt5/Qt5/plugins" "${HERE}/usr/bin/_internal/PyQt5/Qt/plugins"; do
    if [ -d "$plugin_dir" ]; then
        export QT_QPA_PLATFORM_PLUGIN_PATH="$plugin_dir"
        export QT_PLUGIN_PATH="$plugin_dir"
        break
    fi
done

# SSL证书
for cert_file in "${HERE}/usr/bin/_internal/certifi/cacert.pem" "${HERE}/usr/bin/certifi/cacert.pem"; do
    if [ -f "$cert_file" ]; then
        export SSL_CERT_FILE="$cert_file"
        export REQUESTS_CA_BUNDLE="$cert_file"
        break
    fi
done

# argostranslate包目录
if [ -d "${HERE}/usr/bin/_internal/argos_packages" ]; then
    export ARGOS_PACKAGES_DIR="${HERE}/usr/bin/_internal/argos_packages"
fi

# 清理冲突
unset LD_PRELOAD

cd "${HERE}/usr/bin"
exec ./Skylark_Online_Translation "$@"
EOF
    chmod +x AppDir/AppRun
    
    log_success "离线翻译AppDir创建完成"
}

# 清理构建临时文件
cleanup_build_temp() {
    log_info "清理构建临时文件..."
    
    # 询问是否清理大容量临时目录
    echo ""
    read -p "是否清理大容量临时目录 ($LARGE_TEMP_DIR) 以释放空间? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理临时目录..."
        rm -rf "$LARGE_TEMP_DIR" 2>/dev/null || true
        
        # 显示释放的空间
        available_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
        log_info "当前可用空间: ${available_space}GB"
        log_success "临时目录已清理"
    else
        log_info "保留临时目录: $LARGE_TEMP_DIR"
        log_info "如需手动清理: rm -rf '$LARGE_TEMP_DIR'"
    fi
}

# 主函数
main() {
    log_info "=== 离线翻译专用 AppImage 构建开始 ==="
    
    # 检查并复制必要文件
    check_and_copy_scripts
    
    # 设置大容量临时目录
    setup_large_temp_dir
    
    # 清理磁盘空间
    cleanup_disk_space
    
    # 安装系统依赖（修复版）
    install_system_deps
    
    # 创建虚拟环境（修复版）
    create_optimized_venv
    
    # 安装argostranslate
    if ! install_argostranslate; then
        log_error "argostranslate安装失败，无法继续"
        cleanup_build_temp
        exit 1
    fi
    
    # 下载语言包
    download_language_packages
    
    # 创建修复的启动器
    create_fixed_launcher
    
    # 构建应用
    if ! build_offline_version; then
        log_error "应用构建失败"
        cleanup_build_temp
        exit 1
    fi
    
    # 创建AppDir
    if ! create_offline_appdir; then
        log_error "AppDir创建失败"
        cleanup_build_temp
        exit 1
    fi
    
    # 下载appimagetool
    if [ ! -f appimagetool ]; then
        log_info "下载appimagetool..."
        if wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool; then
            chmod +x appimagetool
        else
            log_error "appimagetool下载失败"
            cleanup_build_temp
            exit 1
        fi
    fi
    
    # 创建最终AppImage
    log_info "创建离线翻译AppImage..."
    export ARCH=x86_64
    
    if ./appimagetool --no-appstream AppDir Skylark_Online_Translation.AppImage 2>/dev/null; then
        log_success "离线翻译AppImage创建成功！"
        chmod +x Skylark_Online_Translation.AppImage
        
        # 显示文件信息
        if [ -f "Skylark_Online_Translation.AppImage" ]; then
            ls -lh Skylark_Online_Translation.AppImage
            
            echo ""
            log_success "=== 离线翻译版构建完成 ==="
            log_info "文件: Skylark_Online_Translation.AppImage"
            log_info "特点: 完整离线翻译支持，修复PIL.ImageGrab问题，包含online_translator模块"
            
            echo ""
            log_info "🎯 使用方法:"
            log_info "  ./Skylark_Online_Translation.AppImage"
            
            echo ""
            log_info "📦 包含的翻译功能:"
            log_info "  - argostranslate离线翻译引擎（CPU版本）"
            log_info "  - 预装翻译包（如果下载成功）"
            log_info "  - 兼容online_translator模块接口"
            log_info "  - 支持多语言翻译"
            log_info "  - 无需网络连接即可翻译"
            
            echo ""
            log_info "🔧 故障排除:"
            log_info "  - 如果Qt有问题: QT_QPA_PLATFORM=xcb ./Skylark_Online_Translation.AppImage"
            log_info "  - 如果翻译不工作，检查语言包是否正确安装"
            log_info "  - 如果需要更多语言包，可以在应用内下载"
            log_info "  - 缺少模块错误已通过创建兼容模块解决"
            
            # 快速验证
            log_info ""
            log_info "🔍 快速验证应用启动..."
            
            # 后台启动应用进行测试
            timeout 5s ./Skylark_Online_Translation.AppImage --version 2>/dev/null || {
                log_info "应用需要图形界面，请手动测试"
            }
            
            log_success "✅ 构建完成！文件已就绪"
            
        else
            log_error "AppImage文件未正确创建"
            cleanup_build_temp
            exit 1
        fi
        
    else
        log_error "AppImage创建失败"
        log_info "请检查构建日志以获取详细信息"
        cleanup_build_temp
        exit 1
    fi
}

# 执行主函数
main "$@"

# 构建后清理
cleanup_build_temp

log_success "离线翻译版AppImage构建脚本执行完成！"
