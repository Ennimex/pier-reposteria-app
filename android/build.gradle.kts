allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// #383: el plugin integration_test del SDK de Flutter pide androidx.test con
// versiones dinámicas. Con un "+", Gradle lee la lista de versiones en todos
// los repositorios, también en Maven Central, que en el pipeline contestaba
// 429 (Too Many Requests). Se cambian por la versión que ya resolvían; lo
// demás se resuelve igual (espresso-core 3.3.0 pide runner 1.3.0 y Gradle se
// sigue quedando con esa). test/regresion/dependencias_android_test.dart
// avisa si el SDK pide otra al subir de versión de Flutter.
val versionesFijasAndroidxTest =
    mapOf(
        "androidx.test:runner:1.2+" to "1.2.0",
        "androidx.test:rules:1.2+" to "1.2.0",
        "androidx.test.espresso:espresso-core:3.3+" to "3.3.0",
    )

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            val pedido = "${requested.group}:${requested.name}:${requested.version}"
            versionesFijasAndroidxTest[pedido]?.let { version ->
                useVersion(version)
                because("#383: sin versiones dinámicas de androidx.test")
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
