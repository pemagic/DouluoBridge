package com.douluo.bridge.ui

import com.douluo.bridge.GameState

enum class HapticType {
    LIGHT, MEDIUM, HEAVY
}

enum class SFXType {
    JUMP, ATTACK, DASH, HIT, KILL,
    BOSS_WARNING, BOSS_DEATH, DROP_THROUGH,
    SKILL_FIRE, SKILL_WHIRLWIND, SKILL_SHIELD, SKILL_LIGHTNING, SKILL_GHOST,
    UI_CLICK
}

interface GameScreenDelegate {
    fun gameStateChanged(state: GameState)
    fun updateHUD(hp: Float, maxHp: Int, energy: Int, kills: Int, combo: Int, weaponLevel: Int, level: Int)
    fun showLevelBanner(name: String, updateBGM: Boolean)
    fun gameEnded(kills: Int, time: Int, level: Int, victory: Boolean)
    fun triggerHaptic(type: HapticType)
    fun playSFX(type: SFXType)
    fun switchToBossBGM()
    fun restoreLevelBGM()
    fun showBossWarning(name: String)
}
