# Keep gomobile bridge classes/methods required by native libbox.
-keep class go.Seq { *; }
-keep class go.** { *; }
-keep class go.**$* { *; }

# Keep libbox JNI entry points and models from obfuscation/shrinking.
-keep class io.nekohasekai.libbox.** { *; }
-keep class io.nekohasekai.libbox.**$* { *; }

# Keep plugin-side classes that are invoked from platform services.
-keep class com.signbox.singbox_mm.** { *; }

# Keep native methods signatures intact.
-keepclassmembers class * {
    native <methods>;
}
