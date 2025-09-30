import os
import importlib.util
import sys
from pathlib import Path
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QGroupBox
from PyQt5.QtCore import Qt

class PluginManager:
    """真正的即插即用插件管理器 - 主程序完全不知道插件内容"""
    
    def __init__(self, main_window):
        self.main_window = main_window
        self.plugins = {}
        self.loaded_plugins = {}
        
    def discover_plugins(self):
        """发现并加载所有可用插件"""
        plugin_dir = Path(__file__).parent
        print(f"🔍 在目录中搜索插件: {plugin_dir}")
        
        # 查找所有 EXT*.py 文件
        plugin_files = list(plugin_dir.glob("EXT*.py"))
        print(f"找到 {len(plugin_files)} 个插件文件: {[f.name for f in plugin_files]}")
        
        for plugin_file in plugin_files:
            plugin_name = plugin_file.stem
            print(f"正在加载插件: {plugin_name}")
            
            try:
                success = self.load_plugin(plugin_name, plugin_file)
                if success:
                    print(f"✅ 插件 {plugin_name} 加载成功")
                else:
                    print(f"⚠️ 插件 {plugin_name} 加载失败")
            except Exception as e:
                print(f"❌ 加载插件 {plugin_name} 时出错: {e}")
    
    def load_plugin(self, plugin_name, plugin_file):
        """动态加载单个插件"""
        try:
            # 动态导入插件模块
            spec = importlib.util.spec_from_file_location(plugin_name, plugin_file)
            if spec is None:
                print(f"无法创建插件 {plugin_name} 的规范")
                return False
                
            plugin_module = importlib.util.module_from_spec(spec)
            sys.modules[plugin_name] = plugin_module
            spec.loader.exec_module(plugin_module)
            
            # 检查插件是否有必需的注册函数
            if not hasattr(plugin_module, 'register_plugin'):
                print(f"插件 {plugin_name} 缺少 register_plugin 函数")
                return False
                
            if not hasattr(plugin_module, 'create_tab'):
                print(f"插件 {plugin_name} 缺少 create_tab 函数")
                return False
            
            # 注册插件
            plugin_info = plugin_module.register_plugin()
            self.plugins[plugin_name] = plugin_info
            self.loaded_plugins[plugin_name] = plugin_module
            
            print(f"✅ 插件 {plugin_name} 注册成功: {plugin_info.get('name', '未知')}")
            return True
                
        except Exception as e:
            print(f"❌ 加载插件 {plugin_name} 失败: {e}")
            return False
    
    def get_plugin_tabs(self, parent_dialog):
        """获取所有插件的标签页"""
        tabs = []
        for plugin_name, plugin_module in self.loaded_plugins.items():
            try:
                tab_widget, tab_name = plugin_module.create_tab(parent_dialog, self.main_window)
                if tab_widget and tab_name:
                    tabs.append((tab_widget, tab_name))
                    print(f"✅ 创建插件标签页: {tab_name}")
                else:
                    print(f"⚠️ 插件 {plugin_name} 返回了无效的标签页")
            except Exception as e:
                print(f"❌ 创建插件 {plugin_name} 标签页失败: {e}")
        
        print(f"总共创建了 {len(tabs)} 个插件标签页")
        return tabs
    
    def is_plugin_available(self, plugin_name):
        """检查插件是否可用"""
        return plugin_name in self.loaded_plugins
    
    def get_plugin_info(self, plugin_name):
        """获取插件信息"""
        if plugin_name in self.plugins:
            return self.plugins[plugin_name]
        return None
    
    def get_loaded_plugins_count(self):
        """获取已加载插件数量"""
        return len(self.loaded_plugins)


class DefaultPluginTab(QWidget):
    """默认插件标签页 - 当插件加载失败时使用"""
    
    def __init__(self, plugin_name, parent=None):
        super().__init__(parent)
        self.plugin_name = plugin_name
        self.setup_ui()
    
    def setup_ui(self):
        layout = QVBoxLayout()
        
        info_group = QGroupBox("插件状态")
        info_layout = QVBoxLayout()
        
        info_label = QLabel(
            f"插件 {self.plugin_name} 加载失败或不可用。\n\n"
            "要使用此功能，请确保相应的插件文件位于应用程序同一目录下。"
        )
        info_label.setWordWrap(True)
        info_label.setStyleSheet("color: #666; padding: 20px;")
        info_label.setAlignment(Qt.AlignCenter)
        
        info_layout.addWidget(info_label)
        info_group.setLayout(info_layout)
        layout.addWidget(info_group)
        
        self.setLayout(layout)


# 插件接口标准说明
"""
插件开发标准:

每个插件文件必须包含以下两个函数:

1. register_plugin() -> dict
   返回插件信息字典，包含:
   - name: 插件名称
   - version: 版本号  
   - description: 描述
   - author: 作者

2. create_tab(parent_dialog, main_window) -> (QWidget, str)
   返回: (标签页控件, 标签页显示名称)

示例:

def register_plugin():
    return {
        'name': '我的插件',
        'version': '1.0',
        'description': '插件功能描述',
        'author': '作者名'
    }

def create_tab(parent_dialog, main_window):
    tab = MyPluginTab(parent_dialog, main_window)
    return tab, "插件标签页"
"""