// lib/config/dependencies.dart
//
// Inyección de dependencias (MVVM, Fase 3.5). Registra una sola vez el
// ApiClient, los 19 repositorios (contrato abstracto → implementación Remote)
// y los providers globales. Vistas y ViewModels piden su repositorio con
// `context.read<XRepository>()` en vez de instanciarlo.
//
// main.dart lo usa con el ApiService real; test/helpers/pump_app.dart con
// FakeApiClient, así las pruebas montan exactamente el mismo árbol.
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/data/repositories/auth_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository.dart';
import 'package:pier_reposteria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/entregas_repository.dart';
import 'package:pier_reposteria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/notificaciones_repository.dart';
import 'package:pier_reposteria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pagos_repository.dart';
import 'package:pier_reposteria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/quejas_repository.dart';
import 'package:pier_reposteria/data/repositories/quejas_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/reembolsos_repository.dart';
import 'package:pier_reposteria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Árbol de dependencias de la app sobre [api]: primero el cliente HTTP,
/// luego los repositorios y al final los providers globales que los usan.
List<SingleChildWidget> dependencias(ApiClient api) => [
      Provider<ApiClient>.value(value: api),
      // ── Repositorios
      Provider<AtencionClientesRepository>(
        create: (context) =>
            AtencionClientesRepositoryRemote(api: context.read()),
      ),
      Provider<AuthRepository>(
        create: (context) => AuthRepositoryRemote(api: context.read()),
      ),
      Provider<CarritoRepository>(
        create: (context) => CarritoRepositoryRemote(api: context.read()),
      ),
      Provider<ComandasRepository>(
        create: (context) => ComandasRepositoryRemote(api: context.read()),
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
      Provider<GestionPedidosRepository>(
        create: (context) =>
            GestionPedidosRepositoryRemote(api: context.read()),
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
      Provider<PublicacionesRepository>(
        create: (context) => PublicacionesRepositoryRemote(api: context.read()),
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
      // ── Servicios (la fábrica PasarelaPago() elige la implementación)
      Provider<PasarelaPago>(create: (_) => PasarelaPago()),
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
