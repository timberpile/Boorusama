import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val configuredKeystoreFile = keystoreProperties.getProperty("storeFile")?.let(::file)
val hasValidKeystore = keystorePropertiesFile.exists() &&
    missingSigningProperties.isEmpty() &&
    configuredKeystoreFile?.isFile == true
fun invalidSigningReason(): String {
    val reason = when {
        !keystorePropertiesFile.exists() -> "android/key.properties is missing"
        missingSigningProperties.isNotEmpty() ->
            "missing properties: ${missingSigningProperties.joinToString()}"
        else -> "configured storeFile does not exist"
    }
    return reason
}
val splitPerAbi = project.findProperty("split-per-abi") == "true"

android {
    namespace = "com.degenk.boorusama"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.degenk.boorusama"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasValidKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = configuredKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
   
    buildTypes {
        release {
            if (hasValidKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
                if (!splitPerAbi) {
                    abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
                }
            }
        }
    }

    flavorDimensions.add("boorusama")

    productFlavors {
        create("dev") {
            dimension = "boorusama"
            resValue("string", "app_name", "Boorusama Dev")
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }

        create("prod") {
            dimension = "boorusama"
            resValue("string", "app_name", "Boorusama")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

gradle.taskGraph.whenReady {
    val appReleaseTaskSelected = allTasks.any {
        it.project == project && it.name.contains("release", ignoreCase = true)
    }
    if (appReleaseTaskSelected && !hasValidKeystore) {
        throw GradleException(
            "Release signing configuration is invalid: ${invalidSigningReason()}",
        )
    }
}
