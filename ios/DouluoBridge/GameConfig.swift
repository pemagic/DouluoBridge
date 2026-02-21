import SpriteKit
import UIKit

// MARK: - Physics Constants
struct Physics {
    static let gravity: CGFloat = 1.3
    static let playerSpeed: CGFloat = 14
    static let jumpForce: CGFloat = 25     // positive = up in SpriteKit
    static let dashForce: CGFloat = 52
    static let gameWidth: CGFloat = 1600
    static let gameHeight: CGFloat = 900
}

// MARK: - Skill Definition
struct SkillDef {
    let id: String
    let name: String
    let emoji: String
    let color: UIColor
    let keyCode: String
    let baseCooldown: Int
    let baseDamage: Int
    let baseDuration: Int // only for shield
}

// MARK: - Skill State
class SkillState {
    var level: Int = 0
    var cooldown: Int = 0
    var active: Int = 0  // for shield
}

// MARK: - Enemy Type
enum EnemyType: String, CaseIterable {
    case scout
    case chaser
    case martial
    case heavy
    case sniper
}

// MARK: - Boss Type
enum BossType: String {
    case banditChief = "bandit_chief"
    case wolfKing = "wolf_king"
    case ironFist = "iron_fist"
    case shieldGeneral = "shield_general"
    case phantomArcher = "phantom_archer"
    case twinBlade = "twin_blade"
    case thunderMonk = "thunder_monk"
    case bloodDemon = "blood_demon"
    case shadowLord = "shadow_lord"
    case swordSaint = "sword_saint"
}

// MARK: - Level Color Config
struct LevelColors {
    let bgColors: [UIColor]
    let mountainColors: [UIColor]
    let enemyColors: [UIColor]
    let platformGround: [UIColor]
    let platformFloat: [UIColor]
}

// MARK: - BGM Config
struct BGMConfig {
    let droneFreq: Float
    let filterCutoff: Float
    let volume: Float
    let songId: Int
}

// MARK: - Level Definition
struct LevelDef {
    let name: String
    let killTarget: Int
    let weaponCap: Int
    let enemyTier: Int
    let enemies: [EnemyType]
    let bossHp: Int
    let bossSpeed: CGFloat
    let bossType: BossType
    let colors: LevelColors
    let bgm: BGMConfig
}

// MARK: - Game Config
struct GameConfig {
    
    // Skill Definitions
    static let skillDefs: [SkillDef] = [
        SkillDef(id: "fire", name: "火焰掌", emoji: "🔥",
                 color: UIColor(red: 1.0, green: 0.27, blue: 0, alpha: 1),
                 keyCode: "KeyQ", baseCooldown: 120, baseDamage: 40, baseDuration: 0),
        SkillDef(id: "whirlwind", name: "旋风腿", emoji: "🌀",
                 color: UIColor(red: 0, green: 0.8, blue: 1, alpha: 1),
                 keyCode: "KeyE", baseCooldown: 150, baseDamage: 30, baseDuration: 0),
        SkillDef(id: "shield", name: "铁布衫", emoji: "🛡",
                 color: UIColor(red: 1, green: 0.8, blue: 0, alpha: 1),
                 keyCode: "KeyR", baseCooldown: 300, baseDamage: 0, baseDuration: 60),
        SkillDef(id: "lightning", name: "雷击术", emoji: "⚡",
                 color: UIColor(red: 0.67, green: 0.4, blue: 1, alpha: 1),
                 keyCode: "KeyT", baseCooldown: 180, baseDamage: 60, baseDuration: 0),
        SkillDef(id: "ghost", name: "幽冥爪", emoji: "💀",
                 color: UIColor(red: 0.2, green: 1, blue: 0.53, alpha: 1),
                 keyCode: "KeyY", baseCooldown: 200, baseDamage: 50, baseDuration: 0),
    ]
    
    // Helper to create UIColor from hex string component values
    private static func c(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
    
    // 10 Level Definitions
    static let levels: [LevelDef] = [
        // Level 1: 初入江湖
        LevelDef(
            name: "第一关·初入江湖", killTarget: 15, weaponCap: 3, enemyTier: 1,
            enemies: [.scout], bossHp: 600, bossSpeed: 1.0, bossType: .banditChief,
            colors: LevelColors(
                bgColors: [c("#e8dcc8"), c("#d8ccb4"), c("#c8b89a"), c("#b0a080")],
                mountainColors: [c("#7a9a6a"), c("#8aaa7a"), c("#6a8a5a")],
                enemyColors: [c("#6a8844"), c("#7a9954"), c("#5a7744"), c("#88aa66"), c("#779944")],
                platformGround: [c("#c8b99a"), c("#b8a88a"), c("#d4c4a8")],
                platformFloat: [c("#a09080"), c("#90806a"), c("#c0b090")]
            ),
            bgm: BGMConfig(droneFreq: 49.0, filterCutoff: 2500, volume: 0.04, songId: 0)
        ),
        // Level 2: 崭露锋芒
        LevelDef(
            name: "第二关·崭露锋芒", killTarget: 20, weaponCap: 4, enemyTier: 1,
            enemies: [.scout, .chaser], bossHp: 900, bossSpeed: 1.1, bossType: .wolfKing,
            colors: LevelColors(
                bgColors: [c("#dce8d0"), c("#c8d8bc"), c("#b4c8a0"), c("#a0b888")],
                mountainColors: [c("#6a8a6a"), c("#7a9a7a"), c("#5a7a5a")],
                enemyColors: [c("#88aa44"), c("#77994e"), c("#669944"), c("#99bb55"), c("#88aa55")],
                platformGround: [c("#b8c8a0"), c("#a8b890"), c("#c4d4a8")],
                platformFloat: [c("#90a080"), c("#80906a"), c("#b0c090")]
            ),
            bgm: BGMConfig(droneFreq: 49.0, filterCutoff: 2400, volume: 0.04, songId: 1)
        ),
        // Level 3: 拳脚相加
        LevelDef(
            name: "第三关·拳脚相加", killTarget: 25, weaponCap: 5, enemyTier: 1,
            enemies: [.scout, .chaser, .martial], bossHp: 1200, bossSpeed: 1.2, bossType: .ironFist,
            colors: LevelColors(
                bgColors: [c("#e0c8a0"), c("#d0b890"), c("#c0a878"), c("#aa9060")],
                mountainColors: [c("#8a7050"), c("#9a8060"), c("#7a6040")],
                enemyColors: [c("#aa7744"), c("#996644"), c("#bb8855"), c("#cc9966"), c("#aa8844")],
                platformGround: [c("#c0a880"), c("#b09870"), c("#d0b890")],
                platformFloat: [c("#ff9900"), c("#ffcc00"), c("#ffee44")] // Orange/Yellow
            ),
            bgm: BGMConfig(droneFreq: 46.2, filterCutoff: 2200, volume: 0.042, songId: 2)
        ),
        // Level 4: 铁甲连城
        LevelDef(
            name: "第四关·铁甲连城", killTarget: 30, weaponCap: 6, enemyTier: 2,
            enemies: [.scout, .chaser, .martial, .heavy], bossHp: 1600, bossSpeed: 1.3, bossType: .shieldGeneral,
            colors: LevelColors(
                bgColors: [c("#c8d0d8"), c("#b0b8c8"), c("#98a0b0"), c("#808898")],
                mountainColors: [c("#707888"), c("#606878"), c("#808898")],
                enemyColors: [c("#5588aa"), c("#4477aa"), c("#6699bb"), c("#5599cc"), c("#4488aa")],
                platformGround: [c("#a0a8b8"), c("#9098a8"), c("#b0b8c8")],
                platformFloat: [c("#8800ff"), c("#9933ff"), c("#aa66ff")] // Purple/Violet
            ),
            bgm: BGMConfig(droneFreq: 41.2, filterCutoff: 1800, volume: 0.045, songId: 3)
        ),
        // Level 5: 百步穿杨
        LevelDef(
            name: "第五关·百步穿杨", killTarget: 35, weaponCap: 7, enemyTier: 2,
            enemies: [.scout, .chaser, .martial, .heavy, .sniper], bossHp: 2000, bossSpeed: 1.4, bossType: .phantomArcher,
            colors: LevelColors(
                bgColors: [c("#c8a878"), c("#b89868"), c("#a08050"), c("#886838")],
                mountainColors: [c("#705030"), c("#604020"), c("#805838")],
                enemyColors: [c("#886644"), c("#775533"), c("#997755"), c("#aa8866"), c("#887755")],
                platformGround: [c("#a08060"), c("#907050"), c("#b09070")],
                platformFloat: [c("#00cc00"), c("#33dd33"), c("#66ee66")] // Green/Lime
            ),
            bgm: BGMConfig(droneFreq: 41.2, filterCutoff: 1500, volume: 0.048, songId: 4)
        ),
        // Level 6: 刀光剑影
        LevelDef(
            name: "第六关·刀光剑影", killTarget: 40, weaponCap: 8, enemyTier: 2,
            enemies: [.chaser, .martial, .heavy, .sniper], bossHp: 2500, bossSpeed: 1.5, bossType: .twinBlade,
            colors: LevelColors(
                bgColors: [c("#4a5568"), c("#3a4558"), c("#2a3548"), c("#1a2538")],
                mountainColors: [c("#2a3a50"), c("#1a2a40"), c("#3a4a60")],
                enemyColors: [c("#7755aa"), c("#6644aa"), c("#8866bb"), c("#9977cc"), c("#7766aa")],
                platformGround: [c("#505868"), c("#404858"), c("#606878")],
                platformFloat: [c("#ff0066"), c("#ff3388"), c("#ff66aa")] // Pink/Red
            ),
            bgm: BGMConfig(droneFreq: 36.7, filterCutoff: 1200, volume: 0.05, songId: 5)
        ),
        // Level 7: 龙争虎斗
        LevelDef(
            name: "第七关·龙争虎斗", killTarget: 45, weaponCap: 9, enemyTier: 3,
            enemies: [.martial, .heavy, .sniper, .chaser], bossHp: 3200, bossSpeed: 1.7, bossType: .thunderMonk,
            colors: LevelColors(
                bgColors: [c("#3a2848"), c("#2a1838"), c("#1a0828"), c("#100018")],
                mountainColors: [c("#2a1848"), c("#1a0838"), c("#3a2858")],
                enemyColors: [c("#aa3344"), c("#993355"), c("#bb4455"), c("#cc5566"), c("#aa4466")],
                platformGround: [c("#3a2838"), c("#2a1828"), c("#4a3848")],
                platformFloat: [c("#ffcc00"), c("#ffee00"), c("#ffff44")] // Gold/Yellow (Electric)
            ),
            bgm: BGMConfig(droneFreq: 36.7, filterCutoff: 1000, volume: 0.052, songId: 6)
        ),
        // Level 8: 万夫莫敌
        LevelDef(
            name: "第八关·万夫莫敌", killTarget: 50, weaponCap: 10, enemyTier: 3,
            enemies: [.martial, .heavy, .sniper], bossHp: 4000, bossSpeed: 1.9, bossType: .bloodDemon,
            colors: LevelColors(
                bgColors: [c("#3a1010"), c("#2a0808"), c("#1a0000"), c("#100000")],
                mountainColors: [c("#3a0808"), c("#2a0000"), c("#4a1010")],
                enemyColors: [c("#cc2222"), c("#bb1133"), c("#dd3344"), c("#ee4455"), c("#cc3355")],
                platformGround: [c("#3a1818"), c("#2a0808"), c("#4a2020")],
                platformFloat: [c("#ff0000"), c("#dd0000"), c("#bb0000")] // Deep Red
            ),
            bgm: BGMConfig(droneFreq: 32.7, filterCutoff: 800, volume: 0.055, songId: 7)
        ),
        // Level 9: 天下无双
        LevelDef(
            name: "第九关·天下无双", killTarget: 55, weaponCap: 10, enemyTier: 3,
            enemies: [.martial, .heavy, .sniper], bossHp: 5000, bossSpeed: 2.1, bossType: .shadowLord,
            colors: LevelColors(
                bgColors: [c("#101828"), c("#081018"), c("#000810"), c("#000008")],
                mountainColors: [c("#081830"), c("#001020"), c("#102040")],
                enemyColors: [c("#4466cc"), c("#3355bb"), c("#5577dd"), c("#6688ee"), c("#4477cc")],
                platformGround: [c("#182028"), c("#101818"), c("#202830")],
                platformFloat: [c("#0000ff"), c("#2222ff"), c("#4444ff")] // Deep Blue
            ),
            bgm: BGMConfig(droneFreq: 32.7, filterCutoff: 600, volume: 0.058, songId: 8)
        ),
        // Level 10: 剑神归位
        LevelDef(
            name: "第十关·剑神归位", killTarget: 60, weaponCap: 10, enemyTier: 3,
            enemies: [.martial, .heavy, .sniper], bossHp: 7000, bossSpeed: 2.5, bossType: .swordSaint,
            colors: LevelColors(
                bgColors: [c("#0a0a10"), c("#050508"), c("#020204"), c("#000000")],
                mountainColors: [c("#0a0a18"), c("#050510"), c("#101020")],
                enemyColors: [c("#ccccdd"), c("#bbbbcc"), c("#ddddee"), c("#ffffff"), c("#aaaacc")],
                platformGround: [c("#101018"), c("#080810"), c("#181820")],
                platformFloat: [c("#ffffff"), c("#eeeeee"), c("#dddddd")] // White/Silver
            ),
            bgm: BGMConfig(droneFreq: 27.5, filterCutoff: 500, volume: 0.06, songId: 9)
        ),
    ]
    
    // MARK: - Weapon Names by Level
    static let weaponNames = [
        "木剑", "铁剑", "钢剑", "玄铁剑", "碧血剑",
        "倚天剑", "屠龙刀", "轩辕剑", "干将莫邪", "万剑归宗"
    ]
}
