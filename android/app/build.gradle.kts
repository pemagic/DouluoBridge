plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.douluo.bridge"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.douluo.bridge"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.7.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
    
    sourceSets {
        getByName("main") {
            // Include shared_assets into Android assets when building
            assets.srcDirs("src/main/assets", "../../shared_assets")
        }
    }
}

val natives by configurations.creating

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // libGDX
    api("com.badlogicgames.gdx:gdx:1.12.1")
    api("com.badlogicgames.gdx:gdx-backend-android:1.12.1")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-armeabi-v7a")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-arm64-v8a")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-x86")
    natives("com.badlogicgames.gdx:gdx-platform:1.12.1:natives-x86_64")
}

// Remove custom copy task and rely on standard JNI packaging
android {
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs", layout.buildDirectory.dir("libs"))
        }
    }
}
tasks.register<Copy>("copyAndroidNatives") {
    from(configurations.getByName("natives").map { zipTree(it) })
    into(layout.buildDirectory.dir("libs"))
    include("**/*.so")
}
tasks.whenTaskAdded {
    if (name.contains("package")) {
        dependsOn("copyAndroidNatives")
    }
}
