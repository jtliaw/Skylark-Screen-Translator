import requests
import threading
import time
import json
import os
from datetime import datetime, timedelta
from PyQt5.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, 
    QTableWidget, QTableWidgetItem, QCheckBox, QSpinBox,
    QGroupBox, QTextEdit, QMessageBox, QProgressBar, QComboBox,
    QLineEdit, QTabWidget, QWidget
)
from PyQt5.QtCore import QTimer, pyqtSignal, QThread
from PyQt5.QtGui import QColor

class GoogleAPIEndpointMonitor(QThread):
    """Google翻译API端点监控和自动切换系统"""
    
    endpoint_status_updated = pyqtSignal(str, bool, str, float)  # url, is_working, message, response_time
    api_switched = pyqtSignal(str, str)  # old_url, new_url
    
    def __init__(self):
        super().__init__()
        
        # Google翻译的各种可用API端点
        self.google_endpoints = [
            # 官方和镜像站点
            "https://translate.googleapis.com/translate_a/single",
            "https://translate.google.com/translate_a/single", 
            "https://translate.google.cn/translate_a/single",
            
            # 常用的镜像API
            "https://clients5.google.com/translate_a/single",
            "https://translate-pa.googleapis.com/translate_a/single",
            
            # 备用镜像（经常可用）
            "https://translate.google.com.hk/translate_a/single",
            "https://translate.google.com.tw/translate_a/single",
            "https://translate.google.com.sg/translate_a/single",
            
            # 第三方可靠的Google翻译代理
            "https://translate.mentality.rip/translate_a/single",
            "https://translate.fortunes.tech/translate_a/single",
        ]
        
        # DeepL的备用端点
        self.deepl_endpoints = [
            "https://api-free.deepl.com/v2/translate",
            "https://api.deepl.com/v2/translate",
        ]
        
        # 百度翻译的备用端点
        self.baidu_endpoints = [
            "https://fanyi-api.baidu.com/api/trans/vip/translate",
            "https://aip.baidubce.com/rest/2.0/mt/texttrans/v1",
        ]
        
        self.current_endpoints = {
            'google': self.google_endpoints[0],
            'deepl': self.deepl_endpoints[0], 
            'baidu': self.baidu_endpoints[0]
        }
        
        self.endpoint_status = {}  # 存储每个端点的状态
        self.is_monitoring = False
        self.check_interval = 300  # 5分钟检查一次
        self.auto_switch_enabled = True
        
    def test_google_endpoint(self, endpoint_url):
        """测试Google翻译端点是否可用"""
        try:
            # 构建测试请求参数
            params = {
                'client': 'gtx',
                'sl': 'en',
                'tl': 'zh',
                'dt': 't',
                'q': 'hello'
            }
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            start_time = time.time()
            response = requests.get(endpoint_url, params=params, headers=headers, timeout=10)
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                # 检查返回内容是否包含翻译结果
                try:
                    result = response.json()
                    if result and len(result) > 0 and len(result[0]) > 0:
                        translated = result[0][0][0]
                        if translated and '你好' in translated:
                            return True, f"正常 ({response_time:.2f}s)", response_time
                        else:
                            return False, "返回结果异常", response_time
                    else:
                        return False, "返回格式错误", response_time
                except:
                    return False, "JSON解析失败", response_time
            else:
                return False, f"HTTP {response.status_code}", response_time
                
        except requests.exceptions.Timeout:
            return False, "请求超时", 10.0
        except requests.exceptions.ConnectionError:
            return False, "连接失败", 0.0
        except Exception as e:
            return False, str(e), 0.0
    
    def test_deepl_endpoint(self, endpoint_url):
        """测试DeepL端点（需要API密钥）"""
        # 这里可以添加DeepL API测试逻辑
        return False, "需要API密钥", 0.0
    
    def test_baidu_endpoint(self, endpoint_url):
        """测试百度翻译端点（需要APP ID和密钥）"""
        # 这里可以添加百度翻译API测试逻辑
        return False, "需要API密钥", 0.0
    
    def find_best_google_endpoint(self):
        """寻找最佳的Google翻译端点"""
        best_endpoint = None
        best_time = float('inf')
        
        for endpoint in self.google_endpoints:
            is_working, message, response_time = self.test_google_endpoint(endpoint)
            self.endpoint_status_updated.emit(endpoint, is_working, message, response_time)
            
            if is_working and response_time < best_time:
                best_endpoint = endpoint
                best_time = response_time
                
            time.sleep(1)  # 避免请求过于频繁
        
        return best_endpoint, best_time
    
    def start_monitoring(self):
        """开始监控"""
        self.is_monitoring = True
        self.start()
    
    def stop_monitoring(self):
        """停止监控"""
        self.is_monitoring = False
        self.wait()
    
    def run(self):
        """监控主循环"""
        while self.is_monitoring:
            # 检查当前使用的Google端点
            current_google = self.current_endpoints['google']
            is_working, message, response_time = self.test_google_endpoint(current_google)
            
            self.endpoint_status_updated.emit(current_google, is_working, message, response_time)
            
            if not is_working and self.auto_switch_enabled:
                # 当前端点失效，寻找替代的
                print(f"当前Google翻译端点失效: {current_google}")
                best_endpoint, best_time = self.find_best_google_endpoint()
                
                if best_endpoint and best_endpoint != current_google:
                    old_endpoint = self.current_endpoints['google']
                    self.current_endpoints['google'] = best_endpoint
                    self.api_switched.emit(old_endpoint, best_endpoint)
                    print(f"已切换到新的Google翻译端点: {best_endpoint}")
            
            # 等待下次检查
            for _ in range(self.check_interval):
                if not self.is_monitoring:
                    break
                time.sleep(1)

class GoogleAPIManager:
    """Google翻译API管理器"""
    
    def __init__(self):
        self.monitor = GoogleAPIEndpointMonitor()
        self.current_google_url = self.monitor.current_endpoints['google']
    
    def get_current_google_endpoint(self):
        """获取当前Google翻译端点"""
        return self.monitor.current_endpoints['google']
    
    def set_google_endpoint(self, endpoint_url):
        """设置Google翻译端点"""
        self.monitor.current_endpoints['google'] = endpoint_url
        self.current_google_url = endpoint_url
    
    def translate_with_google(self, text, from_lang='auto', to_lang='zh'):
        """使用当前Google端点进行翻译"""
        endpoint = self.get_current_google_endpoint()
        
        try:
            params = {
                'client': 'gtx',
                'sl': from_lang,
                'tl': to_lang,
                'dt': 't',
                'q': text
            }
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            
            response = requests.get(endpoint, params=params, headers=headers, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                if result and len(result) > 0 and len(result[0]) > 0:
                    return result[0][0][0]
            
            return None
            
        except Exception as e:
            print(f"翻译请求失败: {e}")
            return None

class APIEndpointDialog(QDialog):
    """API端点管理对话框"""
    
    def __init__(self, screen_translator):
        super().__init__()
        self.screen_translator = screen_translator
        self.api_manager = GoogleAPIManager()
        self.init_ui()
        self.setup_connections()
        
    def init_ui(self):
        self.setWindowTitle("翻译API端点管理")
        self.setFixedSize(700, 700)
        
        layout = QVBoxLayout(self)
        
        # 创建选项卡
        tab_widget = QTabWidget()
        
        # Google翻译选项卡
        google_tab = self.create_google_tab()
        tab_widget.addTab(google_tab, "Google翻译端点")
        
        
        layout.addWidget(tab_widget)
        
    def create_google_tab(self):
        """创建Google翻译选项卡"""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        
        # 当前使用的端点
        current_group = QGroupBox("当前使用的Google翻译端点")
        current_layout = QVBoxLayout()
        
        self.current_endpoint_label = QLabel(self.api_manager.get_current_google_endpoint())
        self.current_endpoint_label.setStyleSheet("font-weight: bold; color: green;")
        current_layout.addWidget(self.current_endpoint_label)
        
        # 测试当前端点按钮
        test_current_btn = QPushButton("测试当前端点")
        test_current_btn.clicked.connect(self.test_current_endpoint)
        current_layout.addWidget(test_current_btn)
        
        current_group.setLayout(current_layout)
        layout.addWidget(current_group)
        
        # 监控设置
        monitor_group = QGroupBox("自动监控设置")
        monitor_layout = QVBoxLayout()
        
        # 启用监控
        monitor_control_layout = QHBoxLayout()
        self.monitor_checkbox = QCheckBox("启用API端点监控")
        self.monitor_checkbox.setChecked(True)
        monitor_control_layout.addWidget(self.monitor_checkbox)
        
        monitor_control_layout.addWidget(QLabel("检查间隔:"))
        self.interval_spinbox = QSpinBox()
        self.interval_spinbox.setRange(60, 3600)
        self.interval_spinbox.setValue(300)
        self.interval_spinbox.setSuffix(" 秒")
        monitor_control_layout.addWidget(self.interval_spinbox)
        
        monitor_layout.addLayout(monitor_control_layout)
        
        # 自动切换
        auto_switch_layout = QHBoxLayout()
        self.auto_switch_checkbox = QCheckBox("启用自动切换到最佳端点")
        self.auto_switch_checkbox.setChecked(True)
        auto_switch_layout.addWidget(self.auto_switch_checkbox)
        monitor_layout.addLayout(auto_switch_layout)
        
        # 控制按钮
        control_layout = QHBoxLayout()
        self.start_monitor_btn = QPushButton("开始监控")
        self.start_monitor_btn.clicked.connect(self.start_monitoring)
        control_layout.addWidget(self.start_monitor_btn)
        
        self.stop_monitor_btn = QPushButton("停止监控")
        self.stop_monitor_btn.clicked.connect(self.stop_monitoring)
        self.stop_monitor_btn.setEnabled(False)
        control_layout.addWidget(self.stop_monitor_btn)
        
        self.find_best_btn = QPushButton("查找最佳端点")
        self.find_best_btn.clicked.connect(self.find_best_endpoint)
        control_layout.addWidget(self.find_best_btn)
        
        monitor_layout.addLayout(control_layout)
        monitor_group.setLayout(monitor_layout)
        layout.addWidget(monitor_group)
        
        # 所有端点状态表
        endpoints_group = QGroupBox("所有Google翻译端点状态")
        endpoints_layout = QVBoxLayout()
        
        self.endpoints_table = QTableWidget()
        self.endpoints_table.setColumnCount(4)
        self.endpoints_table.setHorizontalHeaderLabels([
            "端点地址", "状态", "响应时间", "操作"
        ])
        self.endpoints_table.setAlternatingRowColors(True)
        
        # 填充端点表格
        self.update_endpoints_table()
        
        endpoints_layout.addWidget(self.endpoints_table)
        endpoints_group.setLayout(endpoints_layout)
        layout.addWidget(endpoints_group)
        
        # 自定义端点
        custom_group = QGroupBox("添加自定义端点")
        custom_layout = QHBoxLayout()
        
        self.custom_endpoint_input = QLineEdit()
        self.custom_endpoint_input.setPlaceholderText("输入自定义的Google翻译API端点...")
        custom_layout.addWidget(self.custom_endpoint_input)
        
        add_custom_btn = QPushButton("添加")
        add_custom_btn.clicked.connect(self.add_custom_endpoint)
        custom_layout.addWidget(add_custom_btn)
        
        custom_group.setLayout(custom_layout)
        layout.addWidget(custom_group)
        
        # 日志区域
        log_group = QGroupBox("监控日志")
        log_layout = QVBoxLayout()
        
        self.log_text = QTextEdit()
        self.log_text.setMaximumHeight(120)
        self.log_text.setReadOnly(True)
        log_layout.addWidget(self.log_text)
        
        log_group.setLayout(log_layout)
        layout.addWidget(log_group)
        
        return tab
    
    
    def update_endpoints_table(self):
        """更新端点状态表格"""
        endpoints = self.api_manager.monitor.google_endpoints
        self.endpoints_table.setRowCount(len(endpoints))
        
        for i, endpoint in enumerate(endpoints):
            # 端点地址
            url_item = QTableWidgetItem(endpoint)
            self.endpoints_table.setItem(i, 0, url_item)
            
            # 状态
            status_item = QTableWidgetItem("未测试")
            self.endpoints_table.setItem(i, 1, status_item)
            
            # 响应时间
            time_item = QTableWidgetItem("-")
            self.endpoints_table.setItem(i, 2, time_item)
            
            # 操作按钮
            use_btn = QPushButton("使用此端点")
            use_btn.clicked.connect(lambda checked, url=endpoint: self.use_endpoint(url))
            self.endpoints_table.setCellWidget(i, 3, use_btn)
    
    def setup_connections(self):
        """设置信号连接"""
        self.api_manager.monitor.endpoint_status_updated.connect(self.on_endpoint_status_updated)
        self.api_manager.monitor.api_switched.connect(self.on_api_switched)
    
    def test_current_endpoint(self):
        """测试当前端点"""
        current_endpoint = self.api_manager.get_current_google_endpoint()
        self.add_log(f"正在测试当前端点: {current_endpoint}")
        
        is_working, message, response_time = self.api_manager.monitor.test_google_endpoint(current_endpoint)
        
        if is_working:
            self.add_log(f"✅ 当前端点正常: {message}")
        else:
            self.add_log(f"❌ 当前端点异常: {message}")
    
    def start_monitoring(self):
        """开始监控"""
        self.api_manager.monitor.check_interval = self.interval_spinbox.value()
        self.api_manager.monitor.auto_switch_enabled = self.auto_switch_checkbox.isChecked()
        
        self.api_manager.monitor.start_monitoring()
        self.start_monitor_btn.setEnabled(False)
        self.stop_monitor_btn.setEnabled(True)
        self.add_log("✅ API端点监控已启动")
    
    def stop_monitoring(self):
        """停止监控"""
        self.api_manager.monitor.stop_monitoring()
        self.start_monitor_btn.setEnabled(True)
        self.stop_monitor_btn.setEnabled(False)
        self.add_log("⏹️ API端点监控已停止")
    
    def find_best_endpoint(self):
        """查找最佳端点"""
        self.add_log("🔍 正在查找最佳Google翻译端点...")
        
        def find_in_thread():
            best_endpoint, best_time = self.api_manager.monitor.find_best_google_endpoint()
            if best_endpoint:
                self.api_manager.set_google_endpoint(best_endpoint)
                self.current_endpoint_label.setText(best_endpoint)
                self.add_log(f"✅ 已切换到最佳端点: {best_endpoint} ({best_time:.2f}s)")
            else:
                self.add_log("❌ 未找到可用的端点")
        
        threading.Thread(target=find_in_thread, daemon=True).start()
    
    def use_endpoint(self, endpoint_url):
        """使用指定端点"""
        self.api_manager.set_google_endpoint(endpoint_url)
        self.current_endpoint_label.setText(endpoint_url)
        self.add_log(f"已手动切换到端点: {endpoint_url}")
        
        # 更新主程序的翻译器
        if hasattr(self.screen_translator, 'online_translator'):
            # 这里需要根据您的OnlineTranslator实现来更新Google翻译的端点
            pass
    
    def add_custom_endpoint(self):
        """添加自定义端点"""
        custom_url = self.custom_endpoint_input.text().strip()
        if custom_url:
            if custom_url not in self.api_manager.monitor.google_endpoints:
                self.api_manager.monitor.google_endpoints.append(custom_url)
                self.update_endpoints_table()
                self.add_log(f"已添加自定义端点: {custom_url}")
                self.custom_endpoint_input.clear()
            else:
                QMessageBox.information(self, "提示", "该端点已存在")
    
    def on_endpoint_status_updated(self, url, is_working, message, response_time):
        """端点状态更新处理"""
        # 更新表格中的状态
        for i in range(self.endpoints_table.rowCount()):
            url_item = self.endpoints_table.item(i, 0)
            if url_item and url_item.text() == url:
                # 更新状态
                status_text = "✅ 正常" if is_working else f"❌ {message}"
                status_item = self.endpoints_table.item(i, 1)
                status_item.setText(status_text)
                
                # 设置颜色
                if is_working:
                    status_item.setBackground(QColor(200, 255, 200))
                else:
                    status_item.setBackground(QColor(255, 200, 200))
                
                # 更新响应时间
                time_text = f"{response_time:.2f}s" if response_time > 0 else "-"
                time_item = self.endpoints_table.item(i, 2)
                time_item.setText(time_text)
                break
    
    def on_api_switched(self, old_url, new_url):
        """API切换处理"""
        self.current_endpoint_label.setText(new_url)
        self.add_log(f"🔄 自动切换: {old_url} → {new_url}")
        
        # 显示通知
        QMessageBox.information(
            self, "API自动切换", 
            f"检测到当前端点失效，已自动切换到：\n{new_url}"
        )
    
    def add_log(self, message):
        """添加日志"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        self.log_text.append(log_entry)
        
        # 自动滚动到底部
        scrollbar = self.log_text.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())

# 需要添加到ScreenTranslator类中的方法
def add_endpoint_management_to_screen_translator():
    """需要添加到ScreenTranslator类中的代码"""
    
    def open_endpoint_manager(self):
        """打开端点管理对话框"""
        if not hasattr(self, 'endpoint_dialog') or not self.endpoint_dialog:
            self.endpoint_dialog = APIEndpointDialog(self)
        
        self.endpoint_dialog.show()
        self.endpoint_dialog.raise_()
        self.endpoint_dialog.activateWindow()
    
    # 在init_ui方法的按钮区域添加：
    # self.endpoint_manager_btn = QPushButton("API端点管理")
    # self.endpoint_manager_btn.clicked.connect(self.open_endpoint_manager)
    # control_layout.addWidget(self.endpoint_manager_btn)