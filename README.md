# Pier Repostería — App móvil

Aplicación móvil (Android / iOS) de **Pier Repostería**, una pastelería con venta
en línea. Permite a los clientes explorar el catálogo, guardar favoritos, armar
su carrito, pagar con tarjeta, dar seguimiento a sus pedidos, dejar reseñas y
solicitar reembolsos o levantar quejas. Incluye además un **módulo de repartidor**
para gestionar entregas y una **vinculación con Alexa** para consultar pedidos por
voz.

La app consume el backend de Pier (Node + Express) desplegado en Render; no
contiene lógica de negocio del lado del servidor.

## Stack

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Dart 3.x) |
| Estado | `provider` |
| Navegación | `go_router` |
| HTTP | `http` |
| Pagos | `flutter_stripe` (Stripe Payment Sheet) |
| Autenticación | JWT propio + `google_sign_in` (OAuth de Google) |
| Sesión local | `shared_preferences` |
| Backend | Node + Express + PostgreSQL, desplegado en Render |

## Estructura de carpetas

```
lib/
├── core/            # Transversal: no depende de ninguna pantalla
│   ├── constants/   # api_constants (rutas del backend), colores, strings, rutas
│   ├── services/    # Clientes de bajo nivel: API, almacenamiento, notificaciones
│   ├── theme/       # Tema visual (incluye temas de temporada)
│   └── utils/       # Validadores, formateadores, logger, helpers
├── data/            # Capa de datos
│   ├── models/      # Modelos de dominio (producto, pedido, usuario, …)
│   └── providers/   # ChangeNotifiers globales (auth, carrito, pedidos, …)
├── presentation/    # Capa de UI
│   ├── screens/     # Pantallas agrupadas por rol: auth, client, public, repartidor
│   └── widgets/     # Widgets reutilizables
└── routes/          # Configuración de go_router
```

- **core** contiene lo que cualquier otra capa puede usar sin crear dependencias
  circulares: constantes, servicios base, tema y utilidades.
- **data** conoce el backend y expone el estado de la app a través de providers.
- **presentation** solo pinta: lee providers y navega; no llama a la API directamente.

## Requisitos previos

- Flutter estable (3.x) con el SDK de Dart que trae (`^3.10`).
- Android Studio o las herramientas de línea de comandos de Android (SDK + emulador
  o dispositivo físico con depuración USB).
- Xcode (solo para compilar iOS, desde macOS).
- Acceso a internet: la app apunta al backend en Render.

## Cómo correr el proyecto

```bash
git clone https://github.com/Ennimex/pier_pasteleria.git
cd pier_pasteleria
flutter pub get
flutter devices          # identifica tu dispositivo o emulador
flutter run -d <device-id>
```

Comprobaciones antes de abrir un Pull Request:

```bash
flutter analyze
flutter test
```

Para pagos de prueba con Stripe usa la tarjeta `4242 4242 4242 4242` con cualquier
fecha futura y CVC.

## Estrategia de ramas (GitHub Flow)

- `main` es la única rama de larga vida y está **protegida**: no se puede hacer
  push directo ni force push.
- Todo cambio nace en una rama `feature/<descripcion-corta>` creada desde `main`
  (por ejemplo `feature/cambiar-application-id`). Para correcciones puede usarse
  `fix/<descripcion>`.
- La rama se integra a `main` **únicamente mediante Pull Request**, con al menos
  **una aprobación** de otro integrante y las verificaciones en verde.
- Cada PR debe enlazar el issue que resuelve (`Closes #N`) para mantener la
  trazabilidad entre tablero, issue, rama, PR y commit.
- No existe rama `develop`: `main` siempre debe poder liberarse.

## Convención de commits (Conventional Commits)

Formato: `<tipo>(<ámbito opcional>): <descripción en minúsculas>`

| Tipo | Uso |
|---|---|
| `feat` | Nueva funcionalidad visible para el usuario |
| `fix` | Corrección de un error |
| `docs` | Solo documentación |
| `chore` | Mantenimiento, configuración, dependencias |
| `ci` | Cambios en workflows de GitHub Actions |
| `test` | Agregar o corregir pruebas |
| `refactor` | Cambio interno sin alterar comportamiento |
| `build` | Cambios de compilación, firma o versionado |

Ejemplos:

```
feat(checkout): mostrar resumen antes de pagar
fix(auth): manejar token expirado al reabrir la app
build(android): cambiar applicationId a mx.com.pierreposteria
ci: ejecutar analyze y test en cada pull request
```

## Enlaces

- Tablero de planeación (GitHub Projects): _pendiente_
- Documento de evidencias: _pendiente_
- Backend: https://github.com/PedroRubioo/pier-reposteria-backend
