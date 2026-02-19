# Changelog

All notable changes to this project will be documented in this file.

## [1.5] - 2026-02-19

### New Features
- **技能掉落系统 (Skill Drops)**: 击杀敌人有 30% 概率掉落技能书/符文，拾取可解锁或升级技能。
- **多彩天空楼梯 (Colorful Platforms)**: 根据关卡不同，悬浮楼梯呈现多彩色 (Levels 3-10)，增强视觉深度。
- **护盾技能视觉 (Shield Visual)**: 激活护盾时显示金色光圈特效。
- **UI 优化**: 技能获取提示改为顶部非阻塞式横幅。

### Fixed
- 修复 **护盾技能** 无效的问题 (Shield logic against Chaser/Projectiles)。
- 修复 **冲刺技能 (Dash/Kill)** 无法造成伤害的问题 (Added collision damage)。
- 修复 **必杀技 (Ultimate)** 无法造成伤害的问题 (Added AOE damage logic)。
- 修复 **背景音乐 (BGM)** 在拾取技能时被重置的问题。
- 修复 **游戏开始时** 缺少 Level 1 关卡提示横幅的问题。

### Changed
- 增加了所有视觉元素的色彩深度 (Darkened by 40%) 以增强质感。
- 调整了掉落概率平衡 (Weapon deficit scaling + Skill 30%)。

## [1.3] - 2026-02-19

### Fixed
- **怪物刷新根因修复**：
    - 离屏清理的怪物现在计入 `levelKills`，修复击杀计数泄漏导致关卡永远无法推进的根本问题
    - Boss 离屏后重置 `bossActive`/`bossSpawned` 状态，防止 Boss 丢失后刷怪永久停滞
    - 增加 300 帧安全计时器：即使 Boss 状态异常也能自动恢复
    - 移除 `updateEnemies()` 中重复的死亡检查代码
- **刷怪空窗期修复**：当场上无怪物且关卡未完成时，立即重置冷却时间强制刷新

### Added
- **彩虹天空阶梯**：天空和高处平台改为 8 色彩虹循环（红橙黄绿青蓝紫粉），视觉效果更加炫彩
- **梯度刷怪系统**：
    - 最大怪物数 = `10 + 关卡×3 + 武器等级×3`（最高 70 只同屏）
    - 第 7 关起四面八方刷新（左、右、上方、对角线）
    - 高关卡每次冷却批量刷新最多 4 只怪物
    - 刷新冷却随关卡和武器等级加速：`max(3, 35 - 关卡×2 - 武器×2)` 帧

### Changed
- **武器升级平滑化**：
    - 严格执行每关 `weaponCap` 上限（第1关上限Lv.2，第10关上限Lv.10）
    - 基于差值的掉率公式：武器等级低于当前关卡上限时掉率更高，达到上限后几乎不掉
    - 每关约升 1 级武器，全程平滑递进到最终关
- **离屏清理阈值收紧**：从 2200px 缩减到 1600px，防止远处不可见怪物占满上限
- **性能优化**：`EnemyNode.drawStickFigure()` 从每帧调用改为每 3 帧一次（动画相位量化），大幅减少 SKShapeNode 反复创建销毁的开销

---

## [1.2] - 2026-02-18

### Architecture
- **纯原生重构**：从 WKWebView + HTML5 Canvas 混合架构迁移到纯 SpriteKit 原生渲染
    - 移除 `douluo_ios.html` 和 JavaScript 依赖
    - 新增 `GameScene.swift`、`PlayerNode.swift`、`EnemyNode.swift`、`ProjectileNode.swift`、`GameConfig.swift`
    - 游戏逻辑、渲染、物理碰撞全部用 Swift/SpriteKit 重写

### Added
- **水墨背景**：集成 10 幅关卡专属水墨画风背景（`bg_level_1` ~ `bg_level_10`）
- **暂停按钮**：右上角 ⏸ 暂停功能
- **音频引擎**：`AudioManager.swift` 使用 AVAudioEngine 程序化生成古筝 BGM（10 首各 60-80 音符）
- **敌人 AI**：
    - 随机跳跃行为（着地时 1% 概率跳跃以导航平台）
    - 360° 瞄准射击（Scout、Heavy、Sniper）
- **冲锋按钮冷却可视化**

### Changed
- **UI 改进**：
    - 关卡名称标签移至武器等级下方，深色文字
    - 击杀计数器重新定位避免与控制按钮重叠
    - 虚拟控件按钮透明度从 0.25 提高到 0.7
    - 暂停/返回按钮移除圆形边框
    - 隐藏 SpriteKit 调试统计信息
- **相机**：Y 轴偏移 +200，保持角色可见同时展示水墨背景
- **平台生成**：高度调整以适配新相机视角

### Removed
- 移除必杀技（必）单独按钮
- 移除测试用作弊（☠️）按钮
- 修复关卡间 BGM 切换异常

---

## [1.1] - 2026-02-17

### Initial Release (HTML Version)
- **混合架构**：WKWebView + HTML5 Canvas + JavaScript 游戏引擎
- **游戏核心**：10 关卡、5 种敌人、10 级武器进化、Boss 战
- **水墨画风**：CSS 渐变实现的中国水墨背景
- **五声音阶 BGM**：Web Audio API 程序生成古筝旋律
- **iOS 原生控件**：虚拟摇杆 + 动作按钮覆盖在 WebView 上
- **触觉反馈**：通过 WKScriptMessageHandler 桥接 iOS 原生震动
