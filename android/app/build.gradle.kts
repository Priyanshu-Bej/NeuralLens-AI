import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Meta Wearables DAT credentials. "0" works with Developer Mode in the Meta AI
// app; production values come from the Wearables Developer Center and belong
// in the project's .env (MWDAT_*) or android/local.properties (mwdat_*), both
// git-ignored, never in source control. .env wins when both are set.
fun loadProperties(path: String) =
    Properties().apply {
        val file = rootProject.file(path)
        if (file.exists()) file.inputStream().use { load(it) }
    }
val dotEnv = loadProperties("../.env")
val localProperties = loadProperties("local.properties")

fun mwdatValue(name: String) =
    dotEnv.getProperty("MWDAT_${name.uppercase()}")?.trim()?.takeIf { it.isNotEmpty() }
        ?: localProperties.getProperty("mwdat_$name", "0")

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

        manifestPlaceholders["mwdat_application_id"] = mwdatValue("application_id")
        manifestPlaceholders["mwdat_client_token"] = mwdatValue("client_token")
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
    // DAT_APP_ON_THE_GLASSES_UPDATE_REQUIRED despite up-to-date firmware.
    // Keep all DAT modules on the same version, including question capture.
    val mwdatVersion = "1.0.0"
    implementation("com.meta.wearable:mwdat-core:$mwdatVersion")
    implementation("com.meta.wearable:mwdat-display:$mwdatVersion")
    implementation("com.meta.wearable:mwdat-camera:$mwdatVersion")
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    testImplementation("junit:junit:4.13.2")
    // Experimental: usable for development and beta testing only.
    implementation("com.meta.wearable:mwdat-inputs:$mwdatVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}
