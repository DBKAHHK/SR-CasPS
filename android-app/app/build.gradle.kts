plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

import java.io.File
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

android {
    namespace = "dev.neonteam.castoriceps"
    compileSdk = 34

    defaultConfig {
        applicationId = "dev.neonteam.castoriceps"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"

        ndk {
            // Zig workflow currently builds arm64 only.
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

val repoRoot = rootProject.projectDir.parentFile
val programDir = File(repoRoot, "program")
val jniLibOutDir = File(projectDir, "src/main/jniLibs/arm64-v8a")
val jniLibOut = File(jniLibOutDir, "libcastoriceps.so")

val buildCastoricePsSo = tasks.register("buildCastoricePsSo") {
    group = "build"
    description = "Builds libcastoriceps.so via Zig and copies it into src/main/jniLibs/arm64-v8a."

    inputs.dir(programDir)
    outputs.file(jniLibOut)

    doLast {
        jniLibOutDir.mkdirs()

        fun findNdkDir(): File {
            val env = System.getenv()
            val direct = listOf("ANDROID_NDK_HOME", "ANDROID_NDK_ROOT", "ANDROID_NDK").firstNotNullOfOrNull { k ->
                env[k]?.takeIf { it.isNotBlank() }?.let { File(it) }
            }
            if (direct != null && direct.exists()) return direct

            val androidHome = env["ANDROID_HOME"]?.takeIf { it.isNotBlank() }?.let { File(it) }
                ?: env["ANDROID_SDK_ROOT"]?.takeIf { it.isNotBlank() }?.let { File(it) }
            if (androidHome != null) {
                val ndkRoot = File(androidHome, "ndk")
                if (ndkRoot.isDirectory) {
                    val candidates = ndkRoot.listFiles()?.filter { it.isDirectory }?.sortedByDescending { it.name } ?: emptyList()
                    if (candidates.isNotEmpty()) return candidates.first()
                }
                val legacy = File(androidHome, "ndk-bundle")
                if (legacy.isDirectory) return legacy
            }

            throw GradleException(
                "Android NDK not found. Install NDK (via Android Studio SDK Manager or sdkmanager) and set ANDROID_NDK_HOME/ANDROID_NDK_ROOT.",
            )
        }

        fun hostTag(): String {
            val os = System.getProperty("os.name").lowercase()
            val arch = System.getProperty("os.arch").lowercase()
            return when {
                os.contains("linux") -> "linux-x86_64"
                os.contains("windows") -> "windows-x86_64"
                os.contains("mac") || os.contains("darwin") -> if (arch.contains("aarch64") || arch.contains("arm64")) "darwin-arm64" else "darwin-x86_64"
                else -> throw GradleException("Unsupported host OS for NDK: $os ($arch)")
            }
        }

        val ndkDir = findNdkDir()
        val sysroot = File(ndkDir, "toolchains/llvm/prebuilt/${hostTag()}/sysroot")
        if (!sysroot.isDirectory) {
            throw GradleException("NDK sysroot not found at: ${sysroot.absolutePath}")
        }

        // Avoid Gradle exec/task APIs here; some CI setups compile Kotlin scripts with strict
        // settings that turn deprecations into errors and may not have Kotlin DSL extensions.
        val process = ProcessBuilder(
            "zig",
            "build",
            "-Doptimize=ReleaseFast",
            "-Dtarget=aarch64-linux-android.26",
            "-Dandroid_no_libc=false",
            "--sysroot",
            sysroot.absolutePath,
        )
            .directory(programDir)
            .inheritIO()
            .start()
        val exitCode = process.waitFor()
        if (exitCode != 0) {
            throw GradleException("zig build failed with exit code $exitCode")
        }

        val built = File(programDir, "zig-out/lib/libcastoriceps.so")
        if (!built.exists() || built.length() == 0L) {
            throw GradleException("Zig build did not produce ${built.absolutePath}")
        }
        built.copyTo(jniLibOut, overwrite = true)
        logger.lifecycle("Copied JNI lib to: ${jniLibOut.absolutePath}")
    }
}

// Make sure the embedded server is packaged in the APK.
tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(buildCastoricePsSo)
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("com.google.android.material:material:1.12.0")
}
