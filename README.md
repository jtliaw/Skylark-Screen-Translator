<img width="256" height="256" alt="skylark" src="https://github.com/user-attachments/assets/235f3cbf-3bfb-4ad9-b62d-9977126fdec4" />





# 🌤 Skylark Screen Translator
Skylark Screen Translator 是一款简洁美观、操作直觉的屏幕翻译工具，结合 OCR 与 Argos Translate，可翻译高达 30 多种语言，并采用智能翻译路径选择机制，无需用户手动配置转换路径。

“Skylark” 是自由飞翔的云雀 —— 象征自由、轻盈与语言无界限的传达体验。

---
📷 界面截图
<img width="640" height="382" alt="截图_2025-08-03_17-38-20" src="https://github.com/user-attachments/assets/88c3d27b-f170-429f-9f04-475b80a56870" />


<img width="640" height="382" alt="截图_2025-08-03_17-40-28" src="https://github.com/user-attachments/assets/4a0f96f8-4868-49be-ab7c-84de34b4774d" />

---

✨ 功能特色

📷 任意屏幕区域文字识别（OCR）

🌍 支持多语言离线翻译

⚡️ 自动选择最快翻译路径（包括中转）

🧠 内置语言包 / OCR 模型管理与自动下载

🖱 全滑鼠操作：右键翻译、左键显示/隐藏翻译框

🪟 现代简约风格图形界面

🖥 安装后自动创建桌面图标，一键启动

🔄 一键安装 / 卸载脚本支持（Linux）

---

🧰 安装方式（Linux）

在终端中运行以下命令进行安装：

    ./Install_LinuxSkylarkTranslator.sh

安装完成后，系统会自动配置所需环境，并在桌面创建图标。点击桌面图标即可快速启动。
📥 第一次使用指南

启动软件后，点击【语言包管理】。

至少安装一种你所需要的语言翻译方向，例如：

英语 ➜ 中文

日语 ➜ 英语

英语 ➜ 法语

安装完成后请重新启动软件，即可在【设置语言】中选择你需要的翻译方向。

---

🔁 关于 Argos Translate 的翻译机制

Argos Translate 的语言包为单向翻译包，即：

“日语 ➜ 中文”与“中文 ➜ 日语”是两个完全不同的包。

并非所有语言对都直接支持双向翻译。

🌟 Skylark 的中转翻译机制

Skylark Translator 内建“自动中转翻译路径智能选择”功能：

当你需要翻译如“日语 ➜ 中文”而 Argos 没有提供直接翻译包时，软件将自动采用如下路径：

日语 ➜ 英语 ➜ 中文

若系统中同时安装了“日语 ➜ 英语”与“英语 ➜ 中文”的语言包，程序将自动组合路径进行中转翻译，无需用户手动设定。

若存在直接语言包（如“英语 ➜ 中文”），则会优先采用直接翻译以提升速度与准确率。

---

🖱 操作方式说明

左键拖曳	框选屏幕任意区域

滑鼠右键双击	执行 OCR + 翻译，显示结果

滑鼠左键单击	隐藏或重新显示翻译窗口

滑鼠滚轮  可以显示被遮挡的翻译内容

---
🧹 卸载说明

运行以下命令即可卸载本软件及其配置：

    ./Uninstall_LinuxSkylarkTranslator.sh

---

📌 支持语言

已支持超过 30 种语言，包括但不限于：

英语、中文、日语、韩语、法语、德语、西班牙语、俄语、意大利语、葡萄牙语……

你可以自由安装任意 Argos 语言包组合（单向），Skylark 将为你自动处理所有翻译路径细节。



🙏 鸣谢

💬 Argos Translate — 开源的高质量离线翻译引擎

👓 Tesseract OCR — Google 出品的 OCR 引擎

🎨 Qt + PyQt5 — 现代化桌面图形界面开发库
