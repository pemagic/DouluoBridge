package com.douluo.bridge

import android.os.Bundle
import com.badlogic.gdx.backends.android.AndroidApplication
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration

class AndroidLauncher : AndroidApplication() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val config = AndroidApplicationConfiguration()
        // Disable unnecessary features for 2D
        config.useAccelerometer = false
        config.useCompass = false
        
        // Setup initial Game class (we'll implement this later in core)
        initialize(DouluoGame(), config)
    }
}
