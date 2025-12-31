package dev.neonteam.castoriceps

import java.io.File

object NativeBridge {
    @Volatile private var loaded: Boolean = false

    fun ensureLoaded() {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            System.loadLibrary("castoriceps")
            loaded = true
        }
    }

    external fun start(): Int
    external fun stop(): Int
}
