# AppImage 一键打包使用说明

## 快速开始

本项目提供了 `build_appimage.sh` 脚本，可以让用户根据自己的需求打包包含（ArgosTranslate离线）特定语言支持的 AppImage。

### 使用方法

1. 下载 skylark_screen_translator_v2.2 或以上的 Source code (zip) 
2. 根据需要修改脚本中的语言配置
3. 运行脚本进行打包

### 自定义语言配置

打开 `build_appimage.sh` 脚本，找到以下代码段：

```bash
# 选择要打包的语言对（可自行增减）
desired_langs = ['en', 'zh', 'ja', 'ko']
target_packages = [
    pkg for pkg in available_packages
    if pkg.from_code in desired_langs and pkg.to_code in desired_langs
]
```

修改 `desired_langs` 列表中的语言代码，添加或删除您需要的语言。

## 支持的语言列表

以下是 Tesseract OCR 和 ArgosTranslate 支持的语言代码对照表：

### 主要语言
| 语言代码 | 语言名称 | 英文名称 |
|---------|---------|---------|
| `'en'` | 英文 | English |
| `'zh'` | 中文 | Chinese |
| `'ja'` | 日文 | Japanese |
| `'ko'` | 韩文 | Korean |
| `'de'` | 德语 | German |
| `'fr'` | 法语 | French |
| `'es'` | 西班牙语 | Spanish |
| `'it'` | 意大利语 | Italian |
| `'pt'` | 葡萄牙语 | Portuguese |
| `'ru'` | 俄语 | Russian |

### 欧洲语言
| 语言代码 | 语言名称 | 英文名称 |
|---------|---------|---------|
| `'nl'` | 荷兰语 | Dutch |
| `'pl'` | 波兰语 | Polish |
| `'sv'` | 瑞典语 | Swedish |
| `'da'` | 丹麦语 | Danish |
| `'fi'` | 芬兰语 | Finnish |
| `'cs'` | 捷克语 | Czech |
| `'sk'` | 斯洛伐克语 | Slovak |
| `'hu'` | 匈牙利语 | Hungarian |

### 亚洲语言
| 语言代码 | 语言名称 | 英文名称 |
|---------|---------|---------|
| `'ar'` | 阿拉伯语 | Arabic |
| `'fa'` | 波斯语 | Persian |
| `'hi'` | 印地语 | Hindi |
| `'id'` | 印度尼西亚语 | Indonesian |
| `'ms'` | 马来语 | Malay |
| `'tr'` | 土耳其语 | Turkish |
| `'he'` | 希伯来语 | Hebrew |

### 其他语言
| 语言代码 | 语言名称 | 英文名称 |
|---------|---------|---------|
| `'ca'` | 加泰罗尼亚语 | Catalan |
| `'ga'` | 爱尔兰语 | Irish |
| `'az'` | 阿塞拜疆语 | Azerbaijani |

## 配置示例

### 示例 1：仅支持中英翻译
```bash
desired_langs = ['en', 'zh']
```

### 示例 2：支持多语言翻译（中、英、日、韩）
```bash
desired_langs = ['en', 'zh', 'ja', 'ko']
```

### 示例 3：支持欧洲主要语言
```bash
desired_langs = ['en', 'de', 'fr', 'es', 'it', 'pt', 'ru']
```

### 示例 4：支持亚洲语言
```bash
desired_langs = ['en', 'zh', 'ja', 'ko', 'ar', 'hi']
```

## 注意事项

1. **包大小**：添加的语言越多，最终生成的 AppImage 文件越大
2. **下载时间**：首次运行时需要下载对应的语言包，语言越多下载时间越长
3. **兼容性**：请确保所选择的语言组合在 ArgosTranslate 中有对应的翻译模型
4. **存储空间**：确保有足够的磁盘空间存放语言包和生成的 AppImage

## 构建命令

配置完成后，运行以下命令开始打包：

```bash
chmod +x build_appimage.sh
./build_appimage.sh
```

打包完成后，您将获得一个包含所选语言支持的完整 AppImage 文件，其他的所有文件即可删除！
