# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Hive
-keep class com.example.test_sample.models.** { *; }
-keep class io.hive.** { *; }

# For Google Fonts and other reflection based plugins
-keep class com.google.fonts.** { *; }

# Prevent obfuscation of specific models if needed
-keep class com.example.test_sample.models.** { *; }

# Fix R8 missing class errors for Play Core
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.internal.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Keep classes that are referenced but might be missing
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.appupdate.AppUpdateManager { *; }
-keep class com.google.android.play.core.tasks.Task { *; }

