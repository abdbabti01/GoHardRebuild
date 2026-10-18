import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps key (docs/RUN_WALK.md › Map): from the gitignored android/secrets.properties (MAPS_API_KEY=…) or the
// ANDROID_GOOGLE_MAPS_API_KEY environment variable (CI secret). Never committed. Empty = no map; the app then draws
// the route without a basemap.
val mapsApiKey: String = Properties().also { p ->
    rootProject.file("secrets.properties").takeIf { it.exists() }?.inputStream()?.use { p.load(it) }
}.getProperty("MAPS_API_KEY") ?: System.getenv("ANDROID_GOOGLE_MAPS_API_KEY") ?: ""

android {
    namespace = "com.gohard.gohard_rebuild"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // required by flutter_local_notifications
    }

    defaultConfig {
        // Distinct from the original GoHard app so both can be installed side by side.
        applicationId = "com.gohard.rebuild"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 26: Health Connect's client library (daily steps, docs/RUN_WALK.md › Steps) needs Android 8.0 or later.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Daily steps only: one aggregate read of StepsRecord (docs/RUN_WALK.md › Steps).
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
