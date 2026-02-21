### 安卓端关键 Bug 修复 (Android Critical Fixes) - v1.8.4
- **攻击按钮崩溃修复**：`ProjectileTextureCache` / `EnemyFrameCache` 在 GL 上下文重建后持有无效 Texture 导致崩溃，现在 `DouluoGame.resume()` 自动清空缓存按需重建。
- **并发修改异常修复**：`updateProjectiles()` 遍历敌人时不再直接 `enemies.remove()`，消除 `ConcurrentModificationException`。
- **游戏背景恢复**：背景图缺失时改为自动使用关卡主题色渐变（与 iOS 行为一致），不再全黑。
- **平台渲染修复**：地面块改为仅显示 4px 顶边线（不渲染实心矩形），天空/高空平台改为 8 色彩虹，补齐 iOS 原有的第 4 层高空平台（30% 概率）。
- **视口黑边修复**：`FitViewport` 改为 `ExtendViewport`，消除宽屏手机侧边黑条。
- **强制横屏与全屏**：`AndroidLauncher` 新增强制横屏 + 沉浸式全屏（隐藏系统状态栏/导航栏）。
- **安卓安装修复**：正式版编译使用 `debug` 签名，确保内测版可直接安装。
