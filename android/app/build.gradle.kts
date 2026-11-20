import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyFile = rootProject.file("key.properties")
val releaseKeys = Properties().apply {
    if (releaseKeyFile.isFile) releaseKeyFile.inputStream().use { load(it) }
}

fun releaseKey(name: String): String = releaseKeys.getProperty(name)
    ?.takeIf { it.isNotBlank() }
    ?: error("Missing $name in android/key.properties")

android {
    namespace = "com.learningapp.learning_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.learningapp.learning_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseSigner = if (releaseKeyFile.isFile) {
        signingConfigs.create("skillverseRelease") {
            storeFile = rootProject.file(releaseKey("storeFile"))
            storePassword = releaseKey("storePassword")
            keyAlias = releaseKey("keyAlias")
            keyPassword = releaseKey("keyPassword")
        }
    } else {
        // Keep the existing signer for private APK testing and upgrades.
        signingConfigs.getByName("debug")
    }

    buildTypes {
        release {
            signingConfig = releaseSigner
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
