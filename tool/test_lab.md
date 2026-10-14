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
`android/app/src/androidTest/java/mx/com/pierreposteria/MainActivityTest.java`
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

## Resultados del piloto (#75), 11-oct-2026

Proyecto `pier-reposteria-test-lab` (plan Spark), prueba
`integration_test/app_smoke_test.dart` (2 casos: login con credenciales
inválidas y catálogo), flavor prod, `locale=es_MX`, vertical.

| Dispositivo | Tipo | Android (API) | Resultado |
|---|---|---|---|
| Medium Phone 6.4" (`MediumPhone.arm`) | Virtual | 14 (34) | 2/2 ✅ (validación previa) |
| Samsung Galaxy A10 (`a10`) | Físico | 10 (29) | 1/2 ❌ → 2/2 ✅ tras corregir la prueba |
| Samsung Galaxy A15 (`a15`) | Físico | 14 (34) | 2/2 ✅ |
| Samsung Galaxy S24 (`SC-51E`) | Físico | 16 (36) | 2/2 ✅ |

- **Fallo encontrado (fragmentación):** en el Galaxy A10, de pantalla chica,
  el teclado real tapaba el botón «Iniciar Sesión» y el toque de la prueba
  caía en la lista de atrás (`tap() ... would not hit test` en el logcat). La
  prueba ahora cierra el teclado y espera antes de tocar. No es un fallo de la
  app: la persona cierra el teclado o hace scroll.
- **Cuota usada:** 4 de 5 pruebas físicas del día (3 del piloto + 1 de la
  repetición en el A10) y 1 de 10 virtuales.
- **Tiempos:** unos 7 min por corrida en virtual y de 10 a 15 min en físicos
  (incluye la fila); cada prueba tarda segundos.
- **Costo:** $0 (plan Spark, sin facturación).
- **Resultados en crudo** (video, logcat y XML por dispositivo): bucket de
  Cloud Storage que imprime `gcloud` al lanzar la corrida.

### Aviso: Test Lab se cierra el 30-sep-2027

Firebase Test Lab está descontinuado; funciona (también con la cuota gratis
de Spark) hasta el **30 de septiembre de 2027**. Su reemplazo, *Developer
Device Platform* de Google Cloud, **exige facturación activa** y cambia a pago
por uso o suscripción desde el 30 de abril de 2027. Para #81 (Sprint 5) no
cambia nada; después de esa fecha habrá que decidir si se paga o se
sustituye por emuladores y los celulares del equipo.
Ver <https://firebase.google.com/docs/test-lab/migrate-faq>.
