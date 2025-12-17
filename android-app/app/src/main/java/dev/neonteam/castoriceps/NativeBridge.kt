package dev.neonteam.castoriceps

import java.io.File

object NativeBridge {
    @Volatile private var loaded: Boolean = false

    fun ensureLoaded(fallbackSo: File? = null) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            try {
                System.loadLibrary("castoriceps")
            } catch (e: UnsatisfiedLinkError) {
                val so = fallbackSo
                if (so != null && so.exists()) {
                    System.load(so.absolutePath)
                } else {
                    throw e
                }
            }
            loaded = true
        }
    }

    external fun start(): Int
    external fun stop(): Int
}
