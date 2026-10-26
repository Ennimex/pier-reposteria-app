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
        flavor `prod`, apuntando a ese entorno (`http://10.0.2.2:3000/api`
        desde el emulador), sin Sentry y firmado con la llave de pruebas;
      - lo instala en el emulador (Android 14, Pixel 6) y corre el smoke
        (`tool/smoke_liberacion.dart`): la app abre, la pestaña «Catálogo»
        muestra un producto de la semilla y, desde «Más» → «Iniciar Sesión»,
        entra con la cuenta de la semilla hasta que el Inicio saluda
        «Hola, Cliente». Deja una captura por paso en Artifacts
        (`resultados-entorno-liberacion`).
   2. **APK firmado y Release** (`publicar`), solo si el smoke pasó y alguien
      con permiso lo aprueba en el Environment `produccion`:
      - comprueba que el tag sea la versión del `pubspec.yaml`;
      - arma el APK de release (flavor `prod`) con Sentry encendido;
      - comprueba que lo firmó la llave del equipo (huella SHA-1
        `F3:A4:02:DF:C1:97:80:28:A1:D4:17:23:66:40:2C:64:AD:C3:B0:C1`);
      - publica la Release `vX.Y.Z` con el APK `pier-reposteria-vX.Y.Z.apk` y
        las notas sacadas de los commits desde el tag anterior;
      - revisa, sin escribir nada, que producción responda:
        `GET https://pier-reposteria-backend.onrender.com/api/health` debe dar
        200.

Si cualquier comprobación falla, no se publica nada y el Summary de la corrida
dice por qué.

**Probar sin publicar (ensayo):** Actions → Publicar versión → Run workflow, con
«Ensayo» marcado (viene así por omisión). Corre las pruebas en el entorno de
liberación completas y no publica nada, sin crear tags. Desde la terminal:
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

Para la llave en base64, en PowerShell (copia el resultado al portapapeles, sin
mostrarlo en pantalla):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\a\pier-release.jks")) | Set-Clipboard
```

Un secreto guardado ya no se puede leer, solo reemplazar. Sin los cuatro de la
llave el workflow se detiene: nunca publica un APK firmado con la llave de
pruebas. Sin `SENTRY_DSN` publica, pero avisa que esa versión no reportará
errores.

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
   ≥ 99.5 %. Play Store pide el paquete `.aab` (`flutter build appbundle`), no
   el APK: se agregará al workflow con la primera subida a Play.
4. **Rollback:** si *crash-free sessions* baja de 99 % o aparece un error grave,
   se detiene el despliegue en Play Console (los que ya actualizaron se quedan
   en esa versión; Play no deja regresar a la anterior), se corrige y se
   publica `vX.Y.Z+1` con el `+BUILD` más alto.
