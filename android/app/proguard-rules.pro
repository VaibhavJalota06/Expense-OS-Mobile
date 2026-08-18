# Flutter ProGuard / R8 Rules
-dontwarn io.flutter.**

# Google ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
