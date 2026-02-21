# 更新日志 (Changelog)

本项目的所有重大变更都将记录在此文件中。

## [1.8.5] - 2026-02-21

### 安卓端根本性修复 (Android Root-cause Fix)
- **所有渲染 bug 根因修复**：`startGame()` 在 UI 线程 `OnClickListener` 里直接调用，导致内部 `generatePlatforms()` + `drawBackground()` 创建所有 `Pixmap/Texture`（GL 操作）在错误线程执行，造成背景丢失、平台不显示、所有视觉元素渲染失败。现改为 `Gdx.app.postRunnable { startGame() }`，确保在 GL 线程执行。
- **修复范围**：开始游戏按钮、游戏结束重开按钮、暂停继续按钮，全部改为 `postRunnable`。
- **配合 v1.8.4**：功能按钮（攻击/跳跃/冲刺/技能）同样修复，所有 UI → 游戏逻辑调用现在全部在 GL 线程安全执行。

## [1.8.4] - 2026-02-21

### 安卓端关键 Bug 修复 (Android Critical Fixes)
- **攻击按钮崩溃修复**：`ProjectileTextureCache` / `EnemyFrameCache` 在 GL 上下文重建后持有无效 Texture 导致崩溃，现在 `DouluoGame.resume()` 自动清空缓存按需重建。
- **并发修改异常修复**：`updateProjectiles()` 遍历敌人时不再直接 `enemies.remove()`，消除 `ConcurrentModificationException`。
- **游戏背景恢复**：背景图缺失时改为自动使用关卡主题色渐变（与 iOS 行为一致），不再全黑。
- **平台渲染修复**：地面块改为仅显示 4px 顶边线（不渲染实心矩形），天空/高空平台改为 8 色彩虹，补齐 iOS 原有的第 4 层高空平台（30% 概率）。
- **视口黑边修复**：`FitViewport` 改为 `ExtendViewport`，消除宽屏手机侧边黑条。
- **强制横屏与全屏**：`AndroidLauncher` 新增强制横屏 + 沉浸式全屏（隐藏系统状态栏/导航栏）。

### 修复与工作流优化 (CI/CD Fixes)
- **安卓安装修复**：修复了 GitHub Actions 生成的 APK 无法安装的问题。正式版编译使用 `debug` 签名，确保内测版可直接安装。
- **本地强制校验**：`release.sh` 发布前强制执行本地构建与安卓设备安装测试。
- **环境对齐**：对齐了本地与云端的 JDK 17 构建环境。
- **安卓安装修复**：修复了 GitHub Actions 生成的 APK 无法安装的问题。现在正式版编译也会使用 `debug` 签名，确保内测版可直接安装。
- **本地强制校验**：更新了 `release.sh` 发布脚本。现在发布前会**强制执行本地构建与安卓设备安装测试**，只有在真实设备/模拟器上验证通过后，才会允许执行 Git 同步与 Tag 推送。
- **环境对齐**：对齐了本地与云端的 JDK 17 构建环境，确保“所测即所得”。

## [1.8.3] - 2026-02-21

### 文档与国际化 (Localization)
- **全面中文化**：将 `CHANGELOG.md` 及 GitHub Release 日志全面转换为中文，确保国内开发者与用户阅读更友好。
- **记忆锁定**：在项目知识库中锁定了“使用中文记录日志”的规则，确保未来所有自动生成的发布说明均使用中文。

## [1.8.2] - 2026-02-21

### 发布自动化
- **全自动描述提取**：实现了从 `CHANGELOG.md` 中自动提取当前版本说明的功能，生成的 `RELEASE_LOG.md` 会被推送到远程。
- **直接正文填充**：配置了 GitHub Actions 直接读取 `RELEASE_LOG.md` 并将其“贴入” GitHub Release 正文，不再使用自动引用的方式，确保中文日志完美展现。

## [1.8.1] - 2026-02-21

### CI/CD 修复
- **GitHub Actions 兼容性优化**：移除了 `gradle.properties` 中硬编码的本地 JDK 路径，解决了云端 Linux 环境下找不到 Java Home 导致的编译失败问题。

## [1.8.0] - 2026-02-21

### 平台支持
- **安卓端移植**：使用 Kotlin 和 LibGDX (`gdx-backend-android`) 成功将游戏移植到安卓平台。核心逻辑（由 `GameScene.swift` 翻译至 `DouluoGameScreen.kt`）采用了 Scene2D Actor 架构，实现了 1:1 的原生还原，不依赖任何 WebView。
- **自动化 CI/CD**：配置了双端 GitHub Actions 流水线 (`release.yml`)，在推送版本标签时自动在 macOS 编译 `.ipa`、在 Ubuntu 编译 `.apk`。

### 构建工具链与安卓修复
- **环境现代化**：将安卓项目升级至 Gradle 8.11.1、AGP 8.7.3 和 Kotlin 2.1.0，确保与最新 JDK (17/25) 的完美兼容。
- **构建稳定性**：重构了 `build.gradle.kts`，解决了原生资源复制过程中的配置缓存变动异常。
- **资源完整性**：添加了必要的 `proguard-rules.pro`、`strings.xml` 以及图标资源，确保 APK 打包万无一无。

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
