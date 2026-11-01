# Reporte de descompilación del APK release (#224)

Qué ve alguien que descarga el APK de Pier y lo descompila. Es la evidencia de que el release sale reducido y
ofuscado (Actividad 6 de DMI). Este resumen no incluye código descompilado. El análisis completo y sus
evidencias se guardan fuera del repositorio.

## Qué se analizó

| | |
|---|---|
| APK | Candidato de liberación del ensayo de `release.yml` sobre `main` (`a77de18`, todo el Sprint 4), corrida 41196120985 del 31-oct-2026 |
| Cómo se compiló | `flutter build apk --release --flavor prod --obfuscate --split-debug-info` con R8 (`isMinifyEnabled` y `isShrinkResources` explícitos y `proguard-rules.pro` propio) |
| Herramienta | JADX 1.5.6 (línea de comandos) y un script que lee los textos de `libapp.so` |
| Comparación | Con el reporte del 30-oct: la versión publicada v2.1.1 (Dart sin ofuscar) y el primer candidato ofuscado |

## Qué muestra JADX

En una app Flutter hay dos capas: la de Android (Java/Kotlin, que JADX convierte a código legible) y la de la
app (Dart, compilada a código máquina en `lib/<arquitectura>/libapp.so`, que JADX no descompila).

**Capa Java/Kotlin: clases renombradas por R8.**
- 12,759 clases; R8 renombró el 61.2 % a nombres de una o dos letras (`A.C0074a`, paquetes como `E` o `S0`).
- De la app solo quedan `MainActivity` y `R`: todo lo demás es Dart.
- El resto son librerías: Stripe (5,012 clases), Sentry (668), Google (244) y AndroidX.

**Código Dart: ofuscado.**
- Ninguna de las 455 clases del proyecto aparece por su nombre en `libapp.so`. Nombres como `ApiService`,
  `CheckoutViewModel` o `PasarelaStripe` quedan como identificadores de tres letras. El mapa para revertirlos
  (44,013 pares) no viaja en el APK: va con los símbolos a Sentry.
- En la v2.1.1, sin ofuscar, se leían 379 nombres de clases del proyecto. Ahora no se lee ninguno.
- Los pocos nombres que sí aparecen como texto (21 de 334 funciones) coinciden con textos que la app usa a
  propósito, como rutas y acciones de la API o claves de JSON, y con valores de `enum`, que Dart no ofusca.

## Secretos

- **En `libapp.so`: ninguno.** No hay llaves de Stripe (públicas ni secretas), DSN de Sentry, llaves de Google
  ni de AWS, ni llaves privadas.
- **En los recursos de Android: solo el ID público del cliente web de OAuth** que necesita el inicio de sesión
  con Google. Su secreto no está en la app.
- Las URLs son de documentación, imágenes y del servidor al que apunta el build. Ninguna lleva credenciales.

## Permisos

`INTERNET`, `ACCESS_NETWORK_STATE`, ubicación (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`) y `WAKE_LOCK`.
`WAKE_LOCK` llegó con el reproductor de videos del feed (#253): lo declara `media3-exoplayer`, que trae
`video_player`; la app no lo pide en su manifiesto. Es un permiso normal que Android concede sin preguntar.

## Conclusión

El release de `main` está reducido y renombrado en la capa de Android y ofuscado en la de Dart. Quien lo
descompile no ve los nombres de las pantallas, ViewModels ni repositorios, y no encuentra secretos.
