# ============================================================
# Mbeck Business — ProGuard / R8 Rules
# ============================================================

# --- Flutter Engine ---
# Flutter's own rules are injected automatically by the Flutter Gradle plugin,
# but keeping these as a safety net doesn't hurt.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# --- Dart / Flutter Plugin interop ---
# Prevents R8 from stripping plugin entry-point classes that are
# referenced by name at runtime.
-keep class * extends io.flutter.plugin.common.PluginRegistry { *; }

# --- JSON Serialization (json_serializable / dart:convert) ---
# If you use json_serializable on the Dart side this is less relevant,
# but any native Kotlin/Java data classes that are serialized must be kept.
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- Firebase (if used) ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- SQLite / SQFLite ---
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# --- WorkManager (background sync) ---
-keep class androidx.work.** { *; }

# --- General Android safety rules ---
# Keep all Parcelable implementations (used by Android IPC/intents)
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep enum members
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Suppress warnings for missing classes from optional dependencies
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.**
