# Pruebas en dispositivo — Sprint 3 (#79)

Medimos cuánta memoria, CPU y batería consume la app en un teléfono real con el
APK de release, y si sigue funcionando con la batería baja y el ahorro de
energía activado. Los valores quedan junto a la línea base de rendimiento de
#61 y se repiten en #71 con la versión candidata.

## Datos de la prueba

| Dato | Valor |
|---|---|
| Fecha | Jueves 22 de octubre de 2026, de 20:51 a 21:08 (hora de México) |
| Dispositivo | Samsung Galaxy Note10+ (SM-N975U), Android 12, conectado por Wi-Fi |
| App | **Pier** de la Release [v2.1.0](https://github.com/Ennimex/pier-reposteria-app/releases/tag/v2.1.0) (`mx.com.pierreposteria`, 2.1.0+4), el APK firmado que publica `release.yml` |
| Servidor | El real (`pier-reposteria-backend.onrender.com`), con una cuenta de cliente |
| Cómo se midió | Comandos `adb` desde la laptop conectada por USB: `dumpsys meminfo`, `top` y `dumpsys batterystats`. No se instaló nada en la app |

## Resumen

| # | Medición | Resultado | Umbral |
|:-:|---|---|:-:|
| 1 | Memoria al abrir, tras 5 min en el catálogo y al volver del segundo plano | 285 → 307 → 267 MB (PSS); sube y baja con las fotos, sin crecer sin parar | ✅ Estable |
| 2 | CPU en reposo, navegando y en segundo plano | Reposo ~3 %, navegando 28 % de promedio, segundo plano 0 a 2 % | ✅ Cerca de 0 % en reposo |
| 3 | Batería en 9 min 32 s de uso normal | 4.51 mAh (≈ 0.7 % de la batería por hora, sin contar la pantalla); sin wakelocks propios | ✅ |
| 4 | Batería al 5 % con ahorro de energía | Catálogo y checkout funcionan | ✅ |

Pendiente del paso 1: comparar con la vista de memoria de Flutter DevTools
usando el APK de profile.

## 1. Memoria

`adb shell dumpsys meminfo mx.com.pierreposteria`, en kB redondeados a MB. PSS
es la memoria que el sistema le cuenta a la app (la compartida se reparte entre
quienes la usan).

| Momento | Hora | PSS total | Gráficos | Nativa | Java | Código |
|---|:-:|--:|--:|--:|--:|--:|
| Al abrir (arranque en frío, Inicio) | 20:51 | 285 MB | 117 MB | 54 MB | 9 MB | 60 MB |
| Tras 5 min navegando el catálogo | 20:58 | 307 MB | 148 MB | 60 MB | 7 MB | 52 MB |
| Tras 1 min en segundo plano | 21:00 | 273 MB | 99 MB | 69 MB | 6 MB | 52 MB |
| Al volver del segundo plano | 21:00 | 267 MB | 95 MB | 73 MB | 7 MB | 52 MB |
| Tras usar carrito y checkout | 21:03 | 284 MB | 109 MB | 72 MB | 9 MB | 52 MB |

Durante los 5 min del catálogo se tomó el PSS cada 30 s: **297, 278, 292, 251,
265, 265, 270, 269, 281, 275 y 310 MB**. Sube al cargar fotos nuevas y baja
cuando se liberan; no hay una subida continua. La mayor parte son gráficos (las
imágenes del catálogo y el carrusel). En segundo plano la app soltó 49 MB de
gráficos.

## 2. CPU

`adb shell top -b -n 1 -p <pid> -o PID,%CPU,RES`. `top` cuenta 100 % por cada
núcleo, así que 50 % es medio núcleo.

| Momento | Muestras | Resultado |
|---|:-:|---|
| Reposo en Inicio, recién abierta | 5 (1 por segundo) | 3.4, 2.0, 6.0, 42.0 y 1.0 % (mediana 3.4 %). El pico coincide con el cambio automático del carrusel |
| Navegando el catálogo (scroll, productos y categorías) | 64 (cada 4 s, 5½ min) | Promedio 28 %, mediana 31 %, p90 52 %, máximo 79 %; 14 muestras en 0 % (pausas) |
| En segundo plano | 5 (1 por segundo) | 0.0, 0.0, 2.0, 1.0 y 0.0 % |

Al volver del segundo plano Android la trajo al frente en **108 ms** (`am start
-W`: *HOT*), en el mismo proceso: no la había cerrado.

## 3. Batería

1. `adb shell dumpsys battery unplug`: el celular siguió conectado por USB, pero
   Android cuenta el consumo como si estuviera desconectado.
2. `adb shell dumpsys batterystats --reset` a las 20:53.
3. Uso normal: 5½ min en el catálogo, 1 min en segundo plano y unos 3 min en
   carrito y checkout (sin pagar).
4. `adb shell dumpsys batterystats --charged mx.com.pierreposteria` a las 21:03.

| Dato | Valor |
|---|---|
| Tiempo medido | 9 min 32 s con batería, 9 min con la pantalla encendida |
| Consumo estimado de Pier | **4.51 mAh**: CPU 4.48, servicios del sistema 0.01, Wi-Fi 0.02 |
| Por hora | ≈ 28 mAh, cerca del 0.7 % de la batería de 4,170 mAh |
| Wakelocks de la app | Ninguno: no mantiene el celular despierto |

Android no le asigna la pantalla a ninguna app, así que esos 4.51 mAh no la
incluyen. Pier fue la app que más consumió en ese rato porque era la que estaba
en uso.

## 4. Batería baja y ahorro de energía

1. `adb shell dumpsys battery set level 5` (con el `unplug` del paso anterior).
2. `adb shell settings put global low_power 1` (estaba en `0`).
3. En la app: catálogo, abrir un producto, agregarlo al carrito y llegar al
   checkout eligiendo fecha y hora.
4. `adb shell dumpsys battery reset` y `adb shell settings put global low_power 0`
   al terminar. El celular volvió a su 27 % real, cargando por USB.

**Resultado:** ✅ el catálogo cargó productos y fotos con el scroll fluido, y en
el checkout se pudieron elegir fecha y hora. La prueba fue después de las 21:00,
así que el botón decía «Fuera de servicio» y no dejaba pagar: es la regla del
horario de atención (`checkout_screen.dart`: fuera de horario no se crean
pedidos), no un efecto de la batería.

**Observación:** con la tienda cerrada, el aviso del checkout dice «Puedes
dejar tu pedido y lo prepararemos en horario de atención», pero el botón no
deja hacer el pedido. El texto promete algo que la app no permite.
