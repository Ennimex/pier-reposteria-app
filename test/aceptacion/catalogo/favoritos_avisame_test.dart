// test/aceptacion/catalogo/favoritos_avisame_test.dart — escenarios Gherkin
// de favoritos y «Avísame» en productos agotados (#64; historia #38): marcar
// un favorito, el favorito sin sesión, quitarlo y el interés en un agotado,
// sin red.
//
// Cada prueba recorre la app como el cliente: desde una página anfitriona
// abre el detalle de un producto o «Mis Favoritos» y toca los mismos
// botones. El backend es un falso en memoria sobre FakeApiClient que guarda
// los favoritos del cliente (POST y DELETE /favoritos/:id), para que lo que
// se ve en la lista sea lo que el «servidor» realmente tiene, y que recibe
// cada «Avísame» en POST /clics-agotados.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/auth/widgets/login_screen.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/favorites/widgets/favorites_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Un producto como lo mandan el catálogo y GET /favoritos.
Map<String, dynamic> _productoJson(
  int id,
  String nombre, {
  required num precio,
  bool agotado = false,
}) => {
  'id': id,
  'nombre': nombre,
  'descripcion': 'Delicioso $nombre',
  'precio_chico': precio,
  'categoria': 'Pasteles',
  'imagen_url': '',
  // 0 = agotado (regla del backend).
  'stock_online': agotado ? 0 : 12,
  'activo': true,
};

/// Catálogo del backend falso: id → producto.
final Map<int, Map<String, dynamic>> _catalogo = {
  7: _productoJson(7, 'Chocoflan', precio: 300),
  8: _productoJson(8, 'Pay de queso', precio: 250),
  9: _productoJson(9, 'Pay de limón', precio: 200, agotado: true),
};

/// Los productos que el cliente abre: uno disponible y uno agotado.
final Product _chocoflan = Product.fromJson(_catalogo[7]!);
final Product _payDeLimon = Product.fromJson(_catalogo[9]!);

const Map<String, dynamic> _sesion = {
  'success': true,
  'token': 'jwt',
  'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
};

/// Favoritos del cliente en memoria, como los guarda el backend: GET
/// /favoritos/ids y /favoritos los leen, POST /favoritos/:id agrega y
/// DELETE /favoritos/:id quita (404 si no estaba).
class _BackendFavoritos {
  _BackendFavoritos({Set<int> iniciales = const {}})
    : guardados = {...iniciales} {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.login: _sesion,
        ApiConstants.favoritosIds: _ids,
        ApiConstants.favoritos: _lista,
        for (final id in _catalogo.keys) ...{
          ApiConstants.favoritoById('$id'): _favorito,
          ApiConstants.productoById('$id'): {
            'success': true,
            'producto': {'imagenes': <String>[], 'reviews': 0},
            'resenas': <Map<String, dynamic>>[],
          },
          ApiConstants.recomendaciones('$id'): {
            'success': true,
            'recomendaciones': <Map<String, dynamic>>[],
          },
        },
        ApiConstants.clicsAgotados: {'success': true, 'registrado': true},
      },
    );
  }

  /// Ids de los productos guardados, en el orden en que se agregaron.
  final Set<int> guardados;
  late final FakeApiClient api;

  /// Lo que recibió POST /clics-agotados, un body por cada «Avísame».
  List<Map<String, dynamic>?> get intereses => [
    for (final llamada in api.llamadas)
      if (llamada.endpoint == ApiConstants.clicsAgotados) llamada.body,
  ];

  Map<String, dynamic> _ids(LlamadaApi _) => {
    'success': true,
    'ids': [...guardados],
  };

  Map<String, dynamic> _lista(LlamadaApi _) => {
    'success': true,
    'favoritos': [for (final id in guardados) _catalogo[id]!],
  };

  Map<String, dynamic> _favorito(LlamadaApi llamada) {
    final id = int.parse(llamada.endpoint.split('/').last);
    if (llamada.metodo != 'DELETE-Auth') {
      guardados.add(id);
      return {'success': true, 'message': 'Agregado a favoritos'};
    }
    if (!guardados.remove(id)) {
      return {'success': false, 'message': 'No encontrado en favoritos'};
    }
    return {'success': true, 'message': 'Eliminado de favoritos'};
  }
}

/// Página de partida: abre el detalle de un producto, como el catálogo, o
/// «Mis Favoritos», como la pestaña «Más».
class _Tienda extends StatelessWidget {
  const _Tienda();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        for (final producto in [_chocoflan, _payDeLimon])
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(product: producto),
              ),
            ),
            child: Text('Ver ${producto.nombre}'),
          ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
          ),
          child: const Text('Mis favoritos'),
        ),
      ],
    ),
  );
}

/// Monta la tienda sobre el backend falso. Todo se prueba a 1080 de ancho,
/// igual que product_detail_screen_test.dart: con la fuente de pruebas
/// (Ahem, más ancha que la real) el detalle se desborda a 412. Con
/// [conSesion], el cliente ya inició sesión.
Future<void> _abrirTienda(
  WidgetTester tester,
  _BackendFavoritos backend, {
  bool conSesion = true,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 4200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const _Tienda(), api: backend.api);
  if (conSesion) {
    await tester.iniciarSesion(find.byType(_Tienda));
    await tester.pump();
  }
}

/// Toca [boton] y espera a que todo se acomode (páginas, avisos y
/// animaciones).
Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

/// La tarjeta de [nombre] en «Mis Favoritos».
Finder _tarjeta(String nombre) => find
    .ancestor(of: find.text(nombre), matching: find.byType(PresionEscala))
    .first;

void main() {
  group('#38 Favoritos y «Avísame» en productos agotados', () {
    // Escenario: marcar un favorito
    //   Dado que inicié sesión y estoy viendo un producto
    //   Cuando lo marco como favorito
    //   Entonces aparece en mi lista de favoritos
    testWidgets('Escenario: marcar un favorito', (tester) async {
      final backend = _BackendFavoritos();
      await _abrirTienda(tester, backend);

      // Dado que inicié sesión y estoy viendo un producto
      await _tocar(tester, find.text('Ver Chocoflan'));
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Cuando lo marco como favorito
      await _tocar(tester, find.byIcon(Icons.favorite_border_rounded));
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(
        backend.api.llamo(ApiConstants.favoritoById('7'), metodo: 'POST-Auth'),
        isTrue,
      );
      expect(backend.guardados, {7});

      // Entonces aparece en mi lista de favoritos
      await _tocar(tester, find.byIcon(LucideIcons.arrowLeft));
      await _tocar(tester, find.text('Mis favoritos'));
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.text('1 producto guardado'), findsOneWidget);
      expect(_tarjeta('Chocoflan'), findsOneWidget);
      expect(find.text('Pay de queso'), findsNothing);
    });

    // Escenario: favorito sin sesión
    //   Dado que no he iniciado sesión
    //   Cuando intento marcar un producto como favorito
    //   Entonces la app me lleva a iniciar sesión
    testWidgets('Escenario: favorito sin sesión', (tester) async {
      final backend = _BackendFavoritos();

      // Dado que no he iniciado sesión (y estoy viendo un producto)
      await _abrirTienda(tester, backend, conSesion: false);
      await _tocar(tester, find.text('Ver Chocoflan'));

      // Cuando intento marcar un producto como favorito
      await _tocar(tester, find.byIcon(Icons.favorite_border_rounded));

      // Entonces la app me lleva a iniciar sesión, sin guardar nada
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(backend.api.llamo(ApiConstants.favoritoById('7')), isFalse);
      expect(backend.guardados, isEmpty);
    });

    // Escenario: quitar un favorito
    //   Dado que tengo un producto en favoritos
    //   Cuando lo desmarco
    //   Entonces deja de aparecer en mi lista de favoritos
    testWidgets('Escenario: quitar un favorito', (tester) async {
      // Dado que tengo un producto en favoritos (y otro más)
      final backend = _BackendFavoritos(iniciales: {7, 8});
      await _abrirTienda(tester, backend);
      await _tocar(tester, find.text('Mis favoritos'));
      expect(find.text('2 productos guardados'), findsOneWidget);
      expect(_tarjeta('Chocoflan'), findsOneWidget);

      // Cuando lo desmarco (el corazón de su tarjeta)
      await _tocar(
        tester,
        find.descendant(
          of: _tarjeta('Chocoflan'),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
      );

      // Entonces deja de aparecer en mi lista de favoritos…
      expect(find.text('Chocoflan'), findsNothing);
      expect(_tarjeta('Pay de queso'), findsOneWidget);
      expect(find.text('1 producto guardado'), findsOneWidget);
      expect(
        backend.api.llamo(
          ApiConstants.favoritoById('7'),
          metodo: 'DELETE-Auth',
        ),
        isTrue,
      );
      expect(backend.guardados, {8});

      // …tampoco al volver a abrir la lista (el backend ya no lo tiene)
      await _tocar(tester, find.byIcon(LucideIcons.chevronLeft));
      await _tocar(tester, find.text('Mis favoritos'));
      expect(find.text('Chocoflan'), findsNothing);
      expect(find.text('1 producto guardado'), findsOneWidget);
    });

    // Escenario: Avísame en un producto agotado
    //   Dado que un producto está agotado
    //   Cuando pulso «Avísame»
    //   Entonces la app registra mi interés en ese producto, con o sin
    //   sesión iniciada
    testWidgets('Escenario: Avísame en un producto agotado', (tester) async {
      final backend = _BackendFavoritos();
      await _abrirTienda(tester, backend, conSesion: false);

      // Dado que un producto está agotado
      await _tocar(tester, find.text('Ver Pay de limón'));
      expect(find.text('Avísame'), findsOneWidget);
      expect(find.text('Añadir'), findsNothing);

      // Cuando pulso «Avísame» sin haber iniciado sesión
      await _tocar(tester, find.text('Avísame'));

      // Entonces la app registra mi interés en ese producto, sin pedir
      // sesión y sin salir del detalle
      expect(backend.intereses, [
        {'producto_id': 9},
      ]);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      // Ajuste: la confirmación solo dice que se anotó el interés y no
      // promete un aviso posterior, porque ese aviso no existe (#240); el
      // botón conserva el texto «Avísame» mientras el negocio lo decide.
      expect(
        find.text('Anotamos tu interés en "Pay de limón".'),
        findsOneWidget,
      );
      expect(find.textContaining('Te avisaremos'), findsNothing);

      // …y también con sesión iniciada
      await tester.iniciarSesion(find.byType(ProductDetailScreen));
      await _tocar(tester, find.text('Avísame'));
      expect(backend.intereses, [
        {'producto_id': 9},
        {'producto_id': 9},
      ]);
      expect(
        find.text('Anotamos tu interés en "Pay de limón".'),
        findsOneWidget,
      );
    });
  });
}
