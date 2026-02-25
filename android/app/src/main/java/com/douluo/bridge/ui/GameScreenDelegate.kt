package com.douluo.bridge.ui

import com.douluo.bridge.GameState

enum class HapticType {
    LIGHT, MEDIUM, HEAVY
}

interface GameScreenDelegate {
    fun gameStateChanged(state: GameState)
    fun updateHUD(hp: Float, maxHp: Int, energy: Int, kills: Int, combo: Int, weaponLevel: Int, level: Int)
    fun showLevelBanner(name: String, updateBGM: Boolean)
    fun gameEnded(kills: Int, time: Int, level: Int, victory: Boolean)
    fun triggerHaptic(type: HapticType)
    fun playSkillSfx()       // v1.9
    fun playAttackSfx()      // v1.9
    fun playBossWarningSfx() // v1.9
}
