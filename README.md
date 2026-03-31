<p align="center">
  <img src="https://raw.githubusercontent.com/CalvinQin/SuperRClick/main/assets/icon.png" width="128" alt="Super RClick Icon"/>
</p>

<h1 align="center">Super RClick</h1>

<p align="center">
  <strong>The most powerful Finder right-click menu enhancer for macOS</strong><br/>
  macOS Finder 右键增强工具 — 让你的文件操作更高效、更优雅
</p>

<p align="center">
  <a href="https://github.com/CalvinQin/SuperRClick/releases/latest"><img src="https://img.shields.io/github/v/release/CalvinQin/SuperRClick?style=flat-square&color=blue" alt="Latest Release"/></a>
  <a href="https://github.com/CalvinQin/SuperRClick/releases"><img src="https://img.shields.io/github/downloads/CalvinQin/SuperRClick/total?style=flat-square&color=green" alt="Downloads"/></a>
  <img src="https://img.shields.io/badge/platform-macOS%2015+-black?style=flat-square" alt="macOS 15+"/>
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square" alt="Swift"/>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/CalvinQin/SuperRClick?style=flat-square" alt="License"/></a>
  <img src="https://img.shields.io/badge/language-中文%20%7C%20English-brightgreen?style=flat-square" alt="Bilingual"/>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#功能特性">功能特性</a> ·
  <a href="#installation">Install</a> ·
  <a href="#screenshots">Screenshots</a>
</p>

---

## Why Super RClick?

macOS Finder's right-click menu is limited. **Super RClick** transforms it into a productivity powerhouse — batch rename files, compress archives, convert images, create new files, open terminal, and more. All from one elegant right-click.

> 🆓 **Free & Open Source** — No subscriptions, no tracking, no nonsense.

---

## Features

### 🗂️ File Operations
- **Copy Path** — Copy full path, POSIX path, or shell-escaped path with one click
- **Open Terminal Here** — Open Terminal directly in any Finder folder
- **Compress Items** — Quickly archive selected files & folders to ZIP with progress bar
- **Quick Jump to Directory** — Enter any path and jump directly in Finder

### ✏️ Batch Rename
- Three rename modes: **prefix**, **suffix**, and **find & replace**
- Smart numbering with customizable start, step, and zero-padding
- Real-time preview with conflict detection
- Works from Finder right-click or MenuBar with file picker

### 🖼️ Image Conversion
- Convert between **PNG / JPEG / TIFF / HEIC** formats
- One-click format selection via Finder submenu
- Progress indicator with completion notification
- Output saved alongside original files

### 📄 New File Templates
- Create files instantly: `.txt`, `.md`, `.py`, `.json`, `.html`, `.css`, `.js`, `.ts`, `.csv`, `.xml`, `.yaml`, `.sh`, `.swift`, `.java` and more
- Organized submenu — no more creating files from Terminal

### ⚙️ Customization
- **Custom Actions** — Create your own right-click menu commands
- **Toggle Visibility** — Show/hide menu items as needed
- **Workspace Management** — Monitor and manage multiple directories
- **MenuBar Quick Access** — All tools accessible from the menu bar
- **Bilingual UI** — Full Chinese (中文) and English support

---

## 功能特性

**Super RClick** 是一款专为 macOS 设计的 Finder 右键菜单增强工具。

| 功能 | 说明 |
|------|------|
| 📋 复制路径 | 完整路径、POSIX 路径、Shell 转义路径一键复制 |
| 📦 压缩文件 | 选中文件/文件夹快速压缩，带进度条 |
| ✏️ 批量重命名 | 前缀、后缀、替换 + 智能编号 + 实时预览 |
| 🖼️ 图片转换 | PNG / JPEG / TIFF / HEIC 格式互转 |
| 📄 新建文件 | 支持 20+ 种文件模板快速创建 |
| 🚀 快速跳转 | 输入路径直达目标目录 |
| 💻 在终端打开 | 当前目录一键打开 Terminal |
| ⚙️ 自定义动作 | 创建你自己的右键菜单命令 |

---

## Installation

### Option 1: Download DMG (Recommended)

1. Go to [**Releases**](https://github.com/CalvinQin/SuperRClick/releases/latest) and download the `.dmg` file
2. Open the DMG and drag **Super RClick** into **Applications**
3. Launch the app
4. Enable the Finder extension: **System Settings → Privacy & Security → Extensions → Finder Extensions → Super RClick**

### Option 2: Build from Source

```bash
git clone https://github.com/CalvinQin/SuperRClick.git
cd SuperRClick
open SuperRClick.xcodeproj
# Build & Run with Xcode (⌘R)
```

---

## Requirements

- **macOS 15.0 (Sequoia)** or later
- Enable Finder extension in System Settings after first launch

---

## Screenshots

> *Coming soon — Star the repo to stay updated!*

---

## Roadmap

- [ ] Homebrew Cask support (`brew install --cask super-rclick`)
- [ ] Keyboard shortcuts for menu actions
- [ ] Plugin system for user-created extensions
- [ ] Quick Look integration

---

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

---

## Star History

If you find Super RClick useful, please ⭐ star this repo — it helps others discover it!

---

## License

[MIT License](LICENSE)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/CalvinQin">@CalvinQin</a>
</p>

<!-- SEO keywords: macOS right click menu, mac finder extension, finder context menu, mac file manager, batch rename mac, image converter mac, macos productivity tool, finder right click enhancer, 右键菜单增强, mac右键工具, finder扩展, 批量重命名 -->
