plugins {
    id("com.android.application")
    // kotlin-android eliminado: Flutter 3.44+ compila Kotlin con Built-in Kotlin.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pier_pasteleria"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.pier_pasteleria"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // Required for flutter_stripe
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
