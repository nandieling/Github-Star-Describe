# Github-Star-Describe

![Platform](https://img.shields.io/badge/Platform-macOS%2014.0+-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Framework](https://img.shields.io/badge/UI-SwiftUI-blue.svg)
![Data](https://img.shields.io/badge/Data-SwiftData-red.svg)

**Github-Star-Describe** 是一款专为 macOS 打造的原生桌面应用程序。它不仅能一键同步你的 GitHub 标星 (Starred) 仓库，还能让你为每个仓库添加**专属的中文功能描述与备忘笔记**。从此告别“标星如吃灰，用时找不到”的烦恼！

![](https://pixhost.to/show/6685/707867283_2026-03-25-15-32-27.png)

## ✨ 核心功能

- **🔄 智能双向同步**：输入 GitHub 用户名即可全量拉取 Star 列表。支持获取真实“标星时间”，并在每次同步后智能清理已取消标星的失效记录，保持数据纯净。
- **📝 专属功能备忘**：支持为每个仓库编写个人的“功能描述”，数据通过 `SwiftData` 安全保存在本地。
- **🔍 全局极速搜索**：支持对仓库名、自定义描述、原作者描述、编程语言进行多维度模糊搜索。
- **🗂️ 高级视图与排序**：
  - 提供现代化的“卡片瀑布流”与紧凑的“列表视图”无缝切换。
  - 支持 6 种维度的动态排序：名称 (A-Z)、Star 热度、**标星时间 (新到旧/旧到新)**。
- **🎨 深度个性化外观**：
  - **五大色彩主题**：系统默认、深海蓝、极光绿、暖阳橙、薰衣草紫，完美适配 Mac 的深色/浅色模式。
  - **沉浸式自定义背景**：支持选取本地图片作为背景，并可自由滑动调节背景透明度，配以原生的毛玻璃 (Material) 视效。
- **📦 数据安全与流转**：
  - 提供**一键导出/导入备份**功能。你可以将辛辛苦苦写下的中文描述打包成轻量级 JSON 文件，在不同的 Mac 设备间无缝迁移你的知识库。

## 🛠️ 技术栈与底层实现

本项目采用 Apple 最现代的开发框架构建，完全遵循 macOS 平台设计规范：
- **UI 架构**: `SwiftUI` (打造流畅的网格/列表布局与原生 Popover/Sheet 弹窗)
- **本地数据库**: `SwiftData` (基于模型驱动的新一代数据持久化方案)
- **网络层**: `URLSession` + `async/await` (异步并发拉取 GitHub REST API，解析特定 Header 的时间戳)
- **系统集成**: 
  - `@AppStorage`: 轻量级偏好设置存储。
  - `FileDocument` & `UniformTypeIdentifiers`: 原生沙盒机制下的文件选择、读取与写入 (图片及 JSON)。

## 🚀 安装与运行

### 方式一：直接运行成品包 (推荐)
1. 在 [Releases 页面](#) 下载最新的 `Github-Star-Describe.dmg` 。
2. 解压并将 `Github-Star-Describe` 拖入你的「应用程序 (Applications)」文件夹。
3. **首次运行注意**：由于是独立开发者未签名版本，首次打开请对着软件图标**右键 -> 选择“打开”**。

