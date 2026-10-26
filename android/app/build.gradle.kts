import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.bloomwell.bloomwell"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bloomwell.bloomwell"
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

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()
                val storePasswordVal = keystoreProperties.getProperty("storePassword")?.trim()
                val keyAliasVal = keystoreProperties.getProperty("keyAlias")?.trim()
                val keyPasswordVal = keystoreProperties.getProperty("keyPassword")?.trim()

                if (storeFilePath.isNullOrEmpty() ||
                    storePasswordVal.isNullOrEmpty() ||
                    keyAliasVal.isNullOrEmpty() ||
                    keyPasswordVal.isNullOrEmpty()) {
                    throw GradleException(
                        "Release signing error: 'key.properties' was found but is incomplete. " +
                        "All of storeFile, storePassword, keyAlias, and keyPassword must be non-empty."
                    )
                }

                val keystoreFile = rootProject.file(storeFilePath)
                if (!keystoreFile.exists()) {
                    throw GradleException(
                        "Release signing error: Keystore file '${storeFilePath}' does not exist relative to root project (${rootProject.projectDir.path})."
                    )
                }

                storeFile = keystoreFile
                storePassword = storePasswordVal
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

gradle.taskGraph.whenReady {
    val isReleaseTask = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true) &&
        (task.name.contains("assemble", ignoreCase = true) ||
         task.name.contains("bundle", ignoreCase = true) ||
         task.name.contains("package", ignoreCase = true))
    }
    if (isReleaseTask) {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Release signing error: 'key.properties' was not found at 'mobile_app/android/key.properties'. " +
                "Permanent release builds require a configured release keystore and key.properties."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
