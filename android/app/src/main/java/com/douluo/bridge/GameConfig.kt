package com.douluo.bridge

import com.badlogic.gdx.graphics.Color

object Physics {
    const val gravity: Float = 1.3f
    const val playerSpeed: Float = 14f
    const val jumpForce: Float = 25f     // positive = up in libGDX (like SpriteKit)
    const val dashForce: Float = 52f
    const val gameWidth: Float = 1600f
    const val gameHeight: Float = 900f
}

data class SkillDef(
    val id: String,
    val name: String,
    val emoji: String,
    val color: Color,
    val keyCode: String,
    val baseCooldown: Int,
    val baseDamage: Int,
    val baseDuration: Int // only for shield
)

class SkillState {
    var level: Int = 0
    var cooldown: Int = 0
    var active: Int = 0  // for shield
}

enum class EnemyType(val key: String) {
    SCOUT("scout"),
    CHASER("chaser"),
    MARTIAL("martial"),
    HEAVY("heavy"),
    SNIPER("sniper")
}

enum class BossType(val key: String) {
    BANDIT_CHIEF("bandit_chief"),
    WOLF_KING("wolf_king"),
    IRON_FIST("iron_fist"),
    SHIELD_GENERAL("shield_general"),
    PHANTOM_ARCHER("phantom_archer"),
    TWIN_BLADE("twin_blade"),
    THUNDER_MONK("thunder_monk"),
    BLOOD_DEMON("blood_demon"),
    SHADOW_LORD("shadow_lord"),
    SWORD_SAINT("sword_saint")
}

data class LevelColors(
    val bgColors: List<Color>,
    val mountainColors: List<Color>,
    val enemyColors: List<Color>,
    val platformGround: List<Color>,
    val platformFloat: List<Color>
)

data class BGMConfig(
    val droneFreq: Float,
    val filterCutoff: Float,
    val volume: Float,
    val songId: Int
)

data class LevelDef(
    val name: String,
    val killTarget: Int,
    val weaponCap: Int,
    val enemyTier: Int,
    val enemies: List<EnemyType>,
    val bossHp: Int,
    val bossSpeed: Float,
    val bossType: BossType,
    val colors: LevelColors,
    val bgm: BGMConfig
)

object GameConfig {

    val skillDefs: List<SkillDef> = listOf(
        SkillDef("fire", "火焰掌", "🔥", Color(1.0f, 0.27f, 0f, 1f), "KeyQ", 120, 40, 0),
        SkillDef("whirlwind", "旋风腿", "🌀", Color(0f, 0.8f, 1f, 1f), "KeyE", 150, 30, 0),
        SkillDef("shield", "铁布衫", "🛡", Color(1f, 0.8f, 0f, 1f), "KeyR", 300, 0, 60),
        SkillDef("lightning", "雷击术", "⚡", Color(0.67f, 0.4f, 1f, 1f), "KeyT", 180, 60, 0),
        SkillDef("ghost", "幽冥爪", "💀", Color(0.2f, 1f, 0.53f, 1f), "KeyY", 200, 50, 0)
    )

    private fun c(hex: String): Color {
        return Color.valueOf(hex.replace("#", ""))
    }

    val levels: List<LevelDef> = listOf(
        // Level 1: 初入江湖
        LevelDef(
            name = "第一关·初入江湖", killTarget = 15, weaponCap = 3, enemyTier = 1,
            enemies = listOf(EnemyType.SCOUT), bossHp = 600, bossSpeed = 1.0f, bossType = BossType.BANDIT_CHIEF,
            colors = LevelColors(
                bgColors = listOf(c("#e8dcc8"), c("#d8ccb4"), c("#c8b89a"), c("#b0a080")),
                mountainColors = listOf(c("#7a9a6a"), c("#8aaa7a"), c("#6a8a5a")),
                enemyColors = listOf(c("#6a8844"), c("#7a9954"), c("#5a7744"), c("#88aa66"), c("#779944")),
                platformGround = listOf(c("#c8b99a"), c("#b8a88a"), c("#d4c4a8")),
                platformFloat = listOf(c("#a09080"), c("#90806a"), c("#c0b090"))
            ),
            bgm = BGMConfig(droneFreq = 49.0f, filterCutoff = 2500f, volume = 0.04f, songId = 0)
        ),
        // Level 2: 崭露锋芒
        LevelDef(
            name = "第二关·崭露锋芒", killTarget = 20, weaponCap = 4, enemyTier = 1,
            enemies = listOf(EnemyType.SCOUT, EnemyType.CHASER), bossHp = 900, bossSpeed = 1.1f, bossType = BossType.WOLF_KING,
            colors = LevelColors(
                bgColors = listOf(c("#dce8d0"), c("#c8d8bc"), c("#b4c8a0"), c("#a0b888")),
                mountainColors = listOf(c("#6a8a6a"), c("#7a9a7a"), c("#5a7a5a")),
                enemyColors = listOf(c("#88aa44"), c("#77994e"), c("#669944"), c("#99bb55"), c("#88aa55")),
                platformGround = listOf(c("#b8c8a0"), c("#a8b890"), c("#c4d4a8")),
                platformFloat = listOf(c("#90a080"), c("#80906a"), c("#b0c090"))
            ),
            bgm = BGMConfig(droneFreq = 49.0f, filterCutoff = 2400f, volume = 0.04f, songId = 1)
        ),
        // Level 3: 拳脚相加
        LevelDef(
            name = "第三关·拳脚相加", killTarget = 25, weaponCap = 5, enemyTier = 1,
            enemies = listOf(EnemyType.SCOUT, EnemyType.CHASER, EnemyType.MARTIAL), bossHp = 1200, bossSpeed = 1.2f, bossType = BossType.IRON_FIST,
            colors = LevelColors(
                bgColors = listOf(c("#e0c8a0"), c("#d0b890"), c("#c0a878"), c("#aa9060")),
                mountainColors = listOf(c("#8a7050"), c("#9a8060"), c("#7a6040")),
                enemyColors = listOf(c("#aa7744"), c("#996644"), c("#bb8855"), c("#cc9966"), c("#aa8844")),
                platformGround = listOf(c("#c0a880"), c("#b09870"), c("#d0b890")),
                platformFloat = listOf(c("#ff9900"), c("#ffcc00"), c("#ffee44")) // Orange/Yellow
            ),
            bgm = BGMConfig(droneFreq = 46.2f, filterCutoff = 2200f, volume = 0.042f, songId = 2)
        ),
        // Level 4: 铁甲连城
        LevelDef(
            name = "第四关·铁甲连城", killTarget = 30, weaponCap = 6, enemyTier = 2,
            enemies = listOf(EnemyType.SCOUT, EnemyType.CHASER, EnemyType.MARTIAL, EnemyType.HEAVY), bossHp = 1600, bossSpeed = 1.3f, bossType = BossType.SHIELD_GENERAL,
            colors = LevelColors(
                bgColors = listOf(c("#c8d0d8"), c("#b0b8c8"), c("#98a0b0"), c("#808898")),
                mountainColors = listOf(c("#707888"), c("#606878"), c("#808898")),
                enemyColors = listOf(c("#5588aa"), c("#4477aa"), c("#6699bb"), c("#5599cc"), c("#4488aa")),
                platformGround = listOf(c("#a0a8b8"), c("#9098a8"), c("#b0b8c8")),
                platformFloat = listOf(c("#8800ff"), c("#9933ff"), c("#aa66ff")) // Purple/Violet
            ),
            bgm = BGMConfig(droneFreq = 41.2f, filterCutoff = 1800f, volume = 0.045f, songId = 3)
        ),
        // Level 5: 百步穿杨
        LevelDef(
            name = "第五关·百步穿杨", killTarget = 35, weaponCap = 7, enemyTier = 2,
            enemies = listOf(EnemyType.SCOUT, EnemyType.CHASER, EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER), bossHp = 2000, bossSpeed = 1.4f, bossType = BossType.PHANTOM_ARCHER,
            colors = LevelColors(
                bgColors = listOf(c("#c8a878"), c("#b89868"), c("#a08050"), c("#886838")),
                mountainColors = listOf(c("#705030"), c("#604020"), c("#805838")),
                enemyColors = listOf(c("#886644"), c("#775533"), c("#997755"), c("#aa8866"), c("#887755")),
                platformGround = listOf(c("#a08060"), c("#907050"), c("#b09070")),
                platformFloat = listOf(c("#00cc00"), c("#33dd33"), c("#66ee66")) // Green/Lime
            ),
            bgm = BGMConfig(droneFreq = 41.2f, filterCutoff = 1500f, volume = 0.048f, songId = 4)
        ),
        // Level 6: 刀光剑影
        LevelDef(
            name = "第六关·刀光剑影", killTarget = 40, weaponCap = 8, enemyTier = 2,
            enemies = listOf(EnemyType.CHASER, EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER), bossHp = 2500, bossSpeed = 1.5f, bossType = BossType.TWIN_BLADE,
            colors = LevelColors(
                bgColors = listOf(c("#4a5568"), c("#3a4558"), c("#2a3548"), c("#1a2538")),
                mountainColors = listOf(c("#2a3a50"), c("#1a2a40"), c("#3a4a60")),
                enemyColors = listOf(c("#7755aa"), c("#6644aa"), c("#8866bb"), c("#9977cc"), c("#7766aa")),
                platformGround = listOf(c("#505868"), c("#404858"), c("#606878")),
                platformFloat = listOf(c("#ff0066"), c("#ff3388"), c("#ff66aa")) // Pink/Red
            ),
            bgm = BGMConfig(droneFreq = 36.7f, filterCutoff = 1200f, volume = 0.05f, songId = 5)
        ),
        // Level 7: 龙争虎斗
        LevelDef(
            name = "第七关·龙争虎斗", killTarget = 45, weaponCap = 9, enemyTier = 3,
            enemies = listOf(EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER, EnemyType.CHASER), bossHp = 3200, bossSpeed = 1.7f, bossType = BossType.THUNDER_MONK,
            colors = LevelColors(
                bgColors = listOf(c("#3a2848"), c("#2a1838"), c("#1a0828"), c("#100018")),
                mountainColors = listOf(c("#2a1848"), c("#1a0838"), c("#3a2858")),
                enemyColors = listOf(c("#aa3344"), c("#993355"), c("#bb4455"), c("#cc5566"), c("#aa4466")),
                platformGround = listOf(c("#3a2838"), c("#2a1828"), c("#4a3848")),
                platformFloat = listOf(c("#ffcc00"), c("#ffee00"), c("#ffff44")) // Gold/Yellow (Electric)
            ),
            bgm = BGMConfig(droneFreq = 36.7f, filterCutoff = 1000f, volume = 0.052f, songId = 6)
        ),
        // Level 8: 万夫莫敌
        LevelDef(
            name = "第八关·万夫莫敌", killTarget = 50, weaponCap = 10, enemyTier = 3,
            enemies = listOf(EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER), bossHp = 4000, bossSpeed = 1.9f, bossType = BossType.BLOOD_DEMON,
            colors = LevelColors(
                bgColors = listOf(c("#3a1010"), c("#2a0808"), c("#1a0000"), c("#100000")),
                mountainColors = listOf(c("#3a0808"), c("#2a0000"), c("#4a1010")),
                enemyColors = listOf(c("#cc2222"), c("#bb1133"), c("#dd3344"), c("#ee4455"), c("#cc3355")),
                platformGround = listOf(c("#3a1818"), c("#2a0808"), c("#4a2020")),
                platformFloat = listOf(c("#ff0000"), c("#dd0000"), c("#bb0000")) // Deep Red
            ),
            bgm = BGMConfig(droneFreq = 32.7f, filterCutoff = 800f, volume = 0.055f, songId = 7)
        ),
        // Level 9: 天下无双
        LevelDef(
            name = "第九关·天下无双", killTarget = 55, weaponCap = 10, enemyTier = 3,
            enemies = listOf(EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER), bossHp = 5000, bossSpeed = 2.1f, bossType = BossType.SHADOW_LORD,
            colors = LevelColors(
                bgColors = listOf(c("#101828"), c("#081018"), c("#000810"), c("#000008")),
                mountainColors = listOf(c("#081830"), c("#001020"), c("#102040")),
                enemyColors = listOf(c("#4466cc"), c("#3355bb"), c("#5577dd"), c("#6688ee"), c("#4477cc")),
                platformGround = listOf(c("#182028"), c("#101818"), c("#202830")),
                platformFloat = listOf(c("#0000ff"), c("#2222ff"), c("#4444ff")) // Deep Blue
            ),
            bgm = BGMConfig(droneFreq = 32.7f, filterCutoff = 600f, volume = 0.058f, songId = 8)
        ),
        // Level 10: 剑神归位
        LevelDef(
            name = "第十关·剑神归位", killTarget = 60, weaponCap = 10, enemyTier = 3,
            enemies = listOf(EnemyType.MARTIAL, EnemyType.HEAVY, EnemyType.SNIPER), bossHp = 7000, bossSpeed = 2.5f, bossType = BossType.SWORD_SAINT,
            colors = LevelColors(
                bgColors = listOf(c("#0a0a10"), c("#050508"), c("#020204"), c("#000000")),
                mountainColors = listOf(c("#0a0a18"), c("#050510"), c("#101020")),
                enemyColors = listOf(c("#ccccdd"), c("#bbbbcc"), c("#ddddee"), c("#ffffff"), c("#aaaacc")),
                platformGround = listOf(c("#101018"), c("#080810"), c("#181820")),
                platformFloat = listOf(c("#ffffff"), c("#eeeeee"), c("#dddddd")) // White/Silver
            ),
            bgm = BGMConfig(droneFreq = 27.5f, filterCutoff = 500f, volume = 0.06f, songId = 9)
        )
    )

    val weaponNames = listOf(
        "木剑", "铁剑", "钢剑", "玄铁剑", "碧血剑",
        "倚天剑", "屠龙刀", "轩辕剑", "干将莫邪", "万剑归宗"
    )
}
