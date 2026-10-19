// test/widget/favorites/movimiento_favoritos_test.dart — el movimiento de
// «Mis Favoritos»: al regresar del detalle la cuadrícula se queda (sin
// esqueletos ni entrada repetida), buscar no repite la entrada, la foto va
// en FotoProductoHero con la etiqueta de siempre, el «+» hace su pulso, pasa
// a palomita y regresa a «+» en su tamaño, la campana de «Avísame» se mece y
// queda derecha, el estado vacío late una vez y queda quieto, y en el shell
// el «+» lanza la miniatura al carrito. Sin red.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:pier_reposteria/ui/favorites/view_model/favorites_view_model.dart';
import 'package:pier_reposteria/ui/favorites/widgets/favorites_screen.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';
import 'package:pier_reposteria/ui/main/widgets/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Datos del backend falso ─────────────────────────────────────────────

Map<String, dynamic> _favoritos({bool agotado = false, bool vacio = false}) => {
  'success': true,
  'favoritos': vacio
      ? <Object>[]
      : [
          {
            'id': 36,
            'nombre': 'Fresa Matcha Bliss',
            'categoria': 'Pasteles',
            if (agotado) 'stock_online': 0,
          },
          {'id': 40, 'nombre': 'Pay de queso', 'categoria': 'Pays'},
        ],
};

FakeApiClient _backend({bool agotado = false, bool vacio = false}) =>
    FakeApiClient(
      respuestas: {
        ApiConstants.favoritos: _favoritos(agotado: agotado, vacio: vacio),
        ApiConstants.login: {
          'success': true,
          'token': 'jwt',
          'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
        },
        ApiConstants.carrito: {
          'success': true,
          'carrito': {'items': <Object>[]},
        },
        // Lo que pide el shell (inicio, catálogo y barra).
        ApiConstants.productos: {
          'success': true,
          'productos': <Map<String, dynamic>>[],
        },
        ApiConstants.promocionesActivas: {
          'success': true,
          'promociones': <Map<String, dynamic>>[],
        },
        ApiConstants.categorias: {
          'success': true,
          'categorias': <Map<String, dynamic>>[],
        },
        ApiConstants.filtros: {
          'success': true,
          'filtros': <String, dynamic>{},
        },
        ApiConstants.configuracionSeccion('personalizacion'): {
          'success': true,
          'config': <String, dynamic>{},
        },
      },
    );

FavoritesViewModel _viewModel(FakeApiClient api) => FavoritesViewModel(
  favoritosRepo: FavoritosRepositoryRemote(api: api),
  productosRepo: ProductosRepositoryRemote(api: api),
  registrarInteres: (_) {},
);

// ── Montaje ─────────────────────────────────────────────────────────────

/// Pantalla de celular (412×869 lógicos, como el Note 10+).
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

/// «Mis Favoritos» suelta, ya cargada y con sus entradas terminadas.
Future<FavoritesViewModel> _montar(
  WidgetTester tester,
  FakeApiClient api,
) async {
  _celular(tester);
  final vm = _viewModel(api);
  await tester.pumpApp(FavoritesScreen(viewModel: vm), api: api);
  await tester.pumpAndSettle();
  return vm;
}

/// La entrada (EntradaSuave) más cercana que envuelve a [texto].
Finder _entradaDe(String texto) => find
    .ancestor(of: find.text(texto), matching: find.byType(EntradaSuave))
    .first;

/// Las escalas de todos los ScaleTransition por encima de [de].
Iterable<double> _escalasSobre(WidgetTester tester, Finder de) => tester
    .widgetList<ScaleTransition>(
      find.ancestor(of: de, matching: find.byType(ScaleTransition)),
    )
    .map((transicion) => transicion.scale.value);

/// Desmonta para cancelar timers de las pantallas del shell.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('al regresar del detalle la cuadrícula se queda: sin '
      'esqueletos ni entrada repetida', (tester) async {
    final api = _backend();
    final vm = await _montar(tester, api);
    expect(opacidadEn(tester, _entradaDe('Fresa Matcha Bliss')), 1);

    // Como el .then del detalle: recarga mientras la página regresa.
    api.demorar(ApiConstants.favoritos, const Duration(seconds: 1));
    unawaited(vm.cargarFavoritos());
    await tester.pump();
    expect(vm.cargando, isTrue);
    expect(find.byType(ProductSkeletonCard), findsNothing);
    expect(opacidadEn(tester, _entradaDe('Fresa Matcha Bliss')), 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(ProductSkeletonCard), findsNothing);
    expect(opacidadEn(tester, _entradaDe('Fresa Matcha Bliss')), 1);
  });

  testWidgets('buscar no repite la entrada de las tarjetas que quedan ni de '
      'las que vuelven', (tester) async {
    await _montar(tester, _backend());

    await tester.enterText(find.byType(TextField), 'pay');
    await tester.pump();
    expect(opacidadEn(tester, _entradaDe('Pay de queso')), 1);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(opacidadEn(tester, _entradaDe('Fresa Matcha Bliss')), 1);
    await tester.pumpAndSettle();
    expect(find.text('2 productos guardados'), findsOneWidget);
  });

  testWidgets('la tarjeta se hunde al tocarla y su foto vuela con la '
      'etiqueta de siempre', (tester) async {
    await _montar(tester, _backend());

    expect(
      find.ancestor(
        of: find.text('Fresa Matcha Bliss'),
        matching: find.byType(PresionEscala),
      ),
      findsOneWidget,
    );
    final heroe = tester.widget<Hero>(
      find
          .descendant(
            of: find.byType(FotoProductoHero).first,
            matching: find.byType(Hero),
          )
          .first,
    );
    expect(heroe.tag, 'producto-img-36');
  });

  testWidgets('el «+» hace su pulso, pasa a palomita y regresa a «+» en su '
      'tamaño', (tester) async {
    await _montar(tester, _backend());
    await tester.iniciarSesion(find.byType(FavoritesScreen));

    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(
      _escalasSobre(tester, find.byIcon(LucideIcons.check)),
      contains(isNot(1)),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.byIcon(LucideIcons.plus), findsNWidgets(2));
    expect(
      _escalasSobre(tester, find.byIcon(LucideIcons.plus).first),
      everyElement(1),
    );
    expect(find.text('Fresa Matcha Bliss agregado al carrito'), findsOneWidget);
  });

  testWidgets('«Avísame»: la campana se mece y queda derecha', (tester) async {
    await _montar(tester, _backend(agotado: true));
    final campana = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byIcon(LucideIcons.bellRing),
    );
    double giro() => tester
        .widget<RotationTransition>(
          find
              .ancestor(of: campana, matching: find.byType(RotationTransition))
              .first,
        )
        .turns
        .value;
    expect(giro(), 0);

    await tester.tap(campana);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(giro(), isNot(0));

    await tester.pumpAndSettle();
    expect(giro(), 0);
  });

  testWidgets('el estado vacío se arma una vez: el corazón late y queda en '
      'su tamaño', (tester) async {
    _celular(tester);
    final api = _backend(vacio: true);
    await tester.pumpApp(FavoritesScreen(viewModel: _viewModel(api)), api: api);
    await tester.pump();
    expect(find.text('Sin favoritos aún'), findsOneWidget);
    final corazon = find.byIcon(Icons.favorite_rounded);
    double latido() => tester
        .widget<ScaleTransition>(
          find
              .ancestor(of: corazon, matching: find.byType(ScaleTransition))
              .first,
        )
        .scale
        .value;

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(latido(), greaterThan(1));

    await tester.pumpAndSettle();
    expect(latido(), 1);
    expect(opacidadEn(tester, _entradaDe('Sin favoritos aún')), 1);
  });

  testWidgets('en el shell, el «+» lanza la miniatura al carrito', (
    tester,
  ) async {
    // Celular ancho, como main_screen_test: el shell completo cabe.
    tester.view
      ..physicalSize = const Size(1440, 3040)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final api = _backend();
    await tester.pumpApp(const MainScreen(), api: api);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.iniciarSesion(find.byType(MainScreen));
    await tester.pump();

    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FavoritesScreen(viewModel: _viewModel(api)),
          ),
        )
        .ignore();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final antes = find.byType(ClipOval).evaluate().length;
    await tester.tap(
      find
          .descendant(
            of: find.byType(FavoritesScreen),
            matching: find.byIcon(LucideIcons.plus),
          )
          .first,
    );
    await tester.pump();
    expect(find.byType(ClipOval), findsNWidgets(antes + 1));

    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ClipOval), findsNWidgets(antes));
    await _desmontar(tester);
  });
}
