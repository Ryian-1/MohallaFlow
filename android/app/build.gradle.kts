plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.firebase.firebase-perf")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material must live outside the repository. Values may be
// supplied by ~/.gradle/gradle.properties or the current shell environment.
val releaseStoreFilePath = providers.gradleProperty("MOHALLAFLOW_RELEASE_STORE_FILE").orNull
    ?: System.getenv("MOHALLAFLOW_RELEASE_STORE_FILE")
val releaseStorePassword = providers.gradleProperty("MOHALLAFLOW_RELEASE_STORE_PASSWORD").orNull
    ?: System.getenv("MOHALLAFLOW_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = providers.gradleProperty("MOHALLAFLOW_RELEASE_KEY_ALIAS").orNull
    ?: System.getenv("MOHALLAFLOW_RELEASE_KEY_ALIAS")
val releaseKeyPassword = providers.gradleProperty("MOHALLAFLOW_RELEASE_KEY_PASSWORD").orNull
    ?: System.getenv("MOHALLAFLOW_RELEASE_KEY_PASSWORD")

val releaseSigningValues = mapOf(
    "MOHALLAFLOW_RELEASE_STORE_FILE" to releaseStoreFilePath,
    "MOHALLAFLOW_RELEASE_STORE_PASSWORD" to releaseStorePassword,
    "MOHALLAFLOW_RELEASE_KEY_ALIAS" to releaseKeyAlias,
    "MOHALLAFLOW_RELEASE_KEY_PASSWORD" to releaseKeyPassword,
)

// Fail early and explicitly for release packaging. Debug builds continue to
// use the normal Android debug signing configuration.
val releaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

if (releaseBuildRequested) {
    val missing = releaseSigningValues
        .filterValues { it.isNullOrBlank() }
        .keys

    if (missing.isNotEmpty()) {
        throw GradleException(
            "MohallaFlow release signing is not configured. Set these values " +
                "in ~/.gradle/gradle.properties or the build environment: " +
                missing.joinToString(", ")
        )
    }

    val keystore = file(releaseStoreFilePath!!)
    if (!keystore.isFile) {
        throw GradleException(
            "MohallaFlow release keystore does not exist at the configured path. " +
                "Keep the upload keystore outside the repository."
        )
    }
}

android {
    namespace = "com.mohallaflow.mohalla_flow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mohallaflow.mohalla_flow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningValues.values.all { !it.isNullOrBlank() }) {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Never fall back to the debug keystore for a release artifact.
            signingConfig = signingConfigs.getByName("release")
        }
    }
    packaging {
        resources {
            excludes += "DebugProbesKt.bin"
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
