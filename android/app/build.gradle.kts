plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 🔥 CORRECCIÓN: Importamos las clases explícitamente aquí
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.entrenador"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.sebastian.entrenador"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // CONFIGURACIÓN DE FIRMA
    signingConfigs {
        create("release") {
            // Verificamos que las propiedades existan antes de usarlas
            val keyAlias = keystoreProperties["keyAlias"] as String?
            val keyPassword = keystoreProperties["keyPassword"] as String?
            val storeFile = keystoreProperties["storeFile"] as String?
            val storePassword = keystoreProperties["storePassword"] as String?

            if (keyAlias != null && keyPassword != null && storeFile != null && storePassword != null) {
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                this.storeFile = file(storeFile)
                this.storePassword = storePassword
            } else {
                println("⚠️ ADVERTENCIA: No se encontraron las credenciales de firma en key.properties")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // USAR LA FIRMA
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}