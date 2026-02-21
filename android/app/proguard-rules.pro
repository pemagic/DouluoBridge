# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK tools proguard config.

# libGDX - keep all native method classes
-keep class com.badlogic.gdx.** { *; }
-dontwarn com.badlogic.gdx.**
