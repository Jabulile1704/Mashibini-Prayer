import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mashibini.mashibini_prayer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules against java.time, which is
        // newer than the oldest Android this app supports. Desugaring
        // backports it rather than raising minSdk and dropping phones.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mashibini.mashibini_prayer"
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

    // The release key exists so Android recognises the next build as the
    // same app. It is **not** provenance — ADR-013 explains why signing
    // means nothing for an app with no store and four users in one house.
    //
    // Android identifies an app by package name *and* signing key, so a
    // build signed by a different key cannot be installed over the previous
    // one. Everything in this app is device-local, so that would cost
    // somebody their rota and their prayer journal.
    //
    // Read from android/key.properties locally, or from the environment in
    // CI. Absent, release builds fall back to the debug key so that
    // `flutter run --release` still works on a developer's own machine —
    // release.yml refuses to publish in that state (issue #67).
    signingConfigs {
        create("release") {
            val properties = Properties()
            val file = rootProject.file("key.properties")
            if (file.exists()) {
                file.inputStream().use(properties::load)
            }

            fun setting(key: String, variable: String): String? =
                properties.getProperty(key) ?: System.getenv(variable)

            val store = setting("storeFile", "ANDROID_KEYSTORE_PATH")
            if (store != null) {
                storeFile = rootProject.file(store)
                storeType = "PKCS12"
                storePassword = setting("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = setting("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword =
                    setting("keyPassword", "ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
