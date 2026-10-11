// lib/config/dependencies.dart
//
// Inyección de dependencias (MVVM, Fase 3.5). Registra una sola vez el
// ApiClient, los 15 repositorios (contrato abstracto → implementación Remote)
// y los providers globales. Vistas y ViewModels piden su repositorio con
// `context.read<XRepository>()` en vez de instanciarlo.
//
// main.dart lo usa con el ApiService real; test/helpers/pump_app.dart con
// FakeApiClient, así las pruebas montan exactamente el mismo árbol.
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/data/services/pasarela_stripe.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Árbol de dependencias de la app sobre [api]: primero el cliente HTTP,
/// luego los repositorios y al final los providers globales que los usan.
List<SingleChildWidget> dependencias(ApiClient api) => [
      Provider<ApiClient>.value(value: api),
      // ── Repositorios
      Provider<AuthRepository>(
        create: (context) => AuthRepositoryRemote(api: context.read()),
      ),
      Provider<CarritoRepository>(
        create: (context) => CarritoRepositoryRemote(api: context.read()),
      ),
      Provider<ConfiguracionRepository>(
        create: (context) => ConfiguracionRepositoryRemote(api: context.read()),
      ),
      Provider<CuentaRepository>(
        create: (context) => CuentaRepositoryRemote(api: context.read()),
      ),
      Provider<DemandaRepository>(
        create: (context) => DemandaRepositoryRemote(api: context.read()),
      ),
      Provider<DireccionesRepository>(
        create: (context) => DireccionesRepositoryRemote(api: context.read()),
      ),
      Provider<EntregasRepository>(
        create: (context) => EntregasRepositoryRemote(api: context.read()),
      ),
      Provider<FavoritosRepository>(
        create: (context) => FavoritosRepositoryRemote(api: context.read()),
      ),
      Provider<NotificacionesRepository>(
        create: (context) =>
            NotificacionesRepositoryRemote(api: context.read()),
      ),
      Provider<PagosRepository>(
        create: (context) => PagosRepositoryRemote(api: context.read()),
      ),
      Provider<PedidosRepository>(
        create: (context) => PedidosRepositoryRemote(api: context.read()),
      ),
      Provider<ProductosRepository>(
        create: (context) => ProductosRepositoryRemote(api: context.read()),
      ),
      Provider<QuejasRepository>(
        create: (context) => QuejasRepositoryRemote(api: context.read()),
      ),
      Provider<ReembolsosRepository>(
        create: (context) => ReembolsosRepositoryRemote(api: context.read()),
      ),
      Provider<ResenasRepository>(
        create: (context) => ResenasRepositoryRemote(api: context.read()),
      ),
      // ── Servicios
      Provider<PasarelaPago>(create: (_) => PasarelaStripe()),
      // ── Providers globales (estado compartido entre pantallas)
      ChangeNotifierProvider(
        create: (context) => AuthProvider(auth: context.read()),
      ),
      ChangeNotifierProvider(
        create: (context) => CartProvider(repo: context.read()),
      ),
      ChangeNotifierProvider(
        create: (context) => ProductProvider(repo: context.read()),
      ),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(
        create: (context) => NotificationProvider(repo: context.read()),
      ),
      ChangeNotifierProvider(
        create: (context) => TemaProvider(repo: context.read()),
      ),
    ];
