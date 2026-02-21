---
description: Automatically sync versions and trigger a cross-platform release
---
# 发版标准作业流程

每次进行代码变更后，严格执行本工作流完成双发行版构建：

## 1. 版本号对齐 (严禁破坏 JSON 括号与配置结构)
- Android：修改 `android/app/build.gradle.kts` 的 `versionCode` 和 `versionName`
- iOS：修改 `ios/DouluoBridge.xcodeproj/project.pbxproj`，精确搜索并修改 `CURRENT_PROJECT_VERSION` 与 `MARKETING_VERSION`（勿加无用资源路径验证如 DEVELOPMENT_ASSET_PATHS）。

## 2. 自动化发版
// turbo
```bash
python3 scripts/publish_release.py
```

## 🚨 强制红线：
- **禁止修改 README**（已被脚本接管）。
- **禁止操作 RELEASE_LOG.md**（已废弃移除）。
