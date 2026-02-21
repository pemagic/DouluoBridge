# Changelog

All notable changes to this project will be documented in this file.

## [1.8.1] - 2026-02-21

### CI/CD Fixes
- **GitHub Actions Compatibility**: Removed hardcoded local JDK path from `gradle.properties` to allow the CI environment to use its native `JAVA_HOME`.

## [1.8.0] - 2026-02-21

### Platform Support
- **Android Port**: The game has been successfully ported to Android using Kotlin and LibGDX (`gdx-backend-android`). The core logic (`GameScene.swift`) has been faithfully translated to `DouluoGameScreen.kt` using Object-Oriented Scene2D actors, achieving identical gameplay without WebView dependencies.
- **Automated CI/CD**: Dual-platform GitHub Actions pipeline (`release.yml`) configured to automatically build `.ipa` (macOS) and `.apk` (Ubuntu) upon release tags.

### Build Toolchain & Android Fixes
- **Modernized Environment**: Upgraded Android project to Gradle 8.11.1, Android Gradle Plugin (AGP) 8.7.3, and Kotlin 2.1.0 to ensure compatibility with modern JDK versions (JDK 17 / JDK 25).
- **Gradle Stability**: Refactored `build.gradle.kts` to eliminate configuration cache mutation exceptions during native asset copying.
- **Resource Integrity**: Added necessary `proguard-rules.pro`, `strings.xml`, and dummy `ic_launcher` resources to guarantee successful APK packaging.

## [1.7.0] - 2026-02-20

### Gameplay Balance & New Features
- **子弹贯穿机制**: 玩家子弹现在可以贯穿敌人，贯穿数量等于当前武器等级。每贯穿一次，伤害衰减 10%。
- **无敌时间延长**: 玩家受伤后（不论是接触敌人还是被子弹击中），无敌时间统一延长至 0.4 秒（24帧）。
- **降低血量递增**: 每通关一关的怪物血量倍增系数从 ×3 降至 ×1.5 倍，优化后期关卡体验。
- **武器升级曲线调整**: 每一关的武器等级上限全部 +1（例如第一关上限为3级，第二关为4级），同时大幅提高前几关的武器掉落概率，确保玩家能平滑升至当前关卡上限。
- **优化刷怪节奏**: 调低了前几关的刷怪冷却时间下限，使早期关卡怪物出现更加紧密。

### Performance & Visual Fixes
- **背景特效与渲染**: 修复了背景图渲染和颜色割裂问题，更新了 10 张游戏背景图。彻底移除了背景图的半透明效果，改为使用 `colorBlendFactor` 提亮背景。
- **UI 及平台环境**: 地面和悬浮平台恢复了半透明状态，增加了质感。同时移除了界面中用于测试的清关按钮。
- **性能优化进阶**: 
  - 加入 O(1) 计数器重构敌人子弹统计，避免每帧 O(n×m) 的性能瓶颈。
  - 增加严苛的同屏防拉扯硬上限：怪物同屏上限 25，玩家子弹上限 80，敌人子弹上限 30，粒子特效上限 100。
- **错误修复**: 移除了出现异常“长白线”的渲染逻辑（原狙击手瞄准线，受缩放影响出现拉扯翻转）。

## [1.6.2] - 2026-02-20
- **怪物血量递增 (HP Scaling)**: 每通关一关，下一关所有怪物（含 Boss）血量增加 3 倍。第 1 关为基础血量，第 2 关 ×3，第 3 关 ×9，以此类推，大幅提升后期关卡挑战难度。

### Performance Optimizations (深度优化)
- **敌人渲染重构**: 将每个敌人 15-30 个 `SKShapeNode`（火柴人各部位）合并为 1 个 `SKSpriteNode`，使用 `CoreGraphics` 预渲染纹理。30+ 怪物同屏从 500+ draw calls 降至 ~30。
- **子弹纹理缓存**: `ProjectileNode` 从 `SKShapeNode` + `glowWidth` 改为缓存的 `SKSpriteNode` 纹理，按 owner/size/color 缓存避免重复渲染。
- **粒子系统优化**: 粒子从 `SKShapeNode` 改为缓存的 `SKSpriteNode` 纹理，新增 200 粒子并发上限防止帧率崩溃。
- **护盾/必杀特效缓存**: `PlayerNode` 护盾光圈和必杀光效由每帧创建/销毁 `SKShapeNode` 改为预渲染 `SKSpriteNode` 切换可见性。
- **Boss 血条优化**: Boss 血条从 `SKShapeNode` 改为 `SKSpriteNode`。
- **狙击手瞄准线缓存**: 瞄准线 alpha 量化为 5 级，仅在等级变化时重新渲染。
- **子弹数量上限**: 新增 150 发子弹同屏上限，防止高武器等级下 GPU 过载。

## [1.5.2] - 2026-02-19

### Improvements
- **技能掉落修复 (Fix Skill Drops)**: 修复了后期连击数高时，因概率计算溢出导致技能包无法掉落的问题 (Independent 30% roll)。
- **技能追踪 (Homing Skills)**: 火焰掌 (Fire) 和 旋风腿 (Whirlwind) 现在会自动追踪最近的敌人。

## [1.5.1] - 2026-02-19

### Optimizations
- **性能优化 (Performance)**: 重构平台渲染逻辑 (SKSpriteNode 替代 SKShapeNode)，彻底消除开局与关卡切换卡顿。
- **技能释放逻辑 (Instant Cast)**: 拾取技能后立即自动释放一次，且不触发冷却 (Manual cast unchanged)。

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
