package dev.neonteam.castoriceps

object NativeBridge {
    init {
        System.loadLibrary("castoriceps")
    }

    external fun start(): Int
    external fun stop(): Int
}
