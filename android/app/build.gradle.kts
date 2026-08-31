plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.shedowe.ansagengenerator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.shedowe.ansagengenerator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidResources {
        noCompress += "zip"
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

val offlineArchiveDirectory = rootProject.projectDir.parentFile.resolve(
    "source-android/app/src/main/assets/offline",
)
val offlineArchiveManifest = offlineArchiveDirectory.resolve(
    "ansagengenerator-offline-opus-data.parts.json",
)
val offlineArchiveOutput = offlineArchiveDirectory.resolve(
    "ansagengenerator-offline-opus-data.zip",
)
val assembleOfflineArchive by tasks.registering(Exec::class) {
    group = "build setup"
    description = "Reconstructs the verified offline ZIP from regular Git parts."
    inputs.file(offlineArchiveManifest)
    inputs.files(
        fileTree(offlineArchiveDirectory) {
            include("ansagengenerator-offline-opus-data.zip.part-*")
        },
    )
    outputs.file(offlineArchiveOutput)
    commandLine(
        "python3",
        rootProject.projectDir.parentFile.resolve("tool/offline_archive_parts.py").absolutePath,
        "assemble",
        "--manifest",
        offlineArchiveManifest.absolutePath,
        "--output",
        offlineArchiveOutput.absolutePath,
    )
}

tasks.configureEach {
    if (name.startsWith("compileFlutterBuild")) {
        dependsOn(assembleOfflineArchive)
    }
}

flutter {
    source = "../.."
}
