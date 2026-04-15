import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

/*
 * Release identity safety:
 * 1) package name/applicationId must never change
 * 2) signing key must never change
 * 3) versionCode must always increase
 *
 * Changing any of the above will break update compatibility
 * and can cause INSTALL_FAILED_UPDATE_INCOMPATIBLE / package conflict errors.
 */

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.anjanam.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // WARNING: Changing applicationId will cause update conflicts and force users to uninstall the existing app.
        applicationId = "com.anjanam.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode must always increase for Play Store updates.
        // Reusing the same versionCode causes Play Console upload rejection.
        // CI can pass BUILD_NUMBER for deterministic release increments.
        val buildNumberFromEnv = System.getenv("BUILD_NUMBER")?.toIntOrNull()
        versionCode = buildNumberFromEnv ?: flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("Missing key.properties for release signing.")
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Required by FlutterPlayStoreSplitApplication/deferred components classes during release builds.
    // Use modern feature-delivery artifact to avoid duplicate classes with core-common 2.x.
    implementation("com.google.android.play:feature-delivery:2.1.0")
}

val googleServicesJson = project.file("google-services.json")
val debugGoogleServicesJson = project.file("src/debug/google-services.json")
val releaseGoogleServicesJson = project.file("src/release/google-services.json")
if (googleServicesJson.exists() || debugGoogleServicesJson.exists() || releaseGoogleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
}
