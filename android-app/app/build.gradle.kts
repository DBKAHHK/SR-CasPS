plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

import java.io.File
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.Action
import org.gradle.process.ExecSpec

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
        if (jniLibOut.exists() && jniLibOut.length() > 0) {
            logger.lifecycle("Using existing JNI lib: ${jniLibOut.absolutePath}")
            return@doLast
        }

        jniLibOutDir.mkdirs()

        project.exec(Action<ExecSpec> { spec ->
            spec.workingDir = programDir
            spec.commandLine(
                "zig",
                "build",
                "-Doptimize=ReleaseFast",
                "-Dtarget=aarch64-linux-android",
            )
        })

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
