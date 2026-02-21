package com.douluo.bridge

import com.badlogic.gdx.Game
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.g2d.SpriteBatch

class DouluoGame(private val delegate: com.douluo.bridge.ui.GameScreenDelegate) : Game() {
    lateinit var batch: SpriteBatch

    override fun create() {
        batch = SpriteBatch()
        setScreen(DouluoGameScreen(this, delegate))
    }

    override fun render() {
        Gdx.gl.glClearColor(1f, 1f, 1f, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        super.render()
    }

    override fun dispose() {
        batch.dispose()
        super.dispose()
    }
}
