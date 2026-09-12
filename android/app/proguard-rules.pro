# Flutter Proguard Rules for ResumeOS

# Keep Flutter engine and plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Firebase and Google Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep models and serialized classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Coroutines
-keepclassmembernames class kotlinx.coroutines.internal.MainDispatcherFactory {
    java.lang.String FAST_SERVICE_KEY;
}
-keep class kotlinx.coroutines.android.AndroidDispatcherFactory {
    public <init>();
}

# Keep Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keepclassmembers class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Ignore warnings for unused libraries
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
