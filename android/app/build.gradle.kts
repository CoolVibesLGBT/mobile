import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) propertiesFile.inputStream().use { load(it) }
}
fun releaseSigningValue(property: String, environment: String): String? =
    providers.environmentVariable(environment).orNull
        ?.takeIf { it.isNotEmpty() }
        ?: releaseKeyProperties.getProperty(property)?.takeIf { it.isNotEmpty() }

val releaseStorePath = releaseSigningValue("storeFile", "COOLVIBES_KEYSTORE_FILE")
val releaseStorePassword = releaseSigningValue("storePassword", "COOLVIBES_KEYSTORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("keyAlias", "COOLVIBES_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "COOLVIBES_KEY_PASSWORD")
val releaseStoreFile = releaseStorePath?.let { rootProject.file(it) }
val releaseSigningReady = releaseStoreFile?.isFile == true &&
    releaseStorePassword != null && releaseKeyAlias != null && releaseKeyPassword != null

// A local debug build needs no distribution credentials. Every release task
// must use the app owner's key; never silently ship with the debug certificate.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release", ignoreCase = true) } &&
        !releaseSigningReady) {
        throw GradleException(
            "Release signing is not configured. Set android/key.properties " +
                "(storeFile, storePassword, keyAlias, keyPassword) or the COOLVIBES_KEYSTORE_FILE, " +
                "COOLVIBES_KEYSTORE_PASSWORD, COOLVIBES_KEY_ALIAS and COOLVIBES_KEY_PASSWORD " +
                "environment variables. The keystore file must exist. See README.md."
        )
    }
}

android {
    namespace = "app.coolvibes.coolvibes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.coolvibes.coolvibes"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
