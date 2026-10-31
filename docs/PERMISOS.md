# Permisos de Android

Qué permisos declara la app, para qué los usa y cuándo los pide (#227). La
regla: pedir solo lo que aporta algo, en el momento en que se usa y después de
explicar para qué. Sin el permiso, la app sigue funcionando.

## Permisos del APK de release

| Permiso | Tipo | Para qué | Cuándo se pide | Sin él |
|---|---|---|---|---|
| `INTERNET` | Normal (no se pide) | Hablar con el API, Stripe, Google y Sentry | Nunca: Android lo da al instalar | — |
| `ACCESS_NETWORK_STATE` | Normal (no se pide) | Saber si hay red (lo declaran los plugins) | Nunca | — |
| `ACCESS_FINE_LOCATION` y `ACCESS_COARSE_LOCATION` | **Peligroso: en tiempo de ejecución** | Guardar el punto exacto de una dirección de entrega, para que el repartidor llegue sin perderse | Solo al tocar «Usar mi ubicación» en el formulario de dirección, después de la explicación | La dirección se guarda igual, escrita a mano |

`AndroidManifest.xml` explica la ubicación en un comentario junto a los
permisos. Para ver la lista real de un APK:

```sh
aapt dump permissions pier-reposteria-vX.Y.Z.apk
```

## Lo que la app no pide

- **Cámara (`CAMERA`):** las fotos de un reembolso y la de una entrega se
  toman con la app de cámara del teléfono (`image_picker`), que no necesita
  el permiso. Igual, antes de abrirla la app explica para qué es la foto y el
  cliente puede decir «Ahora no».
- **Notificaciones (`POST_NOTIFICATIONS`):** la app no manda notificaciones
  push; las del cliente y del personal se consultan dentro de la app.
- **Ubicación en segundo plano:** nunca se lee la ubicación con la app
  cerrada ni fuera del formulario de dirección.

## Cómo se pide la ubicación

1. El cliente toca «Usar mi ubicación».
2. La app muestra «Usar tu ubicación» con el motivo y dos opciones: «Ahora no»
   (no se pide nada) y «Continuar».
3. Con «Continuar», Android muestra su diálogo de permiso.
4. Según la respuesta:
   - **Lo da:** se lee la posición una vez y la dirección se guarda con sus
     coordenadas (`lat` y `lng` en `POST /direcciones`).
   - **Lo niega:** la dirección se guarda sin coordenadas.
   - **Lo niega para siempre:** la app lo dice y ofrece «Abrir Ajustes».
   - **La ubicación del teléfono está apagada:** la app pide activarla.

Código: `lib/data/services/ubicacion_service.dart`,
`lib/ui/core/ui/explicacion_permiso.dart` y
`lib/ui/checkout/widgets/direccion_form_sheet.dart`.
