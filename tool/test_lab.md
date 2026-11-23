# Firebase Test Lab: correr la prueba de integración en celulares reales

Piloto de #75; se reutilizó en #81 (fragmentación, Sprint 5). Test Lab es una
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
./gradlew app:assembleProdDebug -Ptarget=integration_test/test_lab_test.dart
cd ..
```

En Windows usa `gradlew.bat`. El `target` va relativo a la raíz del repo:
`gradlew.bat` falla si un argumento lleva espacios (la carpeta «Pier Movil»).
Si el repo está en una carpeta con espacios, se compila desde una copia en una
ruta sin espacios (por ejemplo `C:\src\pier_testlab`) y la copia se borra al
terminar. Al borrarla en Windows no hay que seguir los enlaces de
`windows/flutter/ephemeral/.plugin_symlinks` y `linux/…`: apuntan a la caché
de paquetes y un borrado recursivo que los siga la deja vacía. Primero se
quitan los enlaces (sin tocar su destino) y después el resto; las rutas de
`build/` pasan de 260 caracteres, así que hace falta el prefijo `\\?\`.

Con `-Ptarget` solo cabe un archivo por APK, y cada combinación de modelo y
versión gasta una prueba de la cuota. Por eso
`integration_test/test_lab_test.dart` junta el smoke
(`app_smoke_test.dart`) y el flujo principal
(`aceptacion/flujo_principal_test.dart`): 3 casos en una sola corrida. Para
correr solo el smoke, el `target` es `integration_test/app_smoke_test.dart`.

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

Qué elegir:

- **Los que tengan unidades libres.** `gcloud firebase test android models
  describe <modelo>` dice la capacidad de cada versión (`deviceCapacity`). Con
  capacidad baja la corrida puede pasar mucho tiempo en la fila.
- **Un ancho de pantalla distinto al del Samsung del equipo** (411 dp). El
  ancho en dp es `screenX × 160 / screenDensity`. Las pantallas de 360 dp (los
  Galaxy S, 1080 px a 480 dpi) son las que encontraron las fallas de #81.
- **Ningún Xiaomi.** HyperOS no deja que la prueba abra la app desde segundo
  plano (`Abort background activity starts` en el logcat): la corrida se agota
  sin resultado y gasta una prueba de la cuota.

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

## Resultados de #81 (fragmentación), 21-nov-2026

`integration_test/test_lab_test.dart` (3 casos: los 2 del smoke y el flujo
principal), compilado de `develop` (`b1ad8e5`), flavor prod, `locale=es_MX`,
vertical.

| Dispositivo | Tipo | Android (API) | Ancho | Resultado |
|---|---|---|---|---|
| Medium Phone 6.4" (`MediumPhone.arm`) | Virtual | 14 (34) | 411 dp | 3/3 ✅ (validación previa) |
| Motorola G20 (`java`) | Físico | 11 (30) | 411 dp | 3/3 ✅ |
| Google Pixel 10 (`frankel`) | Físico | 16 (36) | 411 dp | 3/3 ✅ |
| Small Phone 4.65" (`SmallPhone.arm`) | Virtual | 10 (29) | 360 dp | 2/3 ❌: falla el flujo principal |
| Xiaomi 14 (`houji`) | Físico | 15 (35) | 400 dp | Sin resultado: HyperOS no dejó abrir la app |

- **Fallas encontradas (fragmentación):** en el teléfono de 360 dp, las
  tarjetas del catálogo se desbordan 9.1 px (#362) y el botón de compra del
  detalle queda solo con el ícono, sin «Añadir» (#364). Son de la app y no se
  ven en pantallas de 411 dp.
- **Repetición con los arreglos** (23:00, `develop` en `732e196`, matriz
  `matrix-1yo1rc6yqh296`): Small Phone 4.65" con Android 10 (360 dp), 3/3 ✅, y
  Samsung Galaxy S24 (`e1q`) físico con Android 14 (360 dp), 3/3 ✅. 8 min en
  total, 6 de fila.
- **Cuota usada:** 3 de 5 pruebas físicas del día y 2 de 10 virtuales; con la
  repetición, 4 de 5 y 3 de 10.
- **Tiempos:** 7 min la validación en el virtual y 19 min la corrida de los
  otros cuatro (incluye la fila y los 10 min que agotó el Xiaomi).
- **Costo:** $0.
- La bitácora completa está en
  [`docs/pruebas-dispositivo-sprint-5.md`](../docs/pruebas-dispositivo-sprint-5.md).

### Aviso: Test Lab se cierra el 30-sep-2027

Firebase Test Lab está descontinuado; funciona (también con la cuota gratis
de Spark) hasta el **30 de septiembre de 2027**. Su reemplazo, *Developer
Device Platform* de Google Cloud, **exige facturación activa** y cambia a pago
por uso o suscripción desde el 30 de abril de 2027. Para #81 (Sprint 5) no
cambia nada; después de esa fecha habrá que decidir si se paga o se
sustituye por emuladores y los celulares del equipo.
Ver <https://firebase.google.com/docs/test-lab/migrate-faq>.
