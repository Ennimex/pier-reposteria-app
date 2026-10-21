# Liberación de versiones

Cómo se publica una versión de la app y cómo se decide si llega a todos los
clientes (#22). Las métricas que deciden cada paso están en #24.

## Publicar una versión

1. Pull Request `build: subir versión a X.Y.Z+N` hacia `main`, con la versión
   nueva en `pubspec.yaml` y en `lib/config/app_version.dart` (ver
   [Versionado](../README.md#versionado-semver)).
2. Con el PR mezclado, crear el tag sobre `main`:

   ```bash
   git switch main && git pull
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```

3. El tag dispara **Publicar versión** (`.github/workflows/release.yml`):
   - comprueba que el tag sea la versión del `pubspec.yaml`;
   - arma el APK de release (flavor `prod`) con Sentry encendido;
   - comprueba que lo firmó la llave del equipo (huella SHA-1
     `F3:A4:02:DF:C1:97:80:28:A1:D4:17:23:66:40:2C:64:AD:C3:B0:C1`);
   - publica la Release `vX.Y.Z` con el APK `pier-reposteria-vX.Y.Z.apk` y las
     notas sacadas de los commits desde el tag anterior.

Si cualquier comprobación falla, no se publica nada y el Summary de la corrida
dice por qué.

**Probar sin publicar:** Actions → Publicar versión → Run workflow. Arma y firma
el APK igual, pero lo deja 7 días en Artifacts en vez de crear una Release.

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
