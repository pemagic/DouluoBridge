// Root-level build.gradle.kts
// AGP 8.7.3 + Kotlin 2.1.0 — compatible with JDK 25 and Gradle 8.11.1
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.3")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}
