import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    println("⚠️ ERRO: key.properties não encontrado!")
}

android {
    namespace = "com.jeovanna.sistemadeindicacao"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.jeovanna.sistemadeindicacao"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"]?.toString()
            val keyAliasProp = keystoreProperties["keyAlias"]?.toString()
            val keyPasswordProp = keystoreProperties["keyPassword"]?.toString()
            val storePasswordProp = keystoreProperties["storePassword"]?.toString()

            if (storeFilePath == null) {
                println("⚠️ Caminho do storeFile é nulo. Verifique o key.properties!")
            } else {
                val storeFileObj = File(storeFilePath)
                if (!storeFileObj.exists()) {
                    println("⚠️ Arquivo JKS não encontrado em: $storeFilePath")
                } else {
                    storeFile = storeFileObj
                    println("✅ Chave encontrada: $storeFilePath")
                }
            }

            keyAlias = keyAliasProp
            keyPassword = keyPasswordProp
            storePassword = storePasswordProp
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
