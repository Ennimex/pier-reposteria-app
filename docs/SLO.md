# Métricas y objetivos de servicio (SLO)

Con qué números se decide si una versión de la app sigue adelante o se
detiene. La estrategia canary completa (quién instala qué y cómo se sube a
Play) está en [LIBERACION.md](LIBERACION.md); aquí están las métricas, sus
objetivos y la regla de avance (#24).

## Las métricas

| Métrica | Qué dice | Fuente | Objetivo | Ventana | Responsable |
|---|---|---|---|---|---|
| **Crash-free sessions** | De cada 100 veces que se abre la app, cuántas terminan sin cerrarse de golpe | Sentry → Releases | **≥ 99.5 %** | 48 h por versión | Pedro |
| **Crash-free users** | De cada 100 personas, cuántas no vieron ningún cierre | Sentry → Releases | **≥ 99 %** | 48 h por versión | Pedro |
| **Tasa de ANR** | Sesiones en las que la app se congeló 5 s o más («la aplicación no responde») | Play Console → Android Vitals; mientras la app no esté en Play, Sentry | **< 0.47 %** (umbral de mal comportamiento de Google) | 28 días en Play; 48 h en Sentry | Pedro |
| **Arranque en frío p90** | El 90 % de las aperturas en frío muestran la primera pantalla en este tiempo o menos | Sentry → Insights → Mobile (`app_start_cold`) | **< 3 s** | 7 días | Alexander |
| **Errores en el pago** | De cada 100 intentos de pago, cuántos fallan por el servidor o la conexión | Sentry → transacciones `checkout.pagar` (etiqueta `flow:checkout`) | **< 1 %** de los intentos | 7 días | Alexander |

Línea base medida en el Samsung SM-N975U (#61): arranque en frío 1.6 s con el
servidor despierto.

### Cómo llega cada dato a Sentry

La app solo manda datos si el APK se compiló con `SENTRY_DSN` (los de
GitHub Releases lo traen; los de pruebas no). Cada evento lleva la versión
(`mx.com.pierreposteria@X.Y.Z+N`) y el ambiente (`prod`, `staging` o `dev`).

- **Sesiones y cierres**: los registra Sentry solo (`enableAutoSessionTracking`).
- **ANR**: el detector de Sentry para Android viene encendido (`anrEnabled`).
  Cuando la app esté en Play, la fuente oficial es Android Vitals.
- **Arranque en frío**: Sentry crea una transacción `ui.load` con la medida
  `app_start_cold` en cada arranque muestreado. Ojo: incluye la espera de
  `/pagos/config` antes del primer cuadro; si el servidor de Render está
  dormido, ese arranque sale de ~20 s.
- **Pago**: cada intento ya validado (con fecha, hora y dirección elegidas) es
  una transacción `pago` (op `checkout.pagar`) con las etiquetas
  `flow:checkout` y `resultado`
  ([`lib/config/monitoreo.dart`](../lib/config/monitoreo.dart)):

  | `resultado` | Cuándo | ¿Cuenta como error? |
  |---|---|---|
  | `pagado` | El pedido quedó registrado | No |
  | `cancelado` | El cliente cerró la hoja de pago o no aceptó el aviso de «por confirmar» | No |
  | `rechazado` | El banco rechazó la tarjeta | No |
  | `error` | Falló el servidor o la conexión al crear el cobro o al registrar el pedido | **Sí** (estado `internal_error`) |

  Las transacciones del pago se envían todas (100 %); las demás, el 20 % en
  prod para no agotar la cuota gratuita.

## Regla de avance del canary

Se revisa al terminar cada ventana de 48 h, con el filtro de la versión nueva:

| Crash-free sessions | Decisión |
|---|---|
| **≥ 99.5 %** y ningún objetivo de la tabla en rojo | Avanzar al siguiente paso: canary → 10 % → 50 % → 100 % |
| Entre 99 % y 99.5 % | Quedarse en el paso actual otras 48 h y revisar los errores nuevos |
| **< 99 %**, o un error grave nuevo | **Rollback**: detener el despliegue y publicar `vX.Y.Z+1` (pasos en [LIBERACION.md](LIBERACION.md#estrategia-canary)) |

Las demás métricas no detienen el avance por sí solas, salvo que estén en rojo
con datos suficientes (por ejemplo, el ANR por encima de 0.47 % o los errores
del pago por encima de 1 % con al menos 100 intentos).

## Dashboard en Sentry

Se arma una vez en sentry.io (proyecto `flutter`) → **Dashboards** →
**Create Dashboard** → nombre «Pier — SLO (#24)». Un widget por métrica, todos
con el filtro de ambiente `prod`:

| Widget | Dataset | Consulta | Visualización |
|---|---|---|---|
| Crash-free sessions | Releases | `crash_free_rate(session)` | Big Number |
| Crash-free users | Releases | `crash_free_rate(user)` | Big Number |
| ANR | Issues | `error.type:ApplicationNotResponding` (eventos y usuarios) | Table |
| Arranque en frío p90 | Transactions | `p90(measurements.app_start_cold)` con `transaction.op:ui.load` | Big Number |
| Errores en el pago | Transactions | `failure_rate()` con `transaction.op:checkout.pagar` | Big Number |
| Intentos de pago por resultado | Transactions | `count()` con `transaction.op:checkout.pagar`, agrupado por `resultado` | Table |

Para revisar una versión en canary se cambia el filtro **Release** del
dashboard a esa versión.

## Alerta

Sentry → **Alerts** → **Create Alert** → *Sessions* → *Crash free session
rate*: si baja de **99.5 %** en una ventana de 24 h (ambiente `prod`), manda
correo al equipo. Es el mismo número de la regla de avance, así que la alerta
avisa antes de la revisión de las 48 h. La alerta de errores de #23 (más de 10
en 1 hora) se queda como está.
