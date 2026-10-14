import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // kotlin-android eliminado: Flutter 3.44+ compila Kotlin con Built-in Kotlin.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release (#11). La llave del equipo vive fuera del repositorio y
// android/key.properties (Git lo ignora) dice dónde está y sus contraseñas.
// Sin ese archivo (GitHub Actions, otra computadora) el release se firma con
// la llave de depuración, como antes: compilar no depende de tener la llave.
val keystorePropertiesFile = rootProject.file("key.properties")
val hayLlaveRelease = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hayLlaveRelease) FileInputStream(keystorePropertiesFile).use { load(it) }
}

android {
    namespace = "mx.com.pierreposteria"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 21 para empatar con el Built-in Kotlin de Flutter 3.44 (su jvmTarget
        // por defecto es 21; con 17 el build falla por targets inconsistentes).
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    // kotlinOptions eliminado junto con el plugin kotlin-android:
    // el jvmTarget de Kotlin lo maneja el Flutter Gradle Plugin.

    defaultConfig {
        // Identificador en Google Play (#10; Play no acepta com.example.*). El
        // inicio con Google lo valida junto con la SHA-1 de la llave: cada
        // computadora que compila necesita su cliente OAuth Android en Google
        // Cloud para este paquete (y .dev / .staging) o da ApiException 10.
        applicationId = "mx.com.pierreposteria"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // Required for flutter_stripe
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Pruebas instrumentadas para Firebase Test Lab (#75). androidx.test
        // (runner, rules, espresso) ya lo trae el plugin integration_test.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Ambientes (#12): cada flavor se instala aparte (sufijo en el paquete) y
    // se distingue en el launcher. El backend lo elige la app con appFlavor
    // (lib/config/api_constants.dart). Sin --flavor se compila prod
    // (default-flavor en pubspec.yaml), así que `flutter run` no cambia.
    flavorDimensions += "ambiente"
    productFlavors {
        create("dev") {
            dimension = "ambiente"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Pier DEV")
        }
        create("staging") {
            dimension = "ambiente"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Pier STAGING")
        }
        create("prod") {
            dimension = "ambiente"
            resValue("string", "app_name", "Pier Repostería")
        }
    }

    signingConfigs {
        if (hayLlaveRelease) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (hayLlaveRelease) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
