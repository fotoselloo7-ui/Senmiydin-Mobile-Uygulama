import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(',').filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8).split('=', limit = 2) }
    .filter { it.size == 2 }.associate { it[0] to it[1] }

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = signingKeys.all { !signingProperties.getProperty(it).isNullOrBlank() }

android {
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }
    namespace = "com.senmiydin.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { resValues = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable identity shared with iOS and external service registrations.
        applicationId = "com.senmiydin.app"
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

        // Firebase's native receiver must be able to start before the Flutter engine.
        val firebaseResources = mapOf(
            "google_app_id" to "FCM_ANDROID_APP_ID",
            "gcm_defaultSenderId" to "FCM_SENDER_ID",
            "project_id" to "FCM_PROJECT_ID",
            "google_api_key" to "FCM_ANDROID_API_KEY",
        )
        if (firebaseResources.values.all { !dartDefines[it].isNullOrBlank() }) {
            firebaseResources.forEach { (resource, define) ->
                resValue("string", resource, dartDefines.getValue(define))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
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


// Fail explicitly rather than producing a store artifact signed with a debug key.
tasks.configureEach {
    if (name == "validateSigningRelease" || name == "signReleaseBundle" || name == "packageRelease") {
        doFirst {
            if (!hasReleaseSigning) throw GradleException("Release signing is missing. Configure android/key.properties; see docs/DEPLOYMENT.md.")
        }
    }
}
