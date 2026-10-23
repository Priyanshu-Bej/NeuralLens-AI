import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Meta Wearables DAT credentials. "0" works with Developer Mode in the Meta AI
// app; production values come from the Wearables Developer Center and belong
// in android/local.properties (git-ignored), never in source control.
val localProperties =
    Properties().apply {
        val file = rootProject.file("local.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }

android {
    namespace = "com.priyanshubej.neurallens"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.priyanshubej.neurallens"
        // The Meta Wearables DAT 1.0.1 AARs declare minSdkVersion 29.
        minSdk = maxOf(29, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["mwdat_application_id"] =
            localProperties.getProperty("mwdat_application_id", "0")
        manifestPlaceholders["mwdat_client_token"] =
            localProperties.getProperty("mwdat_client_token", "0")
    }

    buildTypes {
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
    // Meta Wearables Device Access Toolkit (developer preview), Maven Central.
    // Pinned to 1.0.0, the version proven against our glasses (the iOS app).
    // With 1.0.1 the glasses refused every session with
    // DAT_APP_ON_THE_GLASSES_UPDATE_REQUIRED despite up-to-date firmware; 1.0.1
    // only adds camera-streaming fixes this app does not use.
    val mwdatVersion = "1.0.0"
    implementation("com.meta.wearable:mwdat-core:$mwdatVersion")
    implementation("com.meta.wearable:mwdat-display:$mwdatVersion")
    // Experimental: usable for development and beta testing only.
    implementation("com.meta.wearable:mwdat-inputs:$mwdatVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}
