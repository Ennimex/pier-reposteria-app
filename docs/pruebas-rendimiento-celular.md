# Rendimiento en el celular: fluidez, arranque, CPU y memoria (#355)

Cada versión candidata se mide en el celular antes de aprobarla en el Environment `produccion`
([LIBERACION.md](LIBERACION.md#medir-en-el-celular-antes-de-aprobar)). Es la única fuente de CPU y memoria: Play
no generó informe previo al lanzamiento para la app, y el CI mide en un emulador. Los objetivos que se vigilan en
producción con Sentry están en [SLO.md](SLO.md).

Los scripts están en [`tool/rendimiento_celular/`](../tool/rendimiento_celular/):

| Archivo | Qué hace |
|---|---|
| `fluidez.sh` | 3 corridas de `integration_test/rendimiento/rendimiento_test.dart` con `flutter drive` y 3 arranques en frío con `flutter run --trace-startup` |
| `resumen_fluidez.py` | Las medianas de esas 3 corridas, por escena e indicador |
| `medir_cpu_mem.py` | CPU (`top`) y memoria (`dumpsys meminfo`) de las mismas escenas, el reposo en el Inicio y la prueba de fuga |
| `coords.json` | Dónde tocar en la pantalla (Samsung SM-N975U, pantalla lógica de 1080 × 2280) y cuánto dura cada escena |

## Condiciones

- **El celular de referencia**: Samsung SM-N975U (Android 12), conectado por USB con depuración USB. Nadie lo usa
  mientras se mide.
- **La app**: «Pier DEV» (`mx.com.pierreposteria.dev`) en **modo profile**, armada desde el **tag** de la versión
  (un worktree del tag), contra el servidor de producción. La app de la tienda (`mx.com.pierreposteria`) no se
  toca.
- **Batería arriba de 50 %** y **temperatura debajo de 35 °C** al empezar cada parte
  (`adb shell dumpsys battery`: `level` y `temperature` en décimas de grado). `medir_cpu_mem.py` se detiene si no
  se cumplen; con `IGNORAR_CONDICIONES=1` mide igual y lo deja anotado en su resultado.
- **Servidor despierto**: `GET https://pier-reposteria-backend.onrender.com/api/health` responde en menos de 1 s.
  Dormido tarda unos 20 s (21.70 s el 10-nov).
- **CPU y memoria en pasadas separadas**: `dumpsys meminfo` le pide a la propia app que mida su memoria y le sube
  la CPU. El 10-nov, con las dos lecturas a la vez, la CPU en reposo dio mediana de 10 % en lugar de 0.5 %.
- **Mediana de 3 repeticiones** en todo, salvo la fuga (5 vueltas seguidas) y el reposo (30 s).

## Cómo se corre

Desde la raíz de un worktree del tag que se mide, con la cuenta de prueba en variables de entorno (la de los
secretos `USUARIO_PRUEBA` y `CLAVE_PRUEBA` de [rendimiento-celular.yml](../.github/workflows/rendimiento-celular.yml);
nunca se escribe en archivos ni en la salida) y la serie del celular (`adb devices`) en `DISPOSITIVO`:

```bash
git worktree add ../medicion-vX.Y.Z vX.Y.Z && cd ../medicion-vX.Y.Z && flutter pub get
export USUARIO_PRUEBA=... CLAVE_PRUEBA=... DISPOSITIVO=...
SALIDA=build/rendimiento_celular/AAAA-MM-DD_vXYZ

# 1. Fluidez y arranque en frío (unos 15 min; la primera compilación tarda más)
bash tool/rendimiento_celular/fluidez.sh "$SALIDA"
python tool/rendimiento_celular/resumen_fluidez.py "$SALIDA"

# 2. CPU y memoria. Antes: «Pier DEV» abierta en el Inicio (la sesión quedó del paso 1)
#    y un producto con existencias en el carrito («Añadir» desde su detalle).
python tool/rendimiento_celular/medir_cpu_mem.py reposo  "$SALIDA" 1 cpu
python tool/rendimiento_celular/medir_cpu_mem.py escenas "$SALIDA" 3 cpu
python tool/rendimiento_celular/medir_cpu_mem.py escenas "$SALIDA" 3 mem
python tool/rendimiento_celular/medir_cpu_mem.py fuga    "$SALIDA" 5 mem
#    Al terminar: Carrito → «Vaciar».
```

Cada paso de `medir_cpu_mem.py` deja `cpu_mem_<modo>_<cpu|mem>.json` con cada lectura, su hora y las marcas de
cada escena, y al final imprime el resumen por escena. Ningún paso paga ni crea pedidos: el checkout llega hasta
la pantalla «Finalizar Pedido» y regresa.

Si Play Protect pregunta al instalar «Pier DEV», alguien tiene que responder en el celular; mientras tanto, la
instalación espera. Si se cambia de celular, se vuelven a sacar las coordenadas de `coords.json` con
`adb shell uiautomator dump` (los `bounds` de «Inicio», «Catálogo», «Carrito» y «Proceder al Pago»).

## Las escenas

Las tres de `rendimiento_test.dart`, como las vive el cliente:

| Escena | `rendimiento_test.dart` (fluidez) | `medir_cpu_mem.py` (CPU y memoria) |
|---|---|---|
| **Arranque con sesión** | El splash encuentra la sesión y arma el Inicio, más 3 s | `am force-stop`, `am start -W` y 10 s (el Inicio aparece a los ~7 s, más 3 s) |
| **Catálogo** | 5 desplazamientos hacia abajo y 5 hacia arriba, 1 s entre cada uno | Lo mismo con `input swipe` de 1,200 px en 100 ms |
| **Checkout** | Del carrito con un producto a «Finalizar Pedido», más 3 s | Pestaña Carrito, 3 s, «Proceder al Pago» y 7 s |

`medir_cpu_mem.py` deja 10 s sin tocar después de cada escena. Fuera de esas ventanas confirma con uiautomator
que se ve la pantalla esperada y, antes de cada toque, que «Pier DEV» siga al frente; si no, se detiene.

- **CPU**: `top -b -d 1` del celular, una lectura por segundo. Se expresa en **% de un núcleo** (100 % = un núcleo
  completo; el SM-N975U tiene 8). **Reposo** = 3 lecturas seguidas de 5 % o menos.
- **Memoria**: «TOTAL PSS» de `dumpsys meminfo`, una lectura cada 0.7 a 1 s. «Al terminar» es la primera lectura
  después del fin de la escena; «máximo», la mayor dentro de ella.
- **Fuga**: la app recién abierta (vuelta 0) y 5 vueltas completas sin cerrarla (Catálogo con los 10
  desplazamientos → Carrito → «Proceder al Pago» → atrás → Inicio), con el TOTAL PSS al final de cada vuelta. La
  vuelta 1 llena las cachés (fotos y páginas del catálogo); de ahí en adelante debe quedar plana.

## Umbrales

Línea base del 10-nov-2026: v2.5.0, medianas de 3. Ese día la batería estuvo entre 24 % y 28 % (fuera de la
condición); la siguiente medición con las condiciones completas la confirma o la reemplaza.

### Fluidez y arranque en frío (regla del #71)

Ningún indicador empeora más de 10 % contra la línea base y todo p90 de cuadro queda en 16 ms o menos. Línea base:
la del #61 (21-oct), con el arranque de la línea base nueva del #324.

| Escena e indicador | Línea base | Umbral | 10-nov (v2.5.0) |
|---|--:|--:|--:|
| Arranque · p90 de construcción | 5.5 ms | ≤ 6.1 ms | 6.34 ms |
| Arranque · p90 de rasterizado | 9.9 ms | ≤ 10.9 ms | 9.62 ms |
| Catálogo · p90 de construcción | 11.2 ms | ≤ 12.3 ms | 8.01 ms |
| Catálogo · p90 de rasterizado | 15.2 ms | ≤ 16 ms | 10.51 ms |
| Checkout · p90 de construcción | 6.6 ms | ≤ 7.3 ms | 6.17 ms |
| Checkout · p90 de rasterizado | 14.8 ms | ≤ 16 ms | 9.32 ms |
| Arranque en frío (primer cuadro dibujado) | 1,590 ms | ≤ 3 s | 826 ms |

El 10-nov el p90 de construcción del arranque (6.34 ms; corridas de 5.44, 7.20 y 6.34 ms) pasó su umbral por
0.24 ms; el peor cuadro del Inicio se sigue en el #341.

### CPU y memoria

| Medida | Línea base (arranque · catálogo · checkout) | Falla si |
|---|---|---|
| CPU promedio en la escena | 54.7 % · 50.1 % · 13.7 % | sube más de 20 % **y además** más de 10 puntos: arriba de 65.6 % · 60.1 % · 23.7 % |
| CPU máxima en la escena | 101 % · 64 % · 49 % | pasa de 150 % |
| Vuelta a reposo después de la escena | 4.3 s · 1.4 s · 0.4 s | tarda más de 5 s (sin contar la primera repetición después de abrir la app) |
| CPU con el Inicio quieto (30 s) | mediana 0.5 %, promedio 10.0 % | la mediana pasa de 5 % o el promedio de 15 % |
| TOTAL PSS al terminar la escena | 327.7 · 389.5 · 394.2 MB | sube más de 15 %: arriba de 376.9 · 447.9 · 453.3 MB |
| TOTAL PSS máximo en la escena | 339.2 · 394.8 · 394.2 MB | sube más de 15 %: arriba de 390.1 · 454.0 · 453.3 MB |
| Fuga: TOTAL PSS de la vuelta 1 a la 5 | +1.7 % (426.0 → 433.2 MB) | crece más de 5 % |

Por qué así:

- **CPU promedio**: la misma idea que el CI para los tiempos (porcentaje y un mínimo absoluto). Entre repeticiones
  varió hasta 25 puntos (arranque de 38 % a 63 %); los 10 puntos evitan fallar por ruido en el checkout, que es bajo.
- **CPU máxima**: abrir la app ocupa un núcleo completo (93 % a 102 %). Más de 1.5 núcleos en un segundo sería
  trabajo nuevo en paralelo al dibujo, que es lo que causa tirones.
- **Vuelta a reposo**: cuando la persona deja de tocar, la app no debe seguir gastando batería; 5 s cubren
  decodificar las fotos al terminar de desplazar. La primera vez que se abre el catálogo tarda más de 10 s mientras
  carga las fotos.
- **CPU con el Inicio quieto**: si el promedio sube, algo más se anima o consulta sin que nadie toque. Hoy el
  promedio de 10 % viene de un pico de ~25 % cada 5 s (#352).
- **Memoria**: entre repeticiones el PSS varió hasta 17 % (catálogo de 366 a 428 MB); con menos de 15 % fallaría
  por ruido. Atrapa una versión que cargue de más.
- **Fuga**: después de la vuelta 1 la memoria debe quedar plana; el 10-nov creció 1.7 % con 16 MB de variación
  natural entre vueltas.

## Qué hacer con el resultado

1. Anotar la tabla (fluidez, arranque en frío, CPU y memoria, con la batería y la temperatura de cada parte) en el
   issue o el PR de la versión, como en el #71 y el #324.
2. Si algo pasa su umbral, no aprobar `produccion` hasta decidirlo: un issue con los números y la causa probable
   (como el #324) o una línea base nueva con su razón, que se actualiza aquí.
