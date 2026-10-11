# LogJam

[English](README.md)

LogJam 是一款本地优先的私人文化日志，用来记录电影、书籍和古典音乐。它关注的是“我与这部作品的一次相遇”，而不是建立另一个资料库、评分社区或推荐服务。

本项目免费且开源，不含账户系统、广告、分析追踪、云服务或 App 内购买。

## 主要功能

- 电影、书籍和古典音乐三类日志
- 快速与详细两种记录模板
- 同一作品可关联重看、重读和重复聆听记录
- 编辑和删除已有记录
- 可搜索的首页与资料库
- 自选封面图片，并以不变形的方式裁切显示
- 未选择封面时生成不同类别的抽象图案
- 十分制评分，允许两位小数，并保留隐藏的 11 分彩蛋
- 英文与简体中文界面
- 使用 SwiftData 在设备本地保存
- 可导出和恢复带版本号的 JSON 备份，包括封面图片
- 七项备份与恢复单元测试

## 运行要求

- 可以运行 Xcode 的 Mac
- Xcode 26.6 或兼容的新版本
- 真机运行需要 iOS 17 或更高版本

在模拟器运行，或通过 Personal Team 安装到自己的 iPhone，不需要付费加入 Apple Developer Program。

## 在模拟器运行

1. 克隆或下载本仓库。
2. 使用 Xcode 打开 `LogJam.xcodeproj`。
3. 选择 `LogJam` scheme 和一台 iPhone 模拟器。
4. 按 **Run**（`Command-R`）。

## 免费安装到自己的 iPhone

1. 在 Xcode 中打开 **Settings > Accounts**，登录 Apple Account。
2. 选择 `LogJam` target，再打开 **Signing & Capabilities**。
3. 选择自己的 Personal Team。
4. 将 `com.example.LogJam` 改成你自己的唯一 Bundle Identifier，例如 `com.yourname.LogJam`。
5. 连接 iPhone，将它设为运行设备并按 **Run**。

Apple 的免费 Personal Team 签名会定期失效，届时需要通过 Xcode 重新构建和安装。重新安装或进行可能清除本地数据的操作前，请先在设置中导出日志备份。

## 数据与隐私

LogJam 使用 SwiftData 将日志保存在设备本地，不发送网络请求或分析数据。只有用户明确选择图片时，App 才会导入该图片；只有用户主动导出时，备份文件才会离开 App。

备份可能包含日志文字以及所选封面图片的完整数据，请将导出的 `.json` 文件视为私人数据。完整说明见 [PRIVACY.md](PRIVACY.md)。

## 项目结构

```text
LogJam/
├── LogJam.xcodeproj/       Xcode 工程与共享 scheme
├── LogJam/                 App 源代码
│   ├── LogJamApp.swift
│   ├── Models.swift
│   ├── Persistence.swift
│   └── Views.swift
└── LogJamTests/            备份与恢复测试
```

## 1.0 范围

1.0 版刻意保持本地、iPhone-only。账户、社交功能、作品资料自动查询、CloudKit 同步、更多媒介类别和 iPad 专用布局暂不属于当前范围。

Rooms 标签页仍属于实验界面。Home 是浏览时间线，Library 则以作品为核心，用于查看重复相遇记录。数据模型说明见 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 参与贡献

欢迎提交错误报告、措辞改进、无障碍修复和范围明确的 pull request。提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

LogJam 使用 [MIT License](LICENSE)。
