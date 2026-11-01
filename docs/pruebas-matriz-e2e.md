# Matriz de pruebas de caja negra (E2E) en debug y release (#225)

Cada caso recorre la app completa como lo haría una persona, sin mirar el código: abre la app, toca, escribe y
revisa lo que aparece en pantalla. La matriz dice, por caso, qué resultado tuvo y dónde está la evidencia en los dos
builds: **debug**, el que corre en el emulador de los pipelines, y **release**, el que se publica. Al final está el
registro de los errores encontrados y corregidos.

## Builds y entornos

| Build | Dónde corre | Contra qué servidor | Cómo se arma |
|---|---|---|---|
| Debug | Emulador de GitHub Actions: Android 14 (API 34), perfil Pixel 6 | Entorno aislado (API y base en contenedores, `10.0.2.2:3000`) o, en la regresión completa, el servidor real con la cuenta de prueba | `flutter test` / `flutter drive` sin bandera de modo |
| Release (candidato) | El mismo emulador, en el ensayo de `release.yml` | Entorno aislado | `--release --flavor prod --obfuscate --split-debug-info` |
| Release (publicado) | Samsung Galaxy Note10+ (SM-N975U), Android 12 | Servidor real | El APK firmado de la Release de GitHub |

Evidencia de esta versión de la matriz (31-oct-2026, `main` en `a77de18`, todo el Sprint 4):
- **Debug:** pipeline [41192817230](https://github.com/Ennimex/pier-reposteria-app/actions/runs/41192817230) (push a `main`), los 15 trabajos en verde.
- **Release (candidato):** ensayo de `release.yml` [41196120985](https://github.com/Ennimex/pier-reposteria-app/actions/runs/41196120985), «Pruebas en el entorno de liberación» en verde; no publicó nada.
- **Contra el servidor real:** la última regresión completa es [40575830031](https://github.com/Ennimex/pier-reposteria-app/actions/runs/40575830031) (27-oct, v2.1.1 en `003e0c9`), anterior al Sprint 4. `flujo-compra.yml` no se ha corrido.

## Matriz

✅ pasó · ⏳ pendiente · — no aplica (con la razón)

| ID | Caso | Precondición | Pasos | Resultado esperado | Debug | Release |
|---|---|---|---|---|---|---|
| E2E-01 | Inicio de sesión con credenciales inválidas (`integration_test/app_smoke_test.dart`) | Backend falso que rechaza el inicio de sesión | Abrir «Iniciar sesión» → escribir correo y contraseña → cerrar el teclado → «Iniciar Sesión» | «Credenciales inválidas»; la app sí llamó a `POST /auth/login` | ✅ 41192817230, «Pruebas rápidas (smoke) en Android 14» | ⏳ Samsung: el smoke del candidato (E2E-07) solo cubre el inicio de sesión válido |
| E2E-02 | Catálogo (`app_smoke_test.dart`) | Backend falso con listas vacías | Abrir el catálogo | Pide productos, categorías y filtros | ✅ 41192817230, mismo trabajo | ✅ 41196120985: el smoke del candidato muestra el catálogo con «Chocoflan» (E2E-07) |
| E2E-03 | Flujo principal: iniciar sesión → catálogo → detalle → carrito → checkout (`integration_test/aceptacion/flujo_principal_test.dart`) | Backend falso con `cliente@pier.test` y Chocoflan con existencias | Iniciar sesión → abrir el catálogo → abrir el detalle → «Añadir» → Carrito → «Proceder al Pago» | Una línea en el carrito y llega a «Finalizar Pedido»; 5 capturas | ✅ 41192817230, «Flujo principal en el emulador» | ✅ 27-oct en v2.1.1: compra completa en el Samsung (#62). ⏳ Repetir con el Sprint 4 |
| E2E-04 | Compra hasta el checkout en el entorno aislado (`integration_test/flujos/compra_test.dart`, escenario 1) | API y base en contenedores con la cuenta de la semilla | Iniciar sesión → vaciar el carrito → producto con existencias → «Añadir» → Carrito → «Proceder al Pago» | «Finalizar Pedido» con el producto; el carrito queda vacío al terminar | ✅ 41192817230, «Flujo de compra en el entorno aislado» | ⏳ Samsung (en release no corre ningún flujo de compra automatizado) |
| E2E-05 | Compra hasta el checkout contra el servidor real (mismo escenario) | Secretos de la cuenta de prueba; servidor despierto | Igual que E2E-04 | Igual que E2E-04 | ✅ 27-oct, regresión completa 40575830031 (v2.1.1). ⏳ Con el Sprint 4: la próxima regresión completa (martes) o `flujo-compra.yml` a mano | ✅ 27-oct en v2.1.1 (#62). ⏳ Repetir con el Sprint 4 |
| E2E-06 | Crear el intento de pago con Stripe en modo prueba (`compra_test.dart`, escenario 2) | E2E-05 y dentro del horario de la tienda (lunes a sábado, 9 a 21 h); fuera de él se omite | Checkout → Recoger, mañana, primera hora → «Pagar»; la pasarela de prueba cierra la hoja | Intento `pi_…_secret_…` con la llave `pk_test_`; sigue en el checkout y no se crea pedido | ✅ 27-oct, 40575830031 (v2.1.1). ⏳ Con el Sprint 4 | ✅ 27-oct en v2.1.1: pago con la tarjeta 4242, folio PIER-261027-2048 (#62). ⏳ Repetir con el Sprint 4 |
| E2E-07 | Smoke del candidato: abrir, catálogo e iniciar sesión (`tool/smoke_liberacion.dart`) | Entorno aislado; APK release ofuscado | Abrir en frío → barra «Catálogo» → aparece «Chocoflan» → «Más» → «Iniciar Sesión» → cuenta de la semilla → «Inicio» | «Hola, Cliente»; capturas 01 a 03 | — Es la prueba propia del build release; en debug la cubren E2E-01 a E2E-03 | ✅ 31-oct, 41196120985 (`main`, `a77de18`) |
| E2E-08 | Uso aleatorio con monkey (`esfuerzo.yml`) | Entorno aislado; app sin sesión iniciada | Abrir en frío (≤ 10 s) → 1,000 eventos con la semilla 42 → reabrir en frío → `GET /api/health` | Sin cierres ni congelamientos (CRASH/ANR); la app reabre; la API contesta 200 | ✅ 41192817230, «Uso aleatorio (monkey)» | ⏳ Samsung: 10,000 eventos (#70) |
| E2E-09 | Arranque en frío, 5 veces (`tool/arranque_en_frio.sh`) | Entorno aislado | Cerrar la app y abrirla con `am start -W`, 5 veces | Las 5 abren; mediana dentro de la línea base +20 % | ✅ 41192817230, «Arranque en frío en el emulador» | ⏳ Samsung con la versión candidata (#71). El 27-oct la v2.1.1 tardaba unos 25 s (#198, corregido en #230) |
| E2E-10 | Fluidez: arranque con sesión, desplazar el catálogo y checkout (`integration_test/rendimiento/rendimiento_test.dart`) | Samsung, servidor real, cuenta de prueba | Las tres mediciones con `traceAction` | Cuadros de 16 ms o menos | — Se mide en el build profile, no en debug | ⏳ Samsung con la versión candidata (#71) |
| E2E-11 | Calificar un producto comprado y editar la reseña | Pedido completado en la cuenta de prueba | — | — | — Sin caso E2E todavía: hoy se prueba en memoria (`test/widget/reviews/`, `test/unitarias/resenas/`). Se agrega con #64 y #65 | — Igual |
| E2E-12 | Favoritos y «Avísame» | Cuenta de cliente | — | — | — Sin caso E2E todavía: en memoria (`test/widget/favorites/`). Se agrega con #64 | — Igual |
| E2E-13 | Registro y verificación del correo | Correo nuevo | — | — | — Sin caso E2E todavía: en memoria (`test/aceptacion/auth/registro_verificacion_test.dart`). Necesita un buzón de prueba para el código | — Igual |

## Registro de errores encontrados y corregidos

Severidad: la prioridad del issue en el tablero (el proyecto no tiene un campo aparte de severidad). «Dónde se
vio» queda vacío cuando el issue no lo dice. Las pruebas de regresión llevan la etiqueta `regresion` y las corre
`regresion.yml` en cada pipeline (`flutter test --tags regresion`).

| ID | Caso | Dónde se vio | Descripción | Severidad | Causa | Corrección | Prueba de regresión | Estado |
|---|---|---|---|---|---|---|---|---|
| ERR-01 | Pipeline (#87) | CI (Linux) | El conteo de `flutter analyze` fallaba con el formato de Linux | — (es un PR) | El conteo solo entendía el formato de Windows | #87 | `test/regresion/conteo_analisis_test.dart` (3 casos) | Corregido 08-oct |
| ERR-02 | Catálogo y favoritos (#111) | — | Decía «agregado» aunque el alta fallara | Media | Confirmaba sin esperar la respuesta del backend | #113 | `products_screen_test.dart` y `favorites_screen_test.dart`: «agregado» solo si el backend acepta | Corregido 11-oct |
| ERR-03 | Sin conexión (#112) | — | Al cliente le aparecía el texto técnico del error | Media | Se mostraba el mensaje de la excepción | #116 | `api_service_test.dart`: mensaje amigable sin conexión | Corregido 11-oct |
| ERR-04 | Reembolso (#118) | — | El backend rechazaba la solicitud | Media | El motivo iba como texto y el backend espera el código de su ENUM | #119 | `refunds_view_model_test.dart` (3 pruebas) | Corregido 11-oct |
| ERR-05 | Roles de producción (#126) | — | La app no reconocía los roles hornos y decoración | Alta | Faltaban esos roles en la app | #140 | `auth_provider_test.dart` y los escenarios de hornos y decoración en `inicio_sesion_test.dart` | Corregido 13-oct |
| ERR-06 | Pipeline (#155) | CI | SonarCloud falló en `main` | Media | Error del servidor de SonarCloud y acciones viejas | #156 | `workflows_test.dart`: ningún workflow vuelve a una versión vieja | Corregido 16-oct |
| ERR-07 | Catálogo sin conexión (#160) | — | Decía «Sin resultados / Limpiar filtros» en vez de avisar | Media | Sin conexión se trataba como una lista vacía | #162 | `products_screen_test.dart`: avisa y «Reintentar» vuelve a cargar | Corregido 19-oct |
| ERR-08 | Regresión de la v2.1.0 (#185) | CI | Falló la regresión completa (corrida 7) | Media | Corría las mediciones de rendimiento en el emulador | #186 | `workflows_test.dart`: ningún `flutter test` corre `integration_test/rendimiento/` | Corregido 23-oct |
| ERR-09 | Arranque (#198) | Release, Samsung (27-oct) | Android marcaba la app como congelada al abrir (unos 25 s) | Media | Esperaba `GET /pagos/config` antes de dibujar la primera pantalla | #230 | `test/regresion/arranque_test.dart` | Corregido 28-oct (en `main` el 31-oct) |
| ERR-10 | Detalle del pedido (#216) | Release, Samsung (27-oct, #62) | Horario de recogida en ISO crudo y fecha en UTC | Media | Las fechas no se pasaban a la hora de México | #239 | `order_detail_screen_test.dart` y `formatters_test.dart` (con la etiqueta desde #225) | Corregido 31-oct |
| ERR-11 | Nueva comanda (#241) | Pier STAGING en el Samsung (28-oct) | Al cerrar el selector de hora el foco saltaba al teléfono y se abría el teclado | Baja | Flutter devuelve el foco al último campo que lo tuvo | #255 (abierto) | `nueva_comanda_screen_test.dart`: 4 pruebas de fecha y hora (en #255, todavía sin la etiqueta) | En revisión |

## Lo que falta

- **Release en el Samsung:** E2E-01, E2E-03 a E2E-06 con el Sprint 4, E2E-08 (10,000 eventos, #70), y E2E-09 y E2E-10
  con la versión candidata (#71).
- **Contra el servidor real con el Sprint 4:** la próxima regresión completa o `flujo-compra.yml` a mano.
- **Casos nuevos:** reseñas, favoritos y registro (E2E-11 a E2E-13) no tienen caso E2E todavía.
