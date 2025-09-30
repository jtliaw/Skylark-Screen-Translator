import requests
import json
import hashlib
import random
import time
from urllib.parse import quote
import urllib.request
import urllib.parse
import re

class BaseTranslator:
    """翻译器基类，提供通用的语言处理功能"""
    
    def __init__(self):
        # 基础语言映射（通用语言代码 -> 各API特定代码）
        self.base_lang_map = {
            # 亚洲语言
            'zh': 'zh', 'zh-CN': 'zh', 'zh-TW': 'zh', 'zh-Hans': 'zh', 'zh-Hant': 'zh',
            'ja': 'ja', 'ko': 'ko', 'ms': 'ms', 'th': 'th', 'vi': 'vi',
            'hi': 'hi', 'bn': 'bn', 'ta': 'ta', 'te': 'te', 'ur': 'ur',
            'ar': 'ar', 'fa': 'fa', 'he': 'he', 'tr': 'tr',
            
            # 欧洲语言
            'en': 'en', 'fr': 'fr', 'de': 'de', 'it': 'it', 'es': 'es',
            'pt': 'pt', 'pt-BR': 'pt', 'ru': 'ru', 'nl': 'nl', 'pl': 'pl',
            'uk': 'uk', 'ro': 'ro', 'hu': 'hu', 'sv': 'sv', 'cs': 'cs',
            'da': 'da', 'fi': 'fi', 'no': 'no', 'sk': 'sk', 'sl': 'sl',
            'bg': 'bg', 'hr': 'hr', 'sr': 'sr', 'el': 'el', 'ca': 'ca',
            'et': 'et', 'lv': 'lv', 'lt': 'lt',
            
            # 其他语言
            'af': 'af', 'sw': 'sw', 'id': 'id', 'tl': 'tl', 'eo': 'eo',
            'la': 'la', 'is': 'is', 'ga': 'ga', 'mk': 'mk', 'sq': 'sq'
        }
        
        # API特定的语言映射（子类可以覆盖）
        self.api_lang_map = {}
        
        # 创建session
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        })
    
    def map_language(self, lang_code):
        """将通用语言代码映射到API特定代码"""
        # 先尝试基础映射
        base_mapped = self.base_lang_map.get(lang_code, lang_code)
        # 再尝试API特定映射
        return self.api_lang_map.get(base_mapped, base_mapped)
    
    def get_supported_languages(self):
        """获取支持的语言列表（子类应该覆盖此方法）"""
        return list(set(self.api_lang_map.values()))
    
    def is_language_supported(self, lang_code):
        """检查语言是否支持"""
        mapped_code = self.map_language(lang_code)
        supported = self.get_supported_languages()
        return mapped_code in supported if supported else True  # 如果未定义支持列表，则假定支持


class OnlineTranslator:
    """在线翻译引擎管理类"""
    
    def __init__(self):
        self.translators = {
            'libretranslate': LibreTranslateTranslator(),
            'mymemory': MyMemoryTranslator(),
            'google': GoogleTranslator(),
            'deepl': DeepLTranslator(),
            'baidu': BaiduTranslator(),
            'microsoft': MicrosoftTranslator()
        }
        self.current_translator = 'libretranslate'  # 默认使用LibreTranslate
    
    def set_translator(self, translator_name):
        """设置当前翻译引擎"""
        if translator_name in self.translators:
            self.current_translator = translator_name
            return True
        return False
    
    def get_available_translators(self):
        """获取可用的翻译引擎列表"""
        return list(self.translators.keys())
    
    def get_supported_languages(self, translator_name=None):
        """获取支持的语言列表"""
        if translator_name:
            if translator_name in self.translators:
                return self.translators[translator_name].get_supported_languages()
            return []
        
        # 返回所有翻译器共同支持的语言
        common_languages = set()
        for name, translator in self.translators.items():
            translator_langs = translator.get_supported_languages()
            if translator_langs:  # 只处理有明确支持列表的翻译器
                if not common_languages:
                    common_languages = set(translator_langs)
                else:
                    common_languages &= set(translator_langs)
        
        return list(common_languages) if common_languages else []
    
    def is_language_supported(self, from_lang, to_lang, translator_name=None):
        """检查语言对是否支持"""
        if translator_name:
            if translator_name in self.translators:
                translator = self.translators[translator_name]
                return (translator.is_language_supported(from_lang) and 
                        translator.is_language_supported(to_lang))
            return False
        
        # 检查是否有任意翻译器支持该语言对
        for translator in self.translators.values():
            if (translator.is_language_supported(from_lang) and 
                translator.is_language_supported(to_lang)):
                return True
        
        return False
    
    def translate(self, text, from_lang, to_lang):
        """翻译文本"""
        if not text or not text.strip():
            return ""
        
        # 检查当前翻译器是否支持该语言对
        current_translator = self.translators[self.current_translator]
        if not (current_translator.is_language_supported(from_lang) and 
                current_translator.is_language_supported(to_lang)):
            # 寻找支持该语言对的翻译器
            for name, translator in self.translators.items():
                if (translator.is_language_supported(from_lang) and 
                    translator.is_language_supported(to_lang)):
                    print(f"自动切换到翻译器: {name}（支持 {from_lang}->{to_lang}）")
                    self.current_translator = name
                    current_translator = translator
                    break
            else:
                # 如果没有翻译器明确支持，尝试使用当前翻译器（可能支持但未在列表中）
                print(f"警告：没有翻译器明确支持语言对 {from_lang}->{to_lang}，尝试使用当前翻译器")
        
        translator = self.translators[self.current_translator]
        try:
            print(f"使用翻译引擎: {self.current_translator}")
            result = translator.translate(text, from_lang, to_lang)
            return result
        except Exception as e:
            print(f"翻译失败 ({self.current_translator}): {e}")
            # 按优先级尝试备用翻译器
            fallback_order = ['libretranslate', 'mymemory', 'google', 'deepl', 'microsoft', 'baidu']
            
            for name in fallback_order:
                if name != self.current_translator and name in self.translators:
                    try:
                        print(f"尝试备用翻译器: {name}")
                        result = self.translators[name].translate(text, from_lang, to_lang)
                        return result
                    except Exception as backup_error:
                        print(f"备用翻译器 {name} 失败: {backup_error}")
                        continue
            
            raise Exception(f"所有翻译引擎都失败了: {e}")


class LibreTranslateTranslator(BaseTranslator):
    """LibreTranslate - 开源免费翻译API（改进版，支持自定义URL和实例管理）"""
    
    def __init__(self):
        super().__init__()
        
        # LibreTranslate特定的语言映射
        self.api_lang_map = {
            'zh': 'zh-Hans',  # 简体中文
            'zh-CN': 'zh-Hans',
            'zh-TW': 'zh-Hant',  # 繁体中文
            'ja': 'ja',
            'ko': 'ko',
            'ms': 'ms',
            'en': 'en',
            'fr': 'fr',
            'de': 'de',
            'it': 'it',
            'es': 'es',
            'pt': 'pt',
            'ru': 'ru',
            'ar': 'ar',
            'hi': 'hi',
            'th': 'th',
            'vi': 'vi',
            'tr': 'tr',
            'pl': 'pl',
            'nl': 'nl',
            'sv': 'sv',
            'da': 'da',
            'fi': 'fi',
            'no': 'no',
            'el': 'el',
            'he': 'he',
            'id': 'id',
            'bg': 'bg',
            'ro': 'ro',
            'hu': 'hu',
            'cs': 'cs',
            'sk': 'sk',
            'sl': 'sl',
            'hr': 'hr',
            'sr': 'sr',
            'uk': 'uk',
            'ca': 'ca',
            'af': 'af',
            'sw': 'sw',
            'eo': 'eo',
            'tl': 'tl'
        }
        
        # 原始公共实例列表（只读备份）
        self.original_public_instances = [
            "https://translate.fedilab.app",
            "https://translate.terraprint.co", 
            "https://translate.api.skitzen.com",
            "https://libretranslate.pussthecat.org",
            "https://translate.argosopentech.com",
            "https://libretranslate.de",
            "https://libretranslate.com"  # 官方实例（最后备选）
        ]
        
        # 工作实例列表（可添加自定义实例）
        self.public_instances = self.original_public_instances.copy()
        
        # 自定义实例列表
        self.custom_instances = []
        
        self.current_instance_index = 0
        self.base_url = self.public_instances[self.current_instance_index]
        
        # API密钥（可选，用于官方实例）
        self.api_key = None
        
        # 最大字符限制
        self.max_chars = 2000
        
        # 实例状态跟踪
        self.failed_instances = set()
        
        # 更新session headers
        self.session.headers.update({
            'Content-Type': 'application/json'
        })
    
    def set_api_key(self, api_key):
        """设置API密钥（如果需要）"""
        self.api_key = api_key
    
    def set_base_url(self, base_url):
        """设置自定义实例URL"""
        if not base_url:
            return
            
        custom_url = base_url.rstrip('/')
        
        # 如果URL已经在自定义实例列表中，移到最前面
        if custom_url in self.custom_instances:
            self.custom_instances.remove(custom_url)
        
        # 添加到自定义实例列表开头
        self.custom_instances.insert(0, custom_url)
        
        # 重新构建公共实例列表：自定义实例 + 原始公共实例
        self.public_instances = self.custom_instances + self.original_public_instances
        
        # 设置当前实例为第一个自定义实例
        self.current_instance_index = 0
        self.base_url = self.public_instances[self.current_instance_index]
        
        print(f"已设置自定义LibreTranslate实例: {custom_url}")
        print(f"当前实例列表: {len(self.public_instances)} 个实例")
    
    def add_custom_instance(self, base_url):
        """添加自定义实例（不改变当前实例）"""
        if not base_url:
            return False
            
        custom_url = base_url.rstrip('/')
        
        if custom_url in self.public_instances:
            return False
            
        # 添加到自定义实例列表
        if custom_url not in self.custom_instances:
            self.custom_instances.append(custom_url)
        
        # 重新构建公共实例列表
        self.public_instances = self.custom_instances + self.original_public_instances
        
        print(f"已添加自定义LibreTranslate实例: {custom_url}")
        print(f"当前实例列表: {len(self.public_instances)} 个实例")
        return True
    
    def remove_custom_instance(self, base_url):
        """移除自定义实例"""
        if not base_url:
            return False
            
        custom_url = base_url.rstrip('/')
        
        if custom_url in self.custom_instances:
            self.custom_instances.remove(custom_url)
            
            # 重新构建公共实例列表
            self.public_instances = self.custom_instances + self.original_public_instances
            
            # 如果当前实例是被移除的自定义实例，切换到下一个可用实例
            if self.base_url == custom_url:
                self._get_next_available_instance()
            
            print(f"已移除自定义LibreTranslate实例: {custom_url}")
            print(f"当前实例列表: {len(self.public_instances)} 个实例")
            return True
        
        return False
    
    def clear_custom_instances(self):
        """清除所有自定义实例"""
        removed_count = len(self.custom_instances)
        self.custom_instances.clear()
        
        # 恢复原始公共实例列表
        self.public_instances = self.original_public_instances.copy()
        
        # 重置当前实例
        self.current_instance_index = 0
        self.base_url = self.public_instances[self.current_instance_index]
        self.failed_instances.clear()
        
        print(f"已清除所有自定义实例，恢复 {len(self.public_instances)} 个公共实例")
        return removed_count
    
    def get_instance_info(self):
        """获取当前实例信息"""
        return {
            'current_instance': self.base_url,
            'current_index': self.current_instance_index,
            'total_instances': len(self.public_instances),
            'custom_instances': self.custom_instances.copy(),
            'failed_instances': list(self.failed_instances),
            'api_key_set': bool(self.api_key)
        }
    
    def get_supported_languages(self):
        """动态获取LibreTranslate支持的语言"""
        # 尝试从当前实例获取支持的语言
        try:
            langs_url = f"{self.base_url}/languages"
            response = self.session.get(langs_url, timeout=5)
            if response.status_code == 200:
                languages = response.json()
                return [lang['code'] for lang in languages]
        except:
            pass
        
        # 如果无法动态获取，返回预设的语言
        return list(self.api_lang_map.values())
    
    def _get_next_available_instance(self):
        """获取下一个可用实例"""
        for i in range(len(self.public_instances)):
            index = (self.current_instance_index + i) % len(self.public_instances)
            instance = self.public_instances[index]
            if instance not in self.failed_instances:
                self.current_instance_index = index
                self.base_url = instance
                return True
        return False
    
    def _mark_instance_as_failed(self, instance):
        """标记实例为失败"""
        self.failed_instances.add(instance)
        print(f"标记实例为失败: {instance}")
    
    def _check_instance_health(self, base_url):
        """检查实例健康状态"""
        try:
            # 尝试获取语言列表
            langs_url = f"{base_url}/languages"
            response = self.session.get(langs_url, timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def _split_text(self, text, max_length=2000):
        """将长文本分割成多个不超过max_length的段落"""
        if len(text) <= max_length:
            return [text]
        
        # 尝试在句子边界处分割
        sentences = re.split(r'(?<=[.!?。！？])\s*', text)
        chunks = []
        current_chunk = ""
        
        for sentence in sentences:
            if len(current_chunk) + len(sentence) + 1 <= max_length:
                if current_chunk:
                    current_chunk += " " + sentence
                else:
                    current_chunk = sentence
            else:
                if current_chunk:
                    chunks.append(current_chunk)
                current_chunk = sentence
                
                # 如果单个句子就超过限制，强制分割
                if len(current_chunk) > max_length:
                    for i in range(0, len(current_chunk), max_length):
                        chunks.append(current_chunk[i:i+max_length])
                    current_chunk = ""
        
        if current_chunk:
            chunks.append(current_chunk)
            
        return chunks
    
    def translate(self, text, from_lang, to_lang):
        """使用LibreTranslate API翻译"""
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 如果文本长度超过限制，分割文本
        if len(text) > self.max_chars:
            print(f"文本长度{len(text)}超过LibreTranslate限制({self.max_chars})，进行分割翻译")
            chunks = self._split_text(text, self.max_chars)
            translated_chunks = []
            
            for i, chunk in enumerate(chunks):
                print(f"翻译第 {i+1}/{len(chunks)} 段 (长度: {len(chunk)})")
                try:
                    translated_chunk = self._translate_with_retry(chunk, from_lang, to_lang)
                    translated_chunks.append(translated_chunk)
                    # 添加短暂延迟避免请求过快
                    time.sleep(0.2)
                except Exception as e:
                    print(f"第 {i+1} 段翻译失败: {e}")
                    # 如果某段失败，尝试使用原文
                    translated_chunks.append(chunk)
            
            return " ".join(translated_chunks)
        else:
            return self._translate_with_retry(text, from_lang, to_lang)
    
    def _translate_with_retry(self, text, from_lang, to_lang, max_retries=None):
        """带重试的翻译方法"""
        if max_retries is None:
            max_retries = len(self.public_instances)
        
        last_error = None
        
        for attempt in range(max_retries):
            try:
                return self._translate_chunk(text, from_lang, to_lang)
            except Exception as e:
                last_error = e
                print(f"实例 {self.base_url} 翻译失败: {e}")
                
                # 标记当前实例为失败并尝试下一个
                self._mark_instance_as_failed(self.base_url)
                
                if not self._get_next_available_instance():
                    # 所有实例都失败了，重置失败列表再试一次
                    if attempt == max_retries - 1:
                        break
                    self.failed_instances.clear()
                    self._get_next_available_instance()
                
                print(f"切换到LibreTranslate实例: {self.base_url}")
                time.sleep(1)  # 添加延迟
        
        raise Exception(f"所有LibreTranslate实例都失败: {last_error}")
    
    def _translate_chunk(self, text, from_lang, to_lang):
        """翻译单个文本块"""
        # 首先检查实例健康状态
        if not self._check_instance_health(self.base_url):
            raise Exception(f"实例 {self.base_url} 健康检查失败")
        
        # 准备请求数据
        data = {
            'q': text,
            'source': from_lang,
            'target': to_lang,
            'format': 'text'
        }
        
        # 添加API密钥（如果需要）
        if self.api_key and 'libretranslate.com' in self.base_url:
            data['api_key'] = self.api_key
        
        url = f"{self.base_url}/translate"
        
        print(f"LibreTranslate翻译: {from_lang} -> {to_lang} (长度: {len(text)})")
        
        response = self.session.post(url, json=data, timeout=15)
        response.raise_for_status()
        
        try:
            result = response.json()
        except json.JSONDecodeError:
            raise Exception(f"无效的JSON响应: {response.text[:200]}")
        
        if 'translatedText' in result:
            translated_text = result['translatedText']
            print(f"LibreTranslate翻译成功: {translated_text[:50]}...")
            return translated_text
        elif 'error' in result:
            error_msg = result['error']
            if 'API key' in error_msg:
                raise Exception(f"需要API密钥: {error_msg}")
            else:
                raise Exception(f"LibreTranslate API错误: {error_msg}")
        else:
            raise Exception(f"未知响应格式: {result}")


class MyMemoryTranslator(BaseTranslator):
    """MyMemory - 免费翻译API（每天1000次调用）"""
    
    def __init__(self):
        super().__init__()
        
        self.base_url = "https://api.mymemory.translated.net/get"
        self.custom_url = None
        
        # MyMemory特定的语言映射
        self.api_lang_map = {
            'zh': 'zh-CN',
            'zh-CN': 'zh-CN',
            'zh-TW': 'zh-TW',
            'ja': 'ja',
            'ko': 'ko', 
            'ms': 'ms',
            'en': 'en',
            'fr': 'fr',
            'de': 'de',
            'it': 'it',
            'es': 'es',
            'pt': 'pt',
            'ru': 'ru',
            'ar': 'ar',
            'hi': 'hi',
            'th': 'th',
            'vi': 'vi',
            'tr': 'tr',
            'pl': 'pl',
            'nl': 'nl'
        }
        
        self.max_chars = 500

    def set_base_url(self, base_url):
        """设置自定义API端点"""
        if base_url:
            self.custom_url = base_url.rstrip('/')
            self.base_url = self.custom_url
            print(f"已设置自定义MyMemory实例: {self.custom_url}")
    
    def get_supported_languages(self):
        """MyMemory支持的语言列表"""
        # MyMemory支持大量语言，这里返回部分常用语言
        return list(self.api_lang_map.values())
    
    def _split_text(self, text, max_length=500):
        """将长文本分割成多个不超过max_length的段落"""
        if len(text) <= max_length:
            return [text]
        
        sentences = re.split(r'(?<=[.!?。！？])\s*', text)
        chunks = []
        current_chunk = ""
        
        for sentence in sentences:
            if len(current_chunk) + len(sentence) + 1 <= max_length:
                if current_chunk:
                    current_chunk += " " + sentence
                else:
                    current_chunk = sentence
            else:
                if current_chunk:
                    chunks.append(current_chunk)
                current_chunk = sentence
                
                if len(current_chunk) > max_length:
                    for i in range(0, len(current_chunk), max_length):
                        chunks.append(current_chunk[i:i+max_length])
                    current_chunk = ""
        
        if current_chunk:
            chunks.append(current_chunk)
            
        return chunks
    
    def translate(self, text, from_lang, to_lang):
        """使用MyMemory API翻译，自动处理长文本分割"""
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 如果文本长度超过限制，分割文本
        if len(text) > self.max_chars:
            print(f"文本长度{len(text)}超过MyMemory限制({self.max_chars})，进行分割翻译")
            chunks = self._split_text(text, self.max_chars)
            translated_chunks = []
            
            for i, chunk in enumerate(chunks):
                print(f"翻译第 {i+1}/{len(chunks)} 段 (长度: {len(chunk)})")
                try:
                    translated_chunk = self._translate_chunk(chunk, from_lang, to_lang)
                    translated_chunks.append(translated_chunk)
                    time.sleep(0.1)
                except Exception as e:
                    print(f"第 {i+1} 段翻译失败: {e}")
                    translated_chunks.append(chunk)
            
            return " ".join(translated_chunks)
        else:
            return self._translate_chunk(text, from_lang, to_lang)
    
    def _translate_chunk(self, text, from_lang, to_lang):
        """翻译单个文本块"""
        params = {
            'q': text,
            'langpair': f"{from_lang}|{to_lang}"
        }
        
        try:
            print(f"MyMemory翻译: {from_lang} -> {to_lang} (长度: {len(text)})")
            
            response = self.session.get(self.base_url, params=params, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            
            if result.get('responseStatus') == 200:
                translated_text = result['responseData']['translatedText']
                print(f"MyMemory翻译成功: {translated_text[:50]}...")
                return translated_text
            elif result.get('responseStatus') == 403:
                raise Exception("MyMemory API配额已用完（每日1000次限制）")
            else:
                error_details = result.get('responseDetails', 'Unknown error')
                raise Exception(f"MyMemory错误: {error_details}")
                
        except Exception as e:
            raise Exception(f"MyMemory翻译失败: {e}")


class GoogleTranslator(BaseTranslator):
    """Google翻译 - 支持官方API和模拟网页翻译"""
    
    def __init__(self):
        super().__init__()
        
        # 默认使用官方API端点
        self.base_url = "https://translation.googleapis.com"
        self.api_key = None
        self.use_custom_endpoint = False
        self.simulate_browser = True  # 默认启用浏览器模拟
        
        # Google翻译支持的语言映射
        self.api_lang_map = {
            'zh': 'zh-CN',
            'zh-CN': 'zh-CN',
            'zh-TW': 'zh-TW',
            'ja': 'ja',
            'ko': 'ko',
            'ms': 'ms',
            'en': 'en',
            'fr': 'fr',
            'de': 'de',
            'it': 'it',
            'es': 'es',
            'pt': 'pt',
            'ru': 'ru',
            'ar': 'ar',
            'hi': 'hi',
            'th': 'th',
            'vi': 'vi',
            'tr': 'tr',
            'pl': 'pl',
            'nl': 'nl',
            'sv': 'sv',
            'da': 'da',
            'fi': 'fi',
            'no': 'no',
            'el': 'el',
            'he': 'he',
            'id': 'id',
            'bg': 'bg',
            'ro': 'ro',
            'hu': 'hu',
            'cs': 'cs',
            'sk': 'sk',
            'sl': 'sl',
            'hr': 'hr',
            'sr': 'sr',
            'uk': 'uk',
            'ca': 'ca'
        }
        
        # 浏览器模拟相关设置
        self.browser_headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
    
    def set_api_key(self, api_key):
        """设置Google Cloud API密钥"""
        self.api_key = api_key
    
    def set_base_url(self, base_url):
        """设置自定义API端点"""
        self.base_url = base_url.rstrip('/')
    
    def set_simulate_browser(self, simulate):
        """设置是否模拟浏览器行为"""
        self.simulate_browser = simulate
    
    def get_supported_languages(self):
        """Google翻译支持的语言列表"""
        return list(self.api_lang_map.values())
    
    def translate_official_api(self, text, from_lang, to_lang):
        """使用Google Cloud官方API翻译"""
        if not self.api_key:
            raise Exception("Google翻译需要API密钥，请在设置中配置")
        
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 构建请求URL
        url = f"{self.base_url}/language/translate/v2"
        
        params = {
            'key': self.api_key,
            'q': text,
            'source': from_lang,
            'target': to_lang,
            'format': 'text'
        }
        
        try:
            print(f"Google官方API翻译: {from_lang} -> {to_lang} (长度: {len(text)})")
            
            headers = {}
            if self.simulate_browser:
                headers.update(self.browser_headers)
                headers['Content-Type'] = 'application/json'
            
            response = self.session.post(url, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            
            if 'data' in result and 'translations' in result['data']:
                translated_text = result['data']['translations'][0]['translatedText']
                print(f"Google官方API翻译成功: {translated_text[:50]}...")
                return translated_text
            elif 'error' in result:
                error_msg = result['error'].get('message', 'Unknown error')
                raise Exception(f"Google翻译API错误: {error_msg}")
            else:
                raise Exception(f"未知响应格式: {result}")
                
        except Exception as e:
            raise Exception(f"Google官方API翻译失败: {e}")
    
    def translate_web_simulation(self, text, from_lang, to_lang):
        """模拟网页版Google翻译"""
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 网页版Google翻译的标准参数
        params = {
            'client': 'gtx',
            'sl': from_lang,
            'tl': to_lang,
            'hl': 'zh-CN',
            'dt': 't',
            'dt': 'at',
            'dt': 'bd',
            'dt': 'ex',
            'dt': 'ld',
            'dt': 'md',
            'dt': 'qca',
            'dt': 'rw',
            'dt': 'rm',
            'dt': 'ss',
            'otf': '1',
            'ssel': '0',
            'tsel': '0',
            'kc': '1',
            'q': text
        }
        
        # 如果是Google翻译网页版端点，使用标准URL
        if 'translate.google.com' in self.base_url:
            url = f"{self.base_url}/translate_a/single"
        else:
            url = self.base_url
        
        try:
            print(f"Google网页模拟翻译: {from_lang} -> {to_lang} (长度: {len(text)})")
            
            # 设置详细的浏览器头信息
            headers = self.browser_headers.copy()
            headers.update({
                'Referer': 'https://translate.google.com/',
                'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
                'X-Requested-With': 'XMLHttpRequest'
            })
            
            # 添加随机延迟模拟真实用户行为
            if self.simulate_browser:
                import random
                time.sleep(random.uniform(0.1, 0.5))
            
            response = self.session.get(url, params=params, headers=headers, timeout=15)
            response.raise_for_status()
            
            # 网页版Google翻译返回的是特殊格式的JSON数组
            result = response.json()
            
            # 解析网页版Google翻译的复杂响应格式
            translated_text = self._parse_web_translation_response(result)
            
            if translated_text:
                print(f"Google网页模拟翻译成功: {translated_text[:50]}...")
                return translated_text
            else:
                raise Exception("无法解析网页翻译响应")
                
        except Exception as e:
            raise Exception(f"Google网页模拟翻译失败: {e}")
    
    def _parse_web_translation_response(self, result):
        """解析网页版Google翻译的复杂响应格式"""
        try:
            # 格式1: 标准网页版Google翻译格式
            # [[["翻译文本","原文",null,null,1]],null,"zh-CN",null,null,null,null,[]]
            if isinstance(result, list) and len(result) > 0:
                if result[0]:  # 第一个元素包含翻译结果
                    translated_parts = []
                    for sentence_group in result[0]:
                        if isinstance(sentence_group, list) and len(sentence_group) > 0:
                            # 每个句子组的第一元素是翻译文本
                            translated_text = sentence_group[0]
                            if translated_text and isinstance(translated_text, str):
                                translated_parts.append(translated_text)
                    
                    if translated_parts:
                        return ''.join(translated_parts).strip()
            
            # 格式2: 简化的翻译格式
            if isinstance(result, list):
                for item in result:
                    if isinstance(item, list):
                        for subitem in item:
                            if isinstance(subitem, list) and len(subitem) > 0:
                                if isinstance(subitem[0], str) and len(subitem[0]) > 1:
                                    return subitem[0].strip()
            
            # 格式3: 字典格式
            if isinstance(result, dict):
                # 尝试常见的键名
                for key in ['translatedText', 'translation', 'text', 'data']:
                    if key in result:
                        value = result[key]
                        if isinstance(value, str):
                            return value.strip()
                        elif isinstance(value, list) and value:
                            if isinstance(value[0], str):
                                return value[0].strip()
                            elif isinstance(value[0], dict) and 'translatedText' in value[0]:
                                return value[0]['translatedText'].strip()
            
            return None
            
        except Exception as e:
            print(f"解析网页翻译响应时出错: {e}")
            return None
    
    def translate_custom_endpoint(self, text, from_lang, to_lang):
        """使用自定义端点翻译"""
        # 检测端点类型并选择合适的翻译方法
        if self._is_web_endpoint(self.base_url):
            return self.translate_web_simulation(text, from_lang, to_lang)
        else:
            return self._translate_generic_endpoint(text, from_lang, to_lang)
    
    def _is_web_endpoint(self, url):
        """检测是否为网页版端点"""
        web_indicators = [
            'translate.google.com',
            'translate.goog',
            'web.translate',
            '/translate_a/',
            '/translate_a/single'
        ]
        return any(indicator in url for indicator in web_indicators)
    
    def _translate_generic_endpoint(self, text, from_lang, to_lang):
        """通用端点翻译方法"""
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 尝试多种参数格式
        param_sets = [
            # 格式1: 标准网页参数
            {
                'client': 'gtx',
                'sl': from_lang,
                'tl': to_lang,
                'dt': 't',
                'q': text
            },
            # 格式2: 简化参数
            {
                'sl': from_lang,
                'tl': to_lang,
                'q': text
            },
            # 格式3: 官方API格式
            {
                'key': self.api_key or 'none',
                'source': from_lang,
                'target': to_lang,
                'q': text,
                'format': 'text'
            }
        ]
        
        headers = self.browser_headers.copy() if self.simulate_browser else {}
        
        last_error = None
        for param_set in param_sets:
            try:
                print(f"尝试参数格式: {list(param_set.keys())}")
                
                # 尝试GET请求
                response = self.session.get(self.base_url, params=param_set, headers=headers, timeout=10)
                if response.status_code == 200:
                    result = response.json()
                    translated = self._parse_generic_response(result)
                    if translated:
                        return translated
                
                # 尝试POST请求
                response = self.session.post(self.base_url, data=param_set, headers=headers, timeout=10)
                if response.status_code == 200:
                    result = response.json()
                    translated = self._parse_generic_response(result)
                    if translated:
                        return translated
                        
            except Exception as e:
                last_error = e
                continue
        
        raise Exception(f"所有参数格式都失败: {last_error}")
    
    def _parse_generic_response(self, result):
        """通用响应解析"""
        # 尝试多种解析方法
        parsers = [
            self._parse_web_translation_response,
            self._parse_standard_json,
            self._deep_search_translation
        ]
        
        for parser in parsers:
            try:
                translated = parser(result)
                if translated:
                    return translated
            except:
                continue
        
        return None
    
    def _parse_standard_json(self, result):
        """解析标准JSON响应"""
        if isinstance(result, dict):
            # 查找翻译相关的键
            translation_keys = ['translatedText', 'translation', 'text', 'result']
            for key in translation_keys:
                if key in result:
                    value = result[key]
                    if isinstance(value, str) and value.strip():
                        return value.strip()
                    elif isinstance(value, list) and value:
                        if isinstance(value[0], str):
                            return value[0].strip()
                        elif isinstance(value[0], dict):
                            return self._parse_standard_json(value[0])
        return None
    
    def _deep_search_translation(self, obj, max_depth=3):
        """深度搜索翻译文本"""
        if max_depth <= 0:
            return None
        
        if isinstance(obj, str) and len(obj) > 10:  # 假设翻译文本长度大于10
            return obj.strip()
        
        elif isinstance(obj, list):
            for item in obj:
                result = self._deep_search_translation(item, max_depth-1)
                if result:
                    return result
        
        elif isinstance(obj, dict):
            # 优先检查包含"trans"的键
            for key, value in obj.items():
                if 'trans' in key.lower():
                    result = self._deep_search_translation(value, max_depth-1)
                    if result:
                        return result
            
            # 检查所有值
            for value in obj.values():
                result = self._deep_search_translation(value, max_depth-1)
                if result:
                    return result
        
        return None
    
    def translate(self, text, from_lang, to_lang):
        """翻译文本 - 根据设置选择实现方式"""
        if not text or not text.strip():
            return ""
        
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        print(f"Google翻译开始: {from_lang} -> {to_lang}, 使用{'自定义端点' if self.use_custom_endpoint else '官方API'}")
        
        try:
            if self.use_custom_endpoint:
                return self.translate_custom_endpoint(text, from_lang, to_lang)
            else:
                return self.translate_official_api(text, from_lang, to_lang)
        except Exception as e:
            # 如果当前模式失败，尝试切换到另一种模式作为备选
            error_msg = str(e)
            print(f"Google翻译失败: {error_msg}")
            
            if self.use_custom_endpoint:
                # 如果自定义端点失败，尝试官方API（如果有API密钥）
                if self.api_key:
                    print("尝试切换到官方API作为备选")
                    try:
                        return self.translate_official_api(text, from_lang, to_lang)
                    except Exception as fallback_error:
                        raise Exception(f"Google翻译全部模式失败: 自定义端点 - {error_msg}, 官方API - {fallback_error}")
                else:
                    raise Exception(f"Google自定义端点翻译失败: {error_msg}")
            else:
                # 如果官方API失败，尝试自定义端点（如果有自定义端点）
                if self.base_url and self.base_url != "https://translation.googleapis.com":
                    print("尝试切换到自定义端点作为备选")
                    try:
                        return self.translate_custom_endpoint(text, from_lang, to_lang)
                    except Exception as fallback_error:
                        raise Exception(f"Google翻译全部模式失败: 官方API - {error_msg}, 自定义端点 - {fallback_error}")
                else:
                    raise Exception(f"Google官方API翻译失败: {error_msg}")

class DeepLTranslator(BaseTranslator):
    """DeepL翻译 - 免费版本"""
    
    def __init__(self):
        super().__init__()
        
        self.base_url = "https://api-free.deepl.com/v2/translate"
        self.api_key = None
        
        # DeepL支持的语言映射
        self.api_lang_map = {
            'zh': 'ZH',
            'ja': 'JA', 
            'en': 'EN',
            'de': 'DE',
            'fr': 'FR',
            'it': 'IT',
            'es': 'ES',
            'pt': 'PT',
            'ru': 'RU',
            'pl': 'PL',
            'nl': 'NL',
            'sv': 'SV',
            'da': 'DA',
            'fi': 'FI',
            'el': 'EL',
            'hu': 'HU',
            'cs': 'CS',
            'ro': 'RO',
            'sk': 'SK',
            'sl': 'SL',
            'bg': 'BG'
        }
    
    def set_api_key(self, api_key):
        """设置DeepL API密钥"""
        self.api_key = api_key
    
    def get_supported_languages(self):
        """DeepL支持的语言列表"""
        return list(self.api_lang_map.values())
    
    def translate(self, text, from_lang, to_lang):
        """使用DeepL API翻译文本"""
        if not self.api_key:
            # 尝试使用免费的DeepL网页版（不稳定）
            return self._translate_web_version(text, from_lang, to_lang)
        
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        headers = {
            'Authorization': f'DeepL-Auth-Key {self.api_key}',
            'Content-Type': 'application/json'
        }
        
        data = {
            'text': [text],
            'source_lang': from_lang,
            'target_lang': to_lang
        }
        
        try:
            response = requests.post(self.base_url, headers=headers, json=data, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            if result.get('translations'):
                return result['translations'][0]['text']
                
        except Exception as e:
            raise Exception(f"DeepL翻译失败: {e}")
        
        return text
    
    def _translate_web_version(self, text, from_lang, to_lang):
        """使用DeepL网页版进行翻译（备用方案）"""
        try:
            url = "https://www2.deepl.com/jsonrpc"
            
            data = {
                "jsonrpc": "2.0",
                "method": "LMT_handle_jobs",
                "params": {
                    "jobs": [{
                        "kind": "default",
                        "raw_en_sentence": text,
                        "raw_en_context_before": [],
                        "raw_en_context_after": [],
                        "preferred_num_beams": 1
                    }],
                    "lang": {
                        "source_lang_user_selected": from_lang.upper(),
                        "target_lang": to_lang.upper()
                    },
                    "priority": 1,
                    "commonJobParams": {},
                    "timestamp": int(time.time() * 1000)
                },
                "id": random.randint(1, 99999999)
            }
            
            headers = {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.post(url, json=data, headers=headers, timeout=15)
            if response.status_code == 200:
                result = response.json()
                if 'result' in result and 'translations' in result['result']:
                    translations = result['result']['translations']
                    if translations and 'beams' in translations[0]:
                        return translations[0]['beams'][0]['postprocessed_sentence']
            
        except Exception as e:
            print(f"DeepL网页版翻译失败: {e}")
        
        return text


class BaiduTranslator(BaseTranslator):
    """百度翻译"""
    
    def __init__(self):
        super().__init__()
        
        self.base_url = "https://fanyi-api.baidu.com/api/trans/vip/translate"
        self.app_id = None
        self.secret_key = None
        
        # 百度翻译支持的语言映射
        self.api_lang_map = {
            'zh': 'zh',
            'ja': 'jp',
            'en': 'en',
            'ko': 'kor',
            'ms': 'may',
            'fr': 'fra',
            'de': 'de',
            'it': 'it',
            'es': 'spa',
            'pt': 'pt',
            'ru': 'ru',
            'ar': 'ara',
            'hi': 'hi',
            'th': 'th',
            'vi': 'vie',
            'tr': 'tr',
            'pl': 'pl',
            'nl': 'nl',
            'sv': 'swe',
            'da': 'dan',
            'fi': 'fin',
            'el': 'el',
            'hu': 'hu',
            'cs': 'cs',
            'ro': 'rom',
            'sk': 'slo',
            'sl': 'slo',
            'bg': 'bul',
            'hr': 'hrv',
            'sr': 'srp',
            'uk': 'ukr'
        }
    
    def set_credentials(self, app_id, secret_key):
        """设置百度翻译API凭据"""
        self.app_id = app_id
        self.secret_key = secret_key
    
    def get_supported_languages(self):
        """百度翻译支持的语言列表"""
        return list(self.api_lang_map.values())
    
    def translate(self, text, from_lang, to_lang):
        """使用百度翻译API翻译文本"""
        if not self.app_id or not self.secret_key:
            # 尝试使用免费的百度翻译网页版
            return self._translate_web_version(text, from_lang, to_lang)
        
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        # 生成签名
        salt = str(random.randint(32768, 65536))
        sign_str = self.app_id + text + salt + self.secret_key
        sign = hashlib.md5(sign_str.encode()).hexdigest()
        
        params = {
            'q': text,
            'from': from_lang,
            'to': to_lang,
            'appid': self.app_id,
            'salt': salt,
            'sign': sign
        }
        
        try:
            response = self.session.get(self.base_url, params=params, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            if 'trans_result' in result:
                return result['trans_result'][0]['dst']
            elif 'error_code' in result:
                raise Exception(f"百度翻译API错误: {result.get('error_msg', result['error_code'])}")
                
        except Exception as e:
            raise Exception(f"百度翻译失败: {e}")
        
        return text
    
    def _translate_web_version(self, text, from_lang, to_lang):
        """使用百度翻译网页版（简化版本）"""
        try:
            url = "https://fanyi.baidu.com/sug"
            data = {'kw': text}
            
            response = self.session.post(url, data=data, timeout=10)
            if response.status_code == 200:
                result = response.json()
                if result.get('data'):
                    return result['data'][0]['v']
            
        except Exception as e:
            print(f"百度网页版翻译失败: {e}")
        
        return text


class MicrosoftTranslator(BaseTranslator):
    """微软翻译"""
    
    def __init__(self):
        super().__init__()
        
        self.base_url = "https://api.cognitive.microsofttranslator.com/translate"
        self.api_key = None
        self.region = "global"
        
        # 微软翻译支持的语言映射
        self.api_lang_map = {
            'zh': 'zh-Hans',
            'ja': 'ja',
            'ko': 'ko',
            'ms': 'ms',
            'en': 'en',
            'fr': 'fr',
            'de': 'de',
            'it': 'it',
            'es': 'es',
            'pt': 'pt',
            'ru': 'ru',
            'ar': 'ar',
            'hi': 'hi',
            'th': 'th',
            'vi': 'vi',
            'tr': 'tr',
            'pl': 'pl',
            'nl': 'nl',
            'sv': 'sv',
            'da': 'da',
            'fi': 'fi',
            'no': 'no',
            'el': 'el',
            'he': 'he',
            'id': 'id',
            'bg': 'bg',
            'ro': 'ro',
            'hu': 'hu',
            'cs': 'cs',
            'sk': 'sk',
            'sl': 'sl',
            'hr': 'hr',
            'sr': 'sr',
            'uk': 'uk',
            'ca': 'ca'
        }
    
    def set_credentials(self, api_key, region="global"):
        """设置微软翻译API凭据"""
        self.api_key = api_key
        self.region = region
    
    def get_supported_languages(self):
        """微软翻译支持的语言列表"""
        return list(self.api_lang_map.values())
    
    def translate(self, text, from_lang, to_lang):
        """使用微软翻译API翻译文本"""
        if not self.api_key:
            # 尝试使用免费的微软翻译网页版
            return self._translate_web_version(text, from_lang, to_lang)
        
        # 映射语言代码
        from_lang = self.map_language(from_lang)
        to_lang = self.map_language(to_lang)
        
        headers = {
            'Ocp-Apim-Subscription-Key': self.api_key,
            'Ocp-Apim-Subscription-Region': self.region,
            'Content-Type': 'application/json'
        }
        
        params = {
            'api-version': '3.0',
            'from': from_lang,
            'to': to_lang
        }
        
        body = [{'text': text}]
        
        try:
            response = requests.post(self.base_url, params=params, headers=headers, json=body, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            if result and result[0].get('translations'):
                return result[0]['translations'][0]['text']
                
        except Exception as e:
            raise Exception(f"微软翻译失败: {e}")
        
        return text
    
    def _translate_web_version(self, text, from_lang, to_lang):
        """使用微软翻译网页版（备用方案）"""
        # 简化实现，实际情况可能需要更复杂的处理
        return text


# 使用示例和测试
if __name__ == "__main__":
    # 创建在线翻译器
    online_translator = OnlineTranslator()
    
    # 测试不同语言对的翻译
    test_cases = [
        ("Hello, how are you today?", "en", "zh"),  # 英文到中文
        ("Bonjour, comment allez-vous?", "fr", "en"),  # 法文到英文
        ("Hola, ¿cómo estás?", "es", "zh"),  # 西班牙文到中文
        ("こんにちは、お元気ですか？", "ja", "en"),  # 日文到英文
    ]
    
    for i, (text, from_lang, to_lang) in enumerate(test_cases, 1):
        print(f"\n=== 测试案例 {i}: {from_lang} -> {to_lang} ===")
        print(f"原文: {text}")
        
        try:
            result = online_translator.translate(text, from_lang, to_lang)
            print(f"翻译结果: {result}")
        except Exception as e:
            print(f"翻译失败: {e}")
    
    # 测试支持的语言列表
    print(f"\n=== 支持的语言 ===")
    supported_langs = online_translator.get_supported_languages()
    print(f"共同支持的语言数量: {len(supported_langs)}")
    print(f"前20种语言: {supported_langs[:20]}")
    
    # 测试特定翻译器的支持语言
    print(f"\n=== LibreTranslate支持的语言 ===")
    libretranslate_langs = online_translator.translators['libretranslate'].get_supported_languages()
    print(f"LibreTranslate支持 {len(libretranslate_langs)} 种语言")
    
    # 测试长文本翻译
    print(f"\n=== 长文本翻译测试 ===")
    long_text = "This is a long text that needs to be translated. " * 30
    try:
        result = online_translator.translate(long_text, "en", "zh")
        print(f"长文本翻译成功，前100字符: {result[:100]}...")
    except Exception as e:
        print(f"长文本翻译失败: {e}")