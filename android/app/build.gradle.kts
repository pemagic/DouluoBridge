plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Custom configuration for libGDX native libraries.
// This MUST be declared before the dependencies block but never resolved at configuration time.
val natives: Configuration by configurations.creating

android {
    namespace = "com.douluo.bridge"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.douluo.bridge"
        minSdk = 24
        targetSdk = 34
        versionCode = 19
        versionName = "1.8.17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Use debug signing for release builds so that they are installable for testing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }

    // Single unified sourceSets block — never open a second android {} block
    sourceSets {
        getByName("main") {
            assets.srcDirs("src/main/assets", "../../shared_assets")
            jniLibs.srcDirs("src/main/jniLibs", layout.buildDirectory.dir("libs/jni"))
        }
    }

    applicationVariants.all {
        outputs.all {
            if (this is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                this.outputFileName = "DouluoBridge-Android-v${defaultConfig.versionName}.apk"
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")

    // libGDX core + Android backend
    api("com.badlogicgames.gdx:gdx:1.12.1")
    api("com.badlogicgames.gdx:gdx-backend-android:1.12.1")

    // libGDX native .so libraries — placed into the custom "natives" configuration,
    // NOT into implementation/api so they don't pollute the compile classpath.
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-armeabi-v7a")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-arm64-v8a")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-x86")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-x86_64")
}

// Extract native .so files from the libGDX platform JARs into ABI-specific subdirectories.
// This task runs ONLY at execution time (inside doLast), never during configuration.
// The "natives" configuration is resolved only when this task actually executes.
val copyAndroidNatives by tasks.registering {
    description = "Extract libGDX native .so files into ABI-specific jniLibs directories"
    doLast {
        val jniDir = layout.buildDirectory.dir("libs/jni").get().asFile
        natives.files.forEach { jar ->
            // Determine target ABI directory from the jar classifier name
            val abi = when {
                jar.name.contains("natives-arm64-v8a") -> "arm64-v8a"
                jar.name.contains("natives-armeabi-v7a") -> "armeabi-v7a"
                jar.name.contains("natives-x86_64") -> "x86_64"
                jar.name.contains("natives-x86") -> "x86"
                else -> return@forEach
            }
            val outputDir = File(jniDir, abi)
            outputDir.mkdirs()
            copy {
                from(zipTree(jar))
                into(outputDir)
                include("*.so")
            }
        }
    }
}

// Wire up: ensure native .so extraction runs before JNI libs are merged into the APK.
// Using configureEach to lazily add the dependency without triggering configuration resolution.
tasks.configureEach {
    if (name.contains("merge") && name.contains("JniLibFolders")) {
        dependsOn(copyAndroidNatives)
    }
}
