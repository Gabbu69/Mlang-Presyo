plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter's installer can uninstall an existing app after a failed update.
// The test harness must therefore own a package separate from the notebook.
// Dart exposes Windows environment names in uppercase. Keep the property and
// ORG_GRADLE_PROJECT_ suffix uppercase so Flutter's child Gradle sees the flag.
val integrationTarget = providers.gradleProperty("PRESYO_INTEGRATION_TARGET")
    .map { it == "true" }
    .getOrElse(false)

android {
    namespace = "app.presyomlang.personal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable internal personal-pilot ID.
        applicationId = if (integrationTarget) {
            "app.presyomlang.personal.integration"
        } else {
            "app.presyomlang.personal"
        }
        manifestPlaceholders["presyoAppLabel"] = if (integrationTarget) {
            "PresyoGo Tests"
        } else {
            "PresyoGo"
        }
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

    buildTypes {
        release {
            // Public release signing is intentionally not configured.
            // Never disguise the development certificate as release signing.
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
