# Publicar en Google Play

Lo que pide Google Play para publicar Pier Repostería, qué ya está, qué falta y
quién lo hace. El paquete lo arma `release.yml` (#226); la estrategia de
despliegue gradual y el rollback están en [LIBERACION.md](LIBERACION.md).

## Fechas

Una cuenta de desarrollador personal creada después del 13-nov-2023 no puede
pedir acceso a producción sin antes correr una **prueba cerrada con al menos
12 testers inscritos durante 14 días seguidos** (una cuenta de organización
no lo necesita). Para llegar a la entrega del 26-nov:

| Fecha | Qué |
|---|---|
| **5-nov, a más tardar** | Primera subida del AAB a la prueba cerrada y los 12 testers inscritos |
| 19-nov | Se cumplen los 14 días con los 12 testers |
| 19 a 25-nov | Solicitud de acceso a producción y revisión de Google (puede tardar varios días) |

Si la subida se atrasa, los 14 días se recorren y la revisión ya no cabe antes
del 26-nov.

## El paquete: AAB firmado

- `release.yml` arma `pier-reposteria-vX.Y.Z.aab` junto al APK, firmado con la
  llave del equipo (huella SHA-1 `F3:A4:…:B0:C1`, la misma del APK) y con
  Sentry encendido, y lo adjunta a la Release. El trabajo de pruebas también
  arma el AAB (con la llave de pruebas, sin publicarlo) para comprobar que
  compila: la corrida a mano en modo ensayo lo revisa sin publicar nada.
- La primera Release con AAB es la siguiente versión que se etiquete después
  de mezclar #226. Si hace falta antes del 5-nov sin etiquetar, se puede armar
  en la laptop, que tiene `android/key.properties`:
  `flutter build appbundle --release --flavor prod --dart-define=SENTRY_DSN=<dsn>`.
- **Play App Signing** (obligatorio para apps nuevas): la llave del equipo pasa
  a ser la *llave de subida* y Google firma lo que llega a los celulares con
  la suya. Play Console muestra la huella SHA-1 de esa llave de Google:
  **hay que agregarla al cliente OAuth de Android en Google Cloud**, o el
  inicio con Google falla en la app instalada desde Play.
- `versionCode` sale del `+BUILD` de `pubspec.yaml` y nunca puede repetirse ni
  bajar (LIBERACION.md).
- `targetSdk` 36 y `minSdk` 24: cumplen lo que pide Play.

## Ficha de la tienda

| Elemento | Requisito de Play | Estado | Quién |
|---|---|---|---|
| Nombre | Hasta 30 caracteres | «Pier Repostería» (el del launcher) | Usuario confirma |
| Descripción corta | Hasta 80 caracteres | Falta | Usuario (borrador: Claude) |
| Descripción completa | Hasta 4,000 caracteres | Falta | Usuario (borrador: Claude) |
| Ícono de la ficha | 512 × 512, PNG de 32 bits, hasta 1 MB | Falta. **El ícono de la app hoy es el de Flutter** (`android/app/src/main/res/mipmap-*`); la fuente es `assets/images/logo.png` (dorado sobre transparente): hay que decidir el fondo | Usuario decide el diseño; Claude genera los tamaños |
| Gráfico destacado | 1024 × 500, JPG o PNG de 24 bits sin transparencia | Falta | Usuario |
| Capturas de teléfono | De 2 a 8; JPG o PNG de 24 bits; cada lado entre 320 y 3840 px y **el largo no más del doble del corto** | Hay capturas publicables en `capturas/` (columna «Publicable» de su índice), pero miden 1080 × 2280 (más de 2:1): hay que recortarlas, por ejemplo a 1080 × 2160 | Claude recorta; usuario elige |
| Categoría | — | Comida y bebida | Usuario |
| Correo de contacto | Obligatorio | `pierreposteria@gmail.com` (`lib/config/business_info.dart`) | Usuario confirma |
| Sitio web | Opcional | `https://pier-reposteria.vercel.app` | — |

## Política y formularios

| Elemento | Estado | Quién |
|---|---|---|
| **URL de la política de privacidad** | Por ahora `https://pier-reposteria.vercel.app/legales?tab=privacy` (el aviso que sirve el backend, con la sección de derechos ARCO) | Usuario la captura |
| **URL para pedir el borrado de la cuenta** | **Falta**: Play exige una página web que funcione sin instalar la app, además del borrado dentro de la app (#222) | Pedro (página y endpoint de baja); app en #222 |
| **Seguridad de los datos** | Falta llenar el formulario; ver la tabla de abajo | Usuario (con esta tabla) |
| **Acceso a la app** (cuenta para los revisores) | Falta: la mayor parte de la app pide sesión. Hace falta una cuenta de cliente **solo para revisores** (no la personal de `~/.pier_prueba`) y las instrucciones: entrar con correo; el pago está en modo de prueba de Stripe y se paga con la tarjeta pública 4242 4242 4242 4242 | Usuario o Pedro crean la cuenta |
| Clasificación del contenido (IARC) | Falta el cuestionario (tienda de comida, sin contenido sensible) | Usuario |
| Público objetivo | Falta: mayores de 18 (no está dirigida a niños) | Usuario |
| Anuncios | No tiene anuncios | Usuario lo declara |
| Prueba cerrada | Falta crear la pista, la lista de 12 testers y el enlace de inscripción | Usuario |

### Seguridad de los datos (borrador para el formulario)

| Dato | Para qué | ¿Obligatorio? |
|---|---|---|
| Nombre, correo y teléfono | Cuenta y pedidos | Sí |
| Dirección de entrega | Pedidos a domicilio | Solo a domicilio |
| Historial de compras | Pedidos, reembolsos y recomendaciones | Sí |
| Datos de pago | Los procesa Stripe; la app no guarda la tarjeta | Solo al pagar |
| Fotos | Evidencia de un reembolso | Opcional |
| Ubicación precisa | Coordenadas de la dirección, si se acepta el permiso (#227) | Opcional |
| Reseñas | Contenido que publica el cliente | Opcional |
| Búsquedas y clics en agotados | Registro de demanda | Se podrá desactivar (#223) |
| Registros de fallos y diagnósticos | Sentry, solo en las versiones de Release | Se podrá desactivar (#223) |

- Todo viaja cifrado (https).
- El cliente puede pedir que se borren sus datos: depende de #222.
- Revisar con Sentry si su identificador de instalación cuenta como
  «identificador del dispositivo» para el formulario.

## Antes de cada subida

1. Mezclar a `main`, subir la versión y etiquetar (LIBERACION.md).
2. Bajar el `.aab` de la Release y subirlo a la pista que toque (prueba
   cerrada, luego producción con despliegue gradual).
3. Revisar el informe previo al lanzamiento que Play genera con el AAB.
