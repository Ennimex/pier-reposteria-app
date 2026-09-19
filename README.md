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
├── config/            # api_constants (rutas del backend), datos del negocio, strings
├── utils/             # Validadores, formateadores, logger, helpers
├── routing/           # Configuración de go_router
├── domain/
│   └── models/        # Modelos de dominio (producto, pedido, usuario, …)
├── data/              # Capa de datos: lo único que conoce el backend
│   ├── services/      # Bajo nivel: ApiClient (interfaz), ApiService, almacenamiento,
│   │                  # notificaciones
│   └── repositories/  # Un repositorio por dominio (auth, productos, carrito, pedidos, …)
└── ui/                # Capa de UI
    ├── core/
    │   ├── themes/    # Tema visual (incluye temas de temporada)
    │   ├── ui/        # Widgets reutilizables
    │   └── state/     # ChangeNotifiers globales (auth, carrito, pedidos, …)
    └── <función>/     # auth, home, products, cart, checkout, orders, …
        └── widgets/   # Pantallas (*_screen.dart) y widgets de esa función
```

La app sigue la arquitectura MVVM de la
[guía oficial de Flutter](https://docs.flutter.dev/app-architecture) (migración en curso):

- **data** es la única capa que habla con el backend. Las pantallas y los providers
  piden los datos a un repositorio; nadie fuera de `lib/data/` importa `ApiService`
  ni `ApiConstants`.
- Cada repositorio recibe un `ApiClient` opcional (`X({ApiClient? api})`), lo que
  permite probarlo sin red con `test/fakes/fake_api_client.dart`.
- **ui** pinta y navega; el estado global vive en `ui/core/state`. Los ViewModels por
  pantalla (`ui/<función>/view_model/`) llegan en la siguiente fase.
- Los imports son absolutos: `package:pier_pasteleria/...`.

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

- Tablero de planeación (GitHub Projects): https://github.com/users/Ennimex/projects/2
- Documento de evidencias: _pendiente_
- Backend: https://github.com/PedroRubioo/pier-reposteria-backend
