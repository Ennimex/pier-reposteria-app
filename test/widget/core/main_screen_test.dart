// test/widget/core/main_screen_test.dart — el shell del cliente con el
// sistema de movimiento: la barra conserva etiquetas y orden con IconoPestana
// en las cinco pestañas (uno elegido), la insignia del carrito sigue en la
// pestaña activa, cada
// pestaña tiene su HeroController, el vuelo al carrito tiene ámbito y
// destino, la vista de invitado entra al abrir Pedidos y el regreso del
// sistema sigue sacando la pila de la pestaña visible. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/animated_indexed_stack.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/home/widgets/home_screen.dart';
import 'package:pier_pasteleria/ui/main/widgets/main_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

FakeApiClient _backend() => FakeApiClient(
  respuestas: {
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
    ApiConstants.filtros: {'success': true, 'filtros': <String, dynamic>{}},
    ApiConstants.configuracionSeccion('personalizacion'): {
      'success': true,
      'config': <String, dynamic>{},
    },
    ApiConstants.carrito: {
      'success': true,
      'carrito': {
        'items': [
          {
            'producto_id': 36,
            'carrito_item_id': 151,
            'nombre': 'Fresa Matcha Bliss',
            'precio_unitario': '90.00',
            'precio_original': '100.00',
            'cantidad': 2,
          },
          {
            'producto_id': 12,
            'carrito_item_id': 152,
            'nombre': 'Pay de limón',
            'precio_unitario': '50.00',
            'precio_original': '50.00',
            'cantidad': 1,
          },
        ],
      },
    },
  },
);

/// Monta el shell en una pantalla de celular ancha (576×1216 lógicos, como
/// las pruebas de aceptación: con la fuente de pruebas el catálogo no cabe
/// en menos).
Future<void> _montar(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const MainScreen(), api: _backend());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Desmonta para cancelar timers de las pantallas (como en home_screen_test).
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder _etiqueta(String texto) => find.descendant(
  of: find.byType(BottomNavigationBar),
  matching: find.text(texto),
);

Future<void> _irA(WidgetTester tester, String pestana) async {
  await tester.tap(_etiqueta(pestana));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Los íconos de la barra (IconoPestana en las dos ranuras de las cinco
/// pestañas) y el único que está elegido.
Iterable<IconoPestana> _iconos(WidgetTester tester) =>
    tester.widgetList<IconoPestana>(find.byType(IconoPestana));

IconoPestana _iconoActivo(WidgetTester tester) =>
    _iconos(tester).singleWhere((icono) => icono.activo);

void main() {
  testWidgets('la barra conserva etiquetas y orden y anima el ícono activo', (
    tester,
  ) async {
    await _montar(tester);

    const etiquetas = ['Inicio', 'Catálogo', 'Carrito', 'Pedidos', 'Más'];
    final posiciones = [
      for (final etiqueta in etiquetas)
        tester.getCenter(_etiqueta(etiqueta)).dx,
    ];
    expect(posiciones, [...posiciones]..sort());
    expect(_iconos(tester), hasLength(5));
    expect(_iconoActivo(tester).icono, LucideIcons.house);

    await _irA(tester, 'Catálogo');
    final contexto = tester.element(find.byType(MainScreen));
    expect(contexto.read<NavigationProvider>().selectedIndex, 1);
    expect(_iconos(tester), hasLength(5));
    expect(_iconoActivo(tester).icono, LucideIcons.store);
    await _desmontar(tester);
  });

  testWidgets('cada pestaña tiene su propio HeroController', (tester) async {
    await _montar(tester);

    final controladores = tester
        .widgetList<HeroControllerScope>(
          find.descendant(
            of: find.byType(AnimatedIndexedStack),
            matching: find.byType(HeroControllerScope, skipOffstage: false),
            skipOffstage: false,
          ),
        )
        .map((alcance) => alcance.controller)
        .whereType<HeroController>()
        .toList();
    expect(controladores, hasLength(5));
    expect(controladores.toSet(), hasLength(5));
    await _desmontar(tester);
  });

  testWidgets('la insignia del carrito aparece y sigue en la pestaña activa', (
    tester,
  ) async {
    await _montar(tester);
    final insignia = find.descendant(
      of: find.byType(InsigniaCarrito),
      matching: find.text('3'),
    );
    expect(insignia, findsNothing);

    await tester
        .element(find.byType(MainScreen))
        .read<CartProvider>()
        .cargarDesdeBackend();
    await tester.pump();
    expect(insignia, findsOneWidget);

    await _irA(tester, 'Carrito');
    expect(insignia, findsOneWidget);
    expect(_iconoActivo(tester).icono, LucideIcons.shoppingCart);
    await _desmontar(tester);
  });

  testWidgets('el vuelo al carrito tiene ámbito y destino', (tester) async {
    await _montar(tester);
    expect(find.byType(VueloAlCarrito), findsOneWidget);
    expect(find.byType(DestinoVuelo), findsOneWidget);

    final antes = find.byType(ClipOval).evaluate().length;
    VueloAlCarrito.lanzar(
      tester.element(find.byType(HomeScreen)),
      imagenUrl: '',
    );
    await tester.pump();
    expect(find.byType(ClipOval), findsNWidgets(antes + 1));
    await tester.pump(AppMovimiento.vuelo);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ClipOval), findsNWidgets(antes));
    await _desmontar(tester);
  });

  testWidgets(
    'sin sesión, Pedidos invita a iniciar sesión y entra al abrirse',
    (
      tester,
    ) async {
      await _montar(tester);
      // Oculta, la vista de invitado no gastó su entrada.
      final entradas = find.byType(EntradaSuave, skipOffstage: false);
      expect(entradas, findsNWidgets(4));
      // Esperan a que la pestaña empiece a verse (token, no un valor propio).
      expect(
        tester.widgetList<EntradaSuave>(entradas).map((e) => e.retraso),
        everyElement(AppMovimiento.trasPestana),
      );
      double opacidad(Finder entrada) => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: entrada,
                  matching: find.byType(FadeTransition, skipOffstage: false),
                  skipOffstage: false,
                )
                .first,
          )
          .opacity
          .value;
      expect(opacidad(entradas.first), 0);

      await _irA(tester, 'Pedidos');
      expect(find.text('Mis Pedidos'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacidad(entradas.first), 1);
      expect(opacidad(entradas.last), 1);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      await _desmontar(tester);
    },
  );

  testWidgets('el regreso del sistema saca la pila de la pestaña visible', (
    tester,
  ) async {
    await _montar(tester);
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Detalle'))),
          ),
        )
        .ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Detalle'), findsOneWidget);

    // Como el botón de regreso de Android: lo atiende el PopScope del shell.
    Navigator.of(tester.element(find.byType(MainScreen))).maybePop().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Detalle'), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    await _desmontar(tester);
  });
}
