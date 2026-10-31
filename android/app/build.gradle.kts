import org.gradle.api.JavaVersion
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 🔐 Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun keystoreValue(name: String): String =
    keystoreProperties.getProperty(name)?.trim().orEmpty()

val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    listOf("storePassword", "keyPassword", "keyAlias", "storeFile").all { name ->
        val value = keystoreValue(name)
        value.isNotEmpty() && !value.startsWith("REPLACE_WITH_")
    }

android {
    namespace = "com.filmytell.ott"
    compileSdk = 36

    // ✅ Required for desugaring + Java 17
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.filmytell.ott"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 🔐 Release signing config
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreValue("keyAlias")
                keyPassword = keystoreValue("keyPassword")
                storeFile = file(keystoreValue("storeFile"))
                storePassword = keystoreValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            require(hasReleaseKeystore) {
                "Release signing configuration is missing or incomplete. Check android/key.properties."
            }

            signingConfig = signingConfigs.getByName("release")

            // ✅ Enabled R8 obfuscation & resource shrinking (generates mapping.txt)
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))

    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")

    // Google Play Install Referrer for deferred deep linking
    implementation("com.android.installreferrer:installreferrer:2.2")

    // Desugaring support
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
