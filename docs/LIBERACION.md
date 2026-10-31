# Liberación de versiones

Cómo se publica una versión de la app y cómo se decide si llega a todos los
clientes (#22). Las métricas que deciden cada paso están en #24.

## Publicar una versión

1. Pull Request `build: subir versión a X.Y.Z+N` hacia `develop` y después
   `develop` → `main` (estrategia de ramas del README), con la versión
   nueva en `pubspec.yaml` y en `lib/config/app_version.dart` (ver
   [Versionado](../README.md#versionado-semver)).
2. Con el PR mezclado, crear el tag sobre `main`:

   ```bash
   git switch main && git pull
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```

3. El tag dispara **Publicar versión** (`.github/workflows/release.yml`), en
   dos trabajos encadenados:
   1. **Pruebas en el entorno de liberación** (`pruebas-entorno-liberacion`):
      - levanta el entorno aislado de las pruebas con `tool/entorno_pruebas.sh`
        (la API del backend y su base en contenedores, con datos ficticios);
      - construye el **candidato de liberación**: el APK en modo release,
        flavor `prod`, ofuscado como el que se publica (ver
        [Ofuscación y símbolos](#ofuscación-y-símbolos)), apuntando a ese
        entorno (`http://10.0.2.2:3000/api` desde el emulador), sin Sentry y
        firmado con la llave de pruebas;
      - lo instala en el emulador (Android 14, Pixel 6) y corre el smoke
        (`tool/smoke_liberacion.dart`): la app abre, la pestaña «Catálogo»
        muestra un producto de la semilla y, desde «Más» → «Iniciar Sesión»,
        entra con la cuenta de la semilla hasta que el Inicio saluda
        «Hola, Cliente». Deja una captura por paso en Artifacts
        (`resultados-entorno-liberacion`).
   2. **APK firmado y Release** (`publicar`), solo si el smoke pasó y alguien
      con permiso lo aprueba en el Environment `produccion`:
      - comprueba que el tag sea la versión del `pubspec.yaml`;
      - arma el APK de release (flavor `prod`), ofuscado y con Sentry
        encendido;
      - comprueba que lo firmó la llave del equipo (huella SHA-1
        `F3:A4:02:DF:C1:97:80:28:A1:D4:17:23:66:40:2C:64:AD:C3:B0:C1`);
      - sube a Sentry los símbolos de Dart y el mapa de nombres
        (`tool/subir_simbolos.sh`) y los guarda 90 días en Artifacts
        (`simbolos-vX.Y.Z`); si falta el token o la subida falla, no publica;
      - publica la Release `vX.Y.Z` con el APK `pier-reposteria-vX.Y.Z.apk` y
        las notas sacadas de los commits desde el tag anterior;
      - revisa, sin escribir nada, que producción responda:
        `GET https://pier-reposteria-backend.onrender.com/api/health` debe dar
        200.

Si cualquier comprobación falla, no se publica nada y el Summary de la corrida
dice por qué.

**Probar sin publicar (ensayo):** Actions → Publicar versión → Run workflow, con
«Ensayo» marcado (viene así por omisión). Corre las pruebas en el entorno de
liberación completas y no publica nada, sin crear tags. Además sube a Sentry
los símbolos del candidato, para comprobar el token y la subida, y deja el APK
ofuscado 7 días en Artifacts (`candidato-ofuscado`). Desde la terminal:
`gh workflow run release.yml --ref main -f ensayo=true`.

## Environment `produccion`

La publicación espera la aprobación de una persona. Se configura una sola vez en
GitHub (lo hace quien administra el repositorio):

1. Settings → Environments → **New environment** → nombre `produccion` →
   **Configure environment**.
2. En **Deployment protection rules**, marcar **Required reviewers**, agregar a
   quien aprueba las versiones y **Save protection rules**.
3. En **Deployment branches and tags**, elegir **Selected branches and tags** →
   **Add deployment branch or tag rule** → tipo **Tag**, patrón `v*` → **Add
   rule**. Así solo un tag de versión puede publicar.

Con un tag, la corrida se detiene en «APK firmado y Release» con el aviso
*Waiting for review*; quien aprueba entra a la corrida → **Review deployments**
→ marca `produccion` → **Approve and deploy**. Si la rechaza, no se publica nada.
La página del Environment (Settings → Environments → `produccion`) guarda cada
publicación aprobada.

## Secretos del repositorio

En Settings → Secrets and variables → Actions → New repository secret:

| Secreto | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | La llave `.jks` convertida a base64 (abajo) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` de `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` de `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` de `android/key.properties` |
| `SENTRY_DSN` | El DSN del proyecto `flutter` en Sentry (Settings → Client Keys) |
| `SENTRY_AUTH_TOKEN` | Token de organización de Sentry para subir los símbolos: organización `pier-reposteria` → Settings → Developer Settings → Organization Tokens (permiso `org:ci`) |

Para la llave en base64, en PowerShell (copia el resultado al portapapeles, sin
mostrarlo en pantalla):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\a\pier-release.jks")) | Set-Clipboard
```

Un secreto guardado ya no se puede leer, solo reemplazar. Sin los cuatro de la
llave el workflow se detiene: nunca publica un APK firmado con la llave de
pruebas. Sin `SENTRY_DSN` publica, pero avisa que esa versión no reportará
errores. Sin `SENTRY_AUTH_TOKEN` se detiene antes de publicar: una versión
ofuscada sin sus símbolos en Sentry manda errores ilegibles.

## Ofuscación y símbolos

La versión publicada va ofuscada en sus dos capas (#224):

- **Java/Kotlin** (la parte nativa de Android y los plugins): R8 la reduce y
  renombra (`android/app/build.gradle.kts`, `proguard-rules.pro`).
- **Dart** (la app, compilada en `libapp.so`): `--obfuscate` renombra las
  clases y funciones, y `--split-debug-info` guarda aparte sus símbolos, un
  `app.android-<arquitectura>.symbols` por arquitectura, con el mapa de
  nombres (`obfuscation.map.json`, de `--save-obfuscation-map`).

`release.yml` sube los símbolos y el mapa a Sentry con `sentry-cli` (versión
fija en `tool/subir_simbolos.sh`): así Sentry muestra los rastros de los
errores y los tipos de excepción con sus nombres reales. También quedan en
Artifacts; para leer a mano un rastro ofuscado:
`flutter symbolize -i rastro.txt -d app.android-arm64.symbols`.

Al escribir código:

- no depender de `runtimeType.toString()` ni de nombres de clases como texto
  (en la versión publicada salen renombrados);
- los nombres de los `enum` (`.name`) no se ofuscan;
- las rutas de go_router, que Sentry usa como nombre de pantalla, son texto y
  no cambian.

El repositorio es público: los símbolos en Artifacts no revelan nada que no
esté ya en el código. La ofuscación dificulta leer el APK, no lo protege:
ningún secreto debe ir dentro de la app.

## Certificado fijado del API

Desde #219 la app solo acepta la conexión con
`pier-reposteria-backend.onrender.com` si su cadena llega a uno de los
certificados de `lib/data/services/certificados_api.dart`: el intermedio
**GTS WE1** (vence el **20-feb-2029**) o, de respaldo, la raíz **GTS Root R4**
(vence el 22-jun-2036). La hoja (`onrender.com`) se renueva cada ~90 días y no
se fija. El entorno aislado por http y los demás servicios (Stripe,
Cloudinary, Google, Sentry) no se fijan.

**Revisarlo** antes de que venza el intermedio (a más tardar a fines de 2028),
cada vez que Render anuncie un cambio de certificados, y si la app empieza a
decir «No pudimos conectar con Pier» con el servidor arriba:

```sh
openssl s_client -showcerts -servername pier-reposteria-backend.onrender.com   -connect pier-reposteria-backend.onrender.com:443 < /dev/null
```

Si el intermedio o la raíz cambiaron, se agregan los nuevos **junto a** los
actuales en `certificados_api.dart` (con su huella:
`openssl x509 -noout -fingerprint -sha256`), se publica una versión y se
quitan los viejos hasta que todos la instalaron. Un certificado fijado que ya
no corresponde deja a todos sin servicio hasta que instalen un APK nuevo.

## Estrategia canary

Cada versión pasa primero por un grupo pequeño y avanza solo si las métricas
lo permiten. Las métricas, sus objetivos, el dashboard de Sentry y la regla
de avance están en [SLO.md](SLO.md) (#24).

1. **Canary (48 h):** los dueños de Pier instalan el APK de la Release en sus
   celulares y usan la app normalmente.
2. **Revisión:** en Sentry, *crash-free sessions* ≥ 99.5 % durante esas 48 h y
   ningún error nuevo en el pago.
3. **Play Console, despliegue gradual:** 10 % → 50 % → 100 % de los usuarios.
   Cada paso espera 48 h y avanza solo si *crash-free sessions* sigue
   ≥ 99.5 %. Play Store pide el paquete `.aab`, no el APK: `release.yml` lo
   arma firmado y lo adjunta a la Release (#226). Lo que pide la ficha y las
   fechas de la prueba cerrada están en [PLAY_STORE.md](PLAY_STORE.md).
4. **Rollback:** si *crash-free sessions* baja de 99 % o aparece un error grave,
   se detiene el despliegue en Play Console (los que ya actualizaron se quedan
   en esa versión; Play no deja regresar a la anterior), se corrige y se
   publica `vX.Y.Z+1` con el `+BUILD` más alto.
