---
description: 每次代码变更后的完整发布流程
---

# 每次变更必须完成的发布清单

每次修复 bug 或新增功能后，必须**按顺序**完成以下全部步骤：

## 1. 更新版本号
修改 `android/app/build.gradle.kts`:
```
versionCode += 1
versionName = "x.x.x"  # 递增
```

## 2. 更新文档
// turbo
- 在 `CHANGELOG.md` 头部插入新版本条目（日期为今天）
- 覆盖 `RELEASE_LOG.md` 为本次发布说明（只保留当前版本内容）

## 3. 重建 APK（本地验证）
// turbo
```bash
cd /Users/mac/Desktop/douluo/DouluoBridge/android
./gradlew clean app:assembleDebug
```
确认 `BUILD SUCCESSFUL`。

## 4. Commit 并推送代码 + 文档
一次性 commit 所有改动（代码 + build.gradle.kts + CHANGELOG.md + RELEASE_LOG.md）：
```bash
cd /Users/mac/Desktop/douluo/DouluoBridge
git add -A
git commit -m "fix/feat: <描述> + chore: 发布 vX.X.X"
git push origin main
```

## 5. 推送 Git Tag（触发 GitHub Release）
// turbo
```bash
cd /Users/mac/Desktop/douluo/DouluoBridge
git tag vX.X.X
git push origin vX.X.X
```
推送 tag 后，GitHub Actions (`release.yml`) 自动构建 APK 并在 Release 页面发布，
Release 正文从 `RELEASE_LOG.md` 读取。

## 注意事项
- 本地 debug APK 路径：`android/app/build/outputs/apk/debug/app-debug.apk`
- GitHub Release 页：https://github.com/pemagic/DouluoBridge/releases
- 版本号规则：patch 级修复 +0.0.1，功能新增 +0.1.0
