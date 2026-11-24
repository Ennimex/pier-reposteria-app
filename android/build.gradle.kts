allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Versiones dinámicas ("+") que piden los plugins, cambiadas por una fija. Con
// un "+", Gradle lee la lista de versiones en todos los repositorios, también
// en Maven Central, que en el pipeline contestaba 429 (Too Many Requests).
// test/regresion/dependencias_android_test.dart avisa si integration_test
// (androidx.test) o stripe_android (com.stripe) piden una que no esté aquí; a
// los demás plugins no los revisa.
val versionesFijas =
    mapOf(
        // #383: del plugin integration_test del SDK de Flutter; se revisan al
        // subir de versión de Flutter. Lo demás se resuelve igual: espresso-core
        // 3.3.0 pide runner 1.3.0 y Gradle se sigue quedando con esa.
        "androidx.test:runner:1.2+" to "1.2.0",
        "androidx.test:rules:1.2+" to "1.2.0",
        "androidx.test.espresso:espresso-core:3.3+" to "3.3.0",
        // #387: el SDK de Stripe, del plugin stripe_android de flutter_stripe
        // 13.1.0. Se actualizan a propósito junto con flutter_stripe: al
        // subirlo, aquí va la más alta publicada del rango que pida su
        // stripe_android, la misma en las dos.
        "com.stripe:stripe-android:23.10.+" to "23.10.1",
        "com.stripe:financial-connections:23.10.+" to "23.10.1",
    )

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            val pedido = "${requested.group}:${requested.name}:${requested.version}"
            versionesFijas[pedido]?.let { version ->
                useVersion(version)
                because("#383 y #387: sin versiones dinámicas")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
