# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Chaquopy (Python runtime)
-keep class com.chaquo.python.** { *; }
-dontwarn com.chaquo.python.**

# Audio Service and Just Audio
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

# AndroidX Media
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-keep class androidx.core.** { *; }

# SQLite
-keep class com.tekartik.sqflite.** { *; }

# OkHttp & Network
-dontwarn okhttp3.**
-dontwarn okio.**

# Google Play Core (deferred components not bundled)
-dontwarn com.google.android.play.core.**
