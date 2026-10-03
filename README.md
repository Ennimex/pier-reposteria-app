# Pier Repostería — App móvil

Aplicación móvil (Android / iOS) de **Pier Repostería**, una pastelería con venta
en línea. Permite a los clientes explorar el catálogo, guardar favoritos, armar
su carrito, pagar con tarjeta, dar seguimiento a sus pedidos, dejar reseñas y
solicitar reembolsos o levantar quejas. Incluye además un **módulo de repartidor**
para gestionar entregas y una **vinculación con Alexa** para consultar pedidos por
voz.

La app consume el backend de Pier (Node + Express) desplegado en Render; no
contiene lógica de negocio del lado del servidor.

## Equipo y roles

| Integrante | Rol (Scrumban) | Responsabilidades |
|---|---|---|
| Pedro ([@PedroRubioo](https://github.com/PedroRubioo)) | Product Owner · DevOps / Release Engineer | Define y prioriza las épicas del backlog. Ambientes, firma y publicación de liberaciones, pipeline de CI/CD y monitoreo. Revisa y aprueba los Pull Requests hacia `main`. Responsable del backend (API) que consume la app. |
| Alexander ([@Ennimex](https://github.com/Ennimex)) | Desarrollo móvil · QA · Documentación técnica | Implementa las historias de la app en Flutter y la arquitectura MVVM. Pruebas unitarias, de widget y de integración. Versionado, README y documentación técnica. |

El responsable de cada actividad aparece como *Assignee* en su issue y en el
[tablero de planeación](https://github.com/users/Ennimex/projects/2).

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
pier-reposteria-app/
├── lib/                   # Código de la app (detalle abajo)
├── test/                  # Pruebas que corren sin red: unitarias, de aceptación y de esfuerzo
│   └── fakes/             # FakeApiClient: doble del backend para probar sin internet
├── integration_test/      # Pruebas de integración y de rendimiento en emulador o celular (desde el Sprint 2)
├── android/  ios/         # Proyectos nativos; la firma de release se configura en android/
├── assets/                # Imágenes y recursos de la app
├── docs/                  # Documentos de evidencias de la materia
├── .github/               # Plantillas de Pull Request e issues; workflows de GitHub Actions (Sprint 1)
├── analysis_options.yaml  # Reglas de flutter analyze
├── pubspec.yaml           # Dependencias y versión de la app (SemVer)
└── linux/ macos/ web/ windows/   # Generados por Flutter; no se usan en este proyecto
```

Dentro de `lib/`:

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

- Flutter 3.44.4 (canal `stable`), que incluye Dart 3.12. Es la versión con la que
  se genera `pubspec.lock`; versiones 3.x más nuevas también compilan el proyecto.
- JDK 21 (Temurin) para compilar Android: `android/app/build.gradle.kts` usa
  `JavaVersion.VERSION_21` y Gradle 8.14.
- Android Studio o las herramientas de línea de comandos de Android (SDK y un
  emulador, o un dispositivo físico con depuración USB).
- Xcode (solo para compilar iOS, desde macOS).
- Acceso a internet: la app apunta al backend en Render.

## Cómo correr el proyecto

```bash
git clone https://github.com/Ennimex/pier-reposteria-app.git
cd pier-reposteria-app
flutter pub get
flutter devices          # identifica tu dispositivo o emulador
flutter run -d <device-id>
```

Comprobaciones antes de abrir un Pull Request (qué revisa cada una, en
[Pruebas](#pruebas)):

```bash
flutter analyze
flutter test
```

Para pagos de prueba con Stripe usa la tarjeta `4242 4242 4242 4242` con cualquier
fecha futura y CVC.

## Pruebas

Cada historia del tablero tiene sus pruebas en el mismo sprint en que se entrega.
Las actividades de prueba son los issues con la etiqueta `prueba` y el título en
MAYÚSCULAS (#15 a #17 y #52 a #72); cada una dice qué historias cubre.

| Tipo | Qué comprueba | Dónde vive | Cuándo corre |
|---|---|---|---|
| Unitarias | Validadores, providers y repositorios, sin red, con `FakeApiClient` | `test/unitarias/` | Cada Pull Request (`ci.yml`) |
| Análisis de código estático | Errores, malas prácticas y vulnerabilidades, sin ejecutar la app | `flutter analyze` y SonarCloud | Cada Pull Request (`ci.yml`) |
| Aceptación | Una prueba de widget por cada escenario Gherkin de la historia | `test/aceptacion/` | Cada Pull Request (`ci.yml`) |
| Integración | Flujos que unen varias historias, en emulador Android contra staging | `integration_test/flujos/` | Pull Requests que tocan código (`integracion.yml`) |
| Regresión | Toda la suite acumulada sobre `main` | Las carpetas anteriores | Martes de cierre de sprint y cada tag (`regresion.yml`) |
| Rendimiento | Arranque, fluidez del catálogo y peso del APK, en el Samsung SM-N975U | `integration_test/rendimiento/` | Cada tag y a mano (`rendimiento.yml`) |
| Esfuerzo | Catálogo de 1,000 productos, carrito de 100 artículos y 5,000 toques de monkey | `test/esfuerzo/` | Cada tag y a mano (`esfuerzo.yml`) |

Herramientas: `flutter_test` e `integration_test` (vienen con el SDK),
`very_good_analysis`, SonarCloud, `reactivecircus/android-emulator-runner`,
`adb shell monkey` y GitHub Actions. Las 31 pruebas actuales viven en `test/`;
las carpetas por tipo y los workflows de `.github/workflows/` se crean en el
Sprint 1 (#19). Para correrlas en tu máquina:

```bash
flutter test                     # unitarias, aceptación y esfuerzo
flutter test --coverage          # igual, con reporte en coverage/lcov.info
flutter test integration_test    # integración, con un emulador o celular conectado
```

## Estrategia de ramas (GitHub Flow)

- `main` es la única rama de larga vida y está **protegida**: no se puede hacer
  push directo ni force push.
- Todo cambio nace en una rama `feature/<descripcion-corta>` creada desde `main`
  (por ejemplo `feature/versionado-semantico`). Para correcciones puede usarse
  `fix/<descripcion>`.
- La rama se integra a `main` **únicamente mediante Pull Request**, con al menos
  **una aprobación** de otro integrante y las verificaciones en verde.
- Cada PR debe enlazar el issue que resuelve (`Closes #N`) para mantener la
  trazabilidad entre tablero, issue, rama, PR y commit.
- No existe rama `develop`: `main` siempre debe poder liberarse.

## Convención de commits (Conventional Commits)

Formato: `<tipo>(<ámbito opcional>): <descripción en minúsculas>`

El cuerpo del commit cita el issue en el que se trabaja con `Refs #N`. El
`Closes #N` que cierra el issue va en la descripción del Pull Request, no en el
commit.

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
build: subir versión a 1.1.0+2
ci: ejecutar analyze y test en cada pull request

docs: completar el README con la estrategia de pruebas

Refs #73
```

## Definición de terminado

Una historia o una tarea está terminada cuando:

1. Cumple todos sus criterios de aceptación.
2. Su Pull Request hacia `main` declara `Closes #N` y fue aprobado por el compañero.
3. `flutter analyze` no reporta errores ni avisos nuevos respecto a `main`.
4. `flutter test` pasa en verde, y el cambio agrega o actualiza pruebas cuando toca lógica.
5. No introduce secretos: sin llaves, tokens, keystores, `key.properties` ni archivos `.env`.
6. Se probó en dispositivo físico o emulador, y el Pull Request anota qué se probó.
7. El Pull Request está mezclado, el issue cerrado y la tarjeta en Done.

Una liberación está terminada cuando, además:

8. `main` lleva un tag SemVer `vX.Y.Z` que coincide con `pubspec.yaml`.
9. Existe un APK firmado con la llave de release, generado desde ese tag.

## Versionado (SemVer)

La versión vive en `version:` de `pubspec.yaml` con el formato
`MAJOR.MINOR.PATCH+BUILD` (por ejemplo `1.1.0+2`). Gradle toma de ahí
`versionName` y `versionCode`.

| Parte | Cuándo sube |
|---|---|
| `MAJOR` | Cambio incompatible: obliga a reinstalar o rompe el contrato con el backend |
| `MINOR` | Funcionalidad nueva que no rompe lo anterior |
| `PATCH` | Corrección de errores sin funcionalidad nueva |
| `+BUILD` | Sube en **cada** build de liberación, aunque lo demás no cambie (Google Play exige un `versionCode` creciente) |

Al subir la versión se cambian, en el mismo commit, `pubspec.yaml` y
`lib/config/app_version.dart` (la copia que muestra la pantalla "Más").
`test/app_version_test.dart` falla si dejan de coincidir.

Flujo de liberación:

1. Pull Request `build: subir versión a X.Y.Z+N` hacia `main`.
2. Con el PR mezclado, crear el tag sobre `main`:
   `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. El tag `v*` disparará el workflow que publica el APK en GitHub Releases
   (Sprint 3, issue #22).

## Calendario de sprints

Sprints de dos semanas, de miércoles a martes. La entrega y revisión de cada
sprint es el **martes de cierre**, día en que coinciden las clases de Desarrollo
Móvil Integral (14:10-15:50) y Gestión del Proceso de Desarrollo de Software
(15:50-17:30). Los bloqueos se atienden en las asesorías: martes 12:30 (Gestión)
y miércoles 13:20 (Móvil).

| Sprint | Inicio | Cierre y entrega | Objetivo | Producto verificable |
|---|---|---|---|---|
| 0 | 16-sep-2026 | 29-sep-2026 | Preparación | Repositorio y tablero configurados, entorno Flutter, MVVM y SemVer en main por PR, Definición de terminado y documento de evidencias |
| 1 | 30-sep-2026 | 13-oct-2026 | Habilitar el pipeline | APK firmado con keystore propio y ambientes dev/staging/prod separados |
| 2 | 14-oct-2026 | 27-oct-2026 | Calidad y pruebas | Pipeline en verde con pruebas y quality gate de SonarCloud en cada PR |
| 3 | 28-oct-2026 | 10-nov-2026 | Liberación y monitoreo | APK en GitHub Releases con Sentry activo y métricas definidas |
| 4 | 11-nov-2026 | 24-nov-2026 | Catálogo, pedidos y reseñas | Pruebas automatizadas de #2, #4 y #5 en verde y APK del sprint en Releases |
| 5 | 25-nov-2026 | 08-dic-2026 | Reembolsos, repartidor y Alexa | Pruebas de #6, #7 y #8 en verde, APK en Releases y versión candidata para el canal interno de Play |

El Sprint 0 es de preparación: configura el repositorio, el tablero, el entorno y
la arquitectura antes de empezar a construir el pipeline.

Cada sprint es un milestone del repositorio y una iteración del tablero. El
cronograma tipo Gantt está en la vista **Cronograma** del tablero.

## Enlaces

- Tablero de planeación (GitHub Projects): https://github.com/users/Ennimex/projects/2
- Documento de evidencias (Actividad 2): [docs/ACTIVIDAD2_EVIDENCIAS.pdf](docs/ACTIVIDAD2_EVIDENCIAS.pdf)
- Backend: https://github.com/PedroRubioo/pier-reposteria-backend
