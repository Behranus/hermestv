plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.iptv.iptv_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.iptv.iptv_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Flutter şablonu minSdk 24 (Android 7.0) ister; eski Android Box'lar (6.0)
        // için 23'e çektik. Flutter 23'ün altını reddettiği için 23 minimumdur.
        // Not: literal sayı yazarsak Flutter migrasyonu geri 24'e çevirir.
        val minSdkLevel = 23
        minSdk = minSdkLevel
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Kalıcı release imzası (Play Protect uyarısı vermez, güncellemeler tutarlı kalır).
        // Anahtar dosyası: android/app/iptv-release.jks  (şifre: iptvplayer2017)
        create("release") {
            storeFile = file("iptv-release.jks")
            storePassword = "iptvplayer2017"
            keyAlias = "iptv"
            keyPassword = "iptvplayer2017"
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // Eski Box'lar (Android 6-) v1 imzası ister; yeni sürümler v2/v3 kullanır.
            signingConfig = signingConfigs.getByName("release")
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
