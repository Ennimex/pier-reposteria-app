# Firebase Test Lab: correr la prueba de integración en celulares reales

Piloto de #75; se reutiliza en #81 (fragmentación, Sprint 5). Test Lab es una
granja de dispositivos de Google: se le suben dos APK y ejecuta
`integration_test/` en los modelos que se elijan. No se agrega ningún SDK de
Firebase a la app. La prueba usa `FakeApiClient`, así que no toca el backend
ni datos reales.

Plan Spark (gratis): 10 pruebas al día en dispositivos virtuales y 5 en
físicos. Cada combinación modelo + versión cuenta como una prueba.

## Una sola vez

1. Crear un proyecto en <https://console.firebase.google.com> (plan Spark) y
   abrir **Test Lab** para activarlo.
2. Instalar Google Cloud CLI: <https://cloud.google.com/sdk/docs/install>
   (en Windows, el instalador `GoogleCloudSDKInstaller.exe`).
3. Iniciar sesión y elegir el proyecto:

   ```bash
   gcloud auth login
   gcloud config set project <id-del-proyecto-de-firebase>
   ```

Ninguna credencial se guarda en el repositorio.

## Compilar los dos APK

Desde la raíz del repo (con flavors hay que nombrar el de prod):

```bash
flutter build apk --debug --flavor prod
cd android
./gradlew app:assembleProdDebugAndroidTest
./gradlew app:assembleProdDebug -Ptarget=integration_test/app_smoke_test.dart
cd ..
```

En Windows usa `gradlew.bat`. El `target` va relativo a la raíz del repo:
`gradlew.bat` falla si un argumento lleva espacios (la carpeta «Pier Movil»).

Salen:

- App: `build/app/outputs/apk/prod/debug/app-prod-debug.apk`
- Prueba: `build/app/outputs/apk/androidTest/prod/debug/app-prod-debug-androidTest.apk`

El arranque de la prueba instrumentada está en
`android/app/src/androidTest/java/com/example/pier_pasteleria/MainActivityTest.java`
(debe estar en el mismo paquete que `MainActivity`).

## Lanzar la corrida

Ver modelos y versiones disponibles:

```bash
gcloud firebase test android models list --filter="form=PHYSICAL"
```

Corrida (un `--device` por modelo; minSdk de la app = 24):

```bash
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/apk/prod/debug/app-prod-debug.apk \
  --test build/app/outputs/apk/androidTest/prod/debug/app-prod-debug-androidTest.apk \
  --device model=<modelo-1>,version=<api>,locale=es_MX,orientation=portrait \
  --device model=<modelo-2>,version=<api>,locale=es_MX,orientation=portrait \
  --device model=<modelo-3>,version=<api>,locale=es_MX,orientation=portrait \
  --timeout 10m
```

La terminal imprime el enlace al reporte en la consola de Firebase (video,
logcat y resultado por dispositivo).

## Resultados del piloto (#75)

Llenar al terminar la primera corrida:

| Modelo | Android (API) | Resultado | Notas |
|---|---|---|---|
| | | | |

- Pruebas consumidas de la cuota diaria:
- Costo: $0 (plan Spark)
- Fallos o incompatibilidades encontradas:
