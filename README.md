# 🗡 斗罗大桥：像素剑影 (Douluo Bridge: Pixel Wuxia)

> **Cross-Platform Edition** v1.8.23 — 中国水墨风武侠横版动作游戏 (iOS & Android)

![Launch Screen](ios/DouluoBridge/LaunchImage.png)

## 🎮 游戏简介

《斗罗大桥：像素剑影》是一款融合**中国传统水墨画风**与**像素武侠**元素的横版动作游戏。本项目现已实现 **iOS 与 Android 双端同源**，核心逻辑完全一致。

### ✨ 核心特色

- 🎨 **双端原生渲染** — iOS (SpriteKit) 与 Android (LibGDX) 均采用原生底层驱动，极致流畅。
- ⚔️ **全平台特色同步** — 水墨画风、彩虹天梯、10级武器进化、五大技能、梯度刷怪等均为双端对齐。
- 🎵 **跨平台音效** — 统一的五声音阶古筝旋律，通过原生音频缓冲技术实现。
- 🚀 **一键发布流程** — 统一的版本管理与 CI/CD 自动化流水线。
- 🎨 **水墨画风** — 10 幅手绘水墨背景，宣纸底色、层叠远山、飘渺云雾
- 🌈 **彩虹天梯** — 天空平台七彩斑斓，上下跳跃间穿越彩虹
- ⚔️ **五种敌人** — 侦察兵、追击者、武术家（功夫连招）、重甲兵、狙击手
- 🔥 **五大技能** — 火焰掌、旋风腿、铁布衫、雷击术、幽冥爪
- 🗡 **10 级武器进化** — 木剑 → 万剑归宗，弹幕从单发到全屏扇形
- 👾 **梯度刷怪** — 后期关卡四面八方同时刷新 10+ 怪物，震撼视觉
- 🎵 **古典 BGM** — 程序生成的中国五声音阶古筝旋律
- 📳 **触觉反馈** — iOS 原生震动：命中、击杀、冲锋、必杀技

### 💥 v1.8.23 最新特性与变更
- fix(ios): 剔除 project.pbxproj 中引发原生 SceneDelegate 失效与启动黑屏的 INFOPLIST_KEY 冗余生成配置
### 🏯 十关境界

| 关卡 | 名称 | Boss | 敌人种类 |
|------|------|------|----------|
| 第一关 | 初入江湖 | 山贼头目 | 侦察兵 |
| 第二关 | 崭露锋芒 | 狼王 | 侦察兵、追击者 |
| 第三关 | 拳脚相加 | 铁拳 | 侦察兵、追击者、武术家 |
| 第四关 | 铁甲连城 | 盾将军 | +重甲兵 |
| 第五关 | 百步穿杨 | 幽灵射手 | +狙击手 |
| 第六关 | 刀光剑影 | 双刀客 | 精英组合 |
| 第七关 | 龙争虎斗 | 雷僧 | Tier 3 精英 |
| 第八关 | 万夫莫敌 | 血魔 | Tier 3 精英 |
| 第九关 | 天下无双 | 影魔 | Tier 3 精英 |
| 第十关 | 剑神归位 | 剑圣 | 最终精英 |

### 🗡 武器等级

| 等级 | 武器 | 弹幕 |
|------|------|------|
| Lv.1 | 木剑 | 单发直线 |
| Lv.4 | 玄铁剑 | 三向散射 |
| Lv.7 | 轩辕剑 | 五向扇形 |
| Lv.10 | 万剑归宗 | 全向霓虹弹幕 + 环绕剑阵 |

## 🏗 技术架构

```
┌─────────────────────────────────────┐
│       iOS Native (SpriteKit)        │
│  GameViewController.swift           │
│  ├── SKView + GameScene (渲染引擎)   │
│  ├── VirtualJoystick (虚拟摇杆)      │
│  ├── ActionButton × 4 (动作按钮)     │
│  ├── HUD (血条/能量/击杀/武器等级)    │
│  └── Haptic Feedback (震动反馈)      │
├─────────────────────────────────────┤
│         Game Scene Layer            │
│  GameScene.swift                    │
│  ├── SKCameraNode (相机跟随)         │
│  ├── Background Layer (水墨背景)     │
│  ├── Platform Layer (平台系统)       │
│  ├── Entity Layer (玩家+敌人+弹幕)   │
│  └── Effect Layer (粒子特效)         │
├─────────────────────────────────────┤
│         Entity System               │
│  ├── PlayerNode.swift  (玩家)        │
│  ├── EnemyNode.swift   (敌人AI)      │
│  ├── ProjectileNode.swift (弹幕)     │
│  └── GameConfig.swift  (关卡配置)    │
├─────────────────────────────────────┤
│         Audio Engine                │
│  AudioManager.swift                 │
│  └── AVAudioEngine 程序生成古筝BGM   │
└─────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 |
|------|------|
| 平台 | iOS 16.0+ |
| 语言 | Swift 5 |
| 渲染 | SpriteKit (原生 2D 引擎) |
| 音频 | AVAudioEngine (程序化生成) |
| 震动 | UIImpactFeedbackGenerator |
| UI | UIKit (原生控件) |

## 🚀 构建与运行

### 环境要求

- Xcode 15+
- iOS 16.0+ 模拟器或真机
- macOS Ventura+

### 步骤

```bash
# 1. 克隆仓库
git clone https://github.com/pemagic/DouluoBridge.git

# 2. 打开 Xcode 项目
open DouluoBridge/DouluoBridge.xcodeproj

# 3. 选择目标设备，点击 Run (⌘R)
```

> 无需任何外部依赖，所有资源均内置。

## 📂 项目结构

```
DouluoBridge/
├── DouluoBridge.xcodeproj/        # Xcode 项目配置
├── DouluoBridge/
│   ├── GameScene.swift            # 游戏主循环 (刷怪/碰撞/关卡)
│   ├── GameViewController.swift   # 主控制器 (HUD/菜单/控件)
│   ├── GameConfig.swift           # 10关配置 (敌人/Boss/颜色/BGM)
│   ├── PlayerNode.swift           # 玩家节点 (武器/技能/动画)
│   ├── EnemyNode.swift            # 敌人节点 (AI/武术家/Boss)
│   ├── ProjectileNode.swift       # 弹幕节点 (追踪/生命周期)
│   ├── VirtualJoystick.swift      # 虚拟摇杆组件
│   ├── ActionButton.swift         # 动作按钮组件
│   ├── AudioManager.swift         # 音频引擎 (古筝BGM生成)
│   ├── AppDelegate.swift          # 应用生命周期
│   ├── SceneDelegate.swift        # 场景管理
│   ├── Info.plist                 # 应用配置
│   ├── LaunchImage.png            # 启动画面
│   └── Assets.xcassets/           # 应用图标 + 10幅水墨背景
├── CHANGELOG.md                   # 版本更新日志
├── PRIVACY_POLICY.md              # 隐私政策
└── README.md
```

## 🎮 操控方式

| 操作 | iOS 控件 |
|------|----------|
| 移动 | 虚拟摇杆 (左侧) |
| 跳跃 | ⬆ 跳 按钮 |
| 攻击 | ⚔️ 攻击 按钮 (自动连射) |
| 冲锋 | 🗡 杀 按钮 (3s 冷却) |
| 暂停 | ⏸ 暂停 按钮 |

## 🔒 隐私政策

本游戏**不收集任何个人信息**。详见 [隐私政策](PRIVACY_POLICY.md)。

## 📜 开源协议

MIT License

---

**斗罗大桥：像素剑影** v1.3 — 水墨江湖，剑影纵横 🗡
