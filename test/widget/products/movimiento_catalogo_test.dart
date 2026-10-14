// test/widget/products/movimiento_catalogo_test.dart — el movimiento del
// catálogo y del detalle de producto: las tarjetas entran en cascada una sola
// vez por tanda (buscar no las repite, cambiar de categoría sí), el chip de
// una categoría pedida desde el inicio llega a la vista aunque esté al fondo
// de la fila, el estado vacío entra y termina quieto, el «+» rebota, vuelve a
// su tamaño y pasa a palomita, el detalle arma su hoja después del push, el
// total rueda hasta el valor exacto, «−» en 1 sacude la píldora, «Añadir»
// rechazado no se queda agrandado, el «+» de un recomendado rebota al tocarlo
// (sin esperar al backend) y la foto de un recomendado comparte ámbito con el
// detalle que abre; con movimiento reducido todo queda en su lugar y ningún
// botón de agregar rebota. En el shell, la primera tanda del catálogo espera a
// que se abra su pestaña, el «+» lanza la miniatura al carrito (la insignia
// del encabezado la espera en vez de adelantarse) y la foto de la tarjeta
// vuela al detalle, cuyo «Añadir» también la lanza. También las piezas de
// movimiento_catalogo.dart. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/core/ui/tarjeta_producto_angosta.dart';
import 'package:pier_pasteleria/ui/main/widgets/main_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/catalogo_secciones.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_galeria.dart';
import 'package:pier_pasteleria/ui/products/widgets/detalle_recomendaciones.dart';
import 'package:pier_pasteleria/ui/products/widgets/movimiento_catalogo.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

// ── Datos del backend falso ─────────────────────────────────────────────

Map<String, dynamic> _producto(
  int id,
  String nombre, {
  num precio = 300,
  num? grande,
  String categoria = 'Pasteles',
}) => {
  'id': id,
  'nombre': nombre,
  'descripcion': 'Rico $nombre',
  'precio_chico': precio,
  'precio_grande': grande,
  'categoria': categoria,
  'imagen_url': '',
  'popular': id == 1,
  'activo': true,
  'rating': 4.5,
};

/// Carrito en memoria: POST agrega la línea y GET la devuelve (como el
/// backend real, que el CartProvider recarga después de cada alta).
class _Carrito {
  final List<Map<String, dynamic>> lineas = [];

  Map<String, dynamic> responder(LlamadaApi llamada) {
    if (llamada.metodo == 'POST-Auth') {
      final id = llamada.body!['producto_id'];
      lineas.add({
        'producto_id': id,
        'carrito_item_id': 150 + lineas.length,
        'nombre': 'Producto $id',
        'precio_unitario': '300.00',
        'precio_original': '300.00',
        'cantidad': llamada.body!['cantidad'],
        'tamano': llamada.body!['tamano'],
      });
      return {'success': true};
    }
    return {
      'success': true,
      'carrito': {'items': lineas},
    };
  }
}

FakeApiClient _backendCatalogo({_Carrito? carrito}) => FakeApiClient(
  respuestas: {
    ApiConstants.productos: {
      'success': true,
      'productos': [
        _producto(1, 'Chocoflan'),
        _producto(2, 'Cheesecake', precio: 450, categoria: 'Pays'),
        _producto(3, 'Rosca', precio: 380),
      ],
    },
    ApiConstants.promocionesActivas: {
      'success': true,
      'promociones': <Map<String, dynamic>>[],
    },
    ApiConstants.categorias: {
      'success': true,
      'categorias': [
        {'id': 1, 'nombre': 'Pasteles'},
        {'id': 2, 'nombre': 'Pays'},
      ],
    },
    ApiConstants.filtros: {'success': true, 'filtros': <String, dynamic>{}},
    ApiConstants.categoriaOpciones('2'): {
      'success': true,
      'sabores': <String>[],
      'tipos': <String>[],
    },
    ApiConstants.configuracionSeccion('personalizacion'): {
      'success': true,
      'config': <String, dynamic>{},
    },
    ApiConstants.login: {
      'success': true,
      'token': 'jwt',
      'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
    },
    ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
    ApiConstants.carrito: (carrito ?? _Carrito()).responder,
  },
);

/// Una fila de categorías mucho más ancha que el celular: «Cafetería» queda
/// al fondo, varios chips más allá de lo que se ve.
const List<String> _filaLarga = [
  'Pasteles',
  'Pays',
  'Roscas',
  'Postres',
  'Gelatinas',
  'Galletas',
  'Panadería',
  'Bebidas',
  'Temporada',
  'Cafetería',
];

FakeApiClient _backendFilaLarga() => FakeApiClient(
  respuestas: {
    ApiConstants.productos: {
      'success': true,
      'productos': [
        _producto(1, 'Chocoflan'),
        _producto(2, 'Capuchino', categoria: 'Cafetería'),
      ],
    },
    ApiConstants.categorias: {
      'success': true,
      'categorias': [
        for (final (i, nombre) in _filaLarga.indexed)
          {'id': i + 1, 'nombre': nombre},
      ],
    },
  },
);

final Product _chocoflan = Product.fromJson({
  ..._producto(7, 'Chocoflan', grande: 500),
  'reviews': 2,
});

FakeApiClient _backendDetalle() => FakeApiClient(
  respuestas: {
    ApiConstants.productoById('7'): {
      'success': true,
      'producto': {'reviews': 2, 'rating_promedio': 4.5},
      'resenas': <Map<String, dynamic>>[],
    },
    ApiConstants.recomendaciones('7'): {
      'success': true,
      'recomendaciones': [_producto(8, 'Pay de queso', precio: 250)],
    },
    ApiConstants.productos: {
      'success': true,
      'productos': [_producto(8, 'Pay de queso', precio: 250)],
    },
    ApiConstants.promocionesActivas: {
      'success': true,
      'promociones': <Map<String, dynamic>>[],
    },
    ApiConstants.login: {
      'success': true,
      'token': 'jwt',
      'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
    },
    ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
    ApiConstants.carrito: {'success': true},
  },
);

// ── Montaje ─────────────────────────────────────────────────────────────

/// Pantalla alta: el catálogo o el detalle caben completos.
void _pantallaAlta(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 4200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Avanza cuadro a cuadro hasta que [finder] aparece (el catálogo llega en
/// microtareas, uno o dos cuadros después de montar).
Future<void> _hastaQueAparezca(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

/// Escalas del rebote de los botones «agregar» dentro de [de]: el
/// ScaleTransition que anima la pantalla alrededor de su PresionEscala.
Iterable<double> _rebotes(WidgetTester tester, Finder de) => tester
    .widgetList<ScaleTransition>(
      find.descendant(
        of: de,
        matching: find.byWidgetPredicate(
          (w) => w is ScaleTransition && w.child is PresionEscala,
        ),
      ),
    )
    .map((t) => t.scale.value);

/// La entrada (EntradaSuave) más cercana al texto [nombre].
Finder _entradaDe(String nombre) => find
    .ancestor(of: find.text(nombre), matching: find.byType(EntradaSuave))
    .first;

/// La entrada de la tarjeta [nombre] del catálogo, aunque su pestaña esté
/// oculta (Inicio también puede mostrar el producto).
Finder _entradaEnCatalogo(String nombre) => find
    .ancestor(
      of: find.descendant(
        of: find.byType(ProductsScreen, skipOffstage: false),
        matching: find.text(nombre, skipOffstage: false),
        skipOffstage: false,
      ),
      matching: find.byType(EntradaSuave, skipOffstage: false),
    )
    .first;

/// Página anfitriona: abre el detalle con push (como el catálogo).
class _Anfitrion extends StatelessWidget {
  const _Anfitrion();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(product: _chocoflan),
          ),
        ),
        child: const Text('Abrir'),
      ),
    ),
  );
}

Future<FakeApiClient> _abrirDetalle(
  WidgetTester tester, {
  bool conSesion = false,
}) async {
  _pantallaAlta(tester);
  final api = _backendDetalle();
  await tester.pumpApp(const _Anfitrion(), api: api);
  if (conSesion) await tester.iniciarSesion(find.byType(_Anfitrion));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return api;
}

/// El shell en un celular ancho (como main_screen_test).
Future<void> _montarShell(WidgetTester tester, FakeApiClient api) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const MainScreen(), api: api);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _irAlCatalogo(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Catálogo'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Desmonta para cancelar timers de las pantallas del shell.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('piezas de movimiento del catálogo', () {
    testWidgets(
      'CifraRodante sube si crece, baja si decrece y termina exacta',
      (
        tester,
      ) async {
        Widget cifra(int valor) => CifraRodante(valor: valor, texto: '$valor');
        await montarMovimiento(tester, cifra(1));
        final reposo = tester.getTopLeft(find.text('1')).dy;

        await montarMovimiento(tester, cifra(2));
        await tester.pump(const Duration(milliseconds: 40));
        // El nuevo entra desde abajo y el anterior sigue saliendo.
        expect(tester.getTopLeft(find.text('2')).dy, greaterThan(reposo));
        expect(find.text('1'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsNothing);
        expect(tester.getTopLeft(find.text('2')).dy, reposo);

        await montarMovimiento(tester, cifra(1));
        await tester.pump(const Duration(milliseconds: 40));
        // Al bajar, el nuevo llega desde arriba.
        expect(tester.getTopLeft(find.text('1')).dy, lessThan(reposo));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsNothing);
      },
    );

    testWidgets('TextoEstiloAnimado funde el color y conserva lo heredado', (
      tester,
    ) async {
      Widget texto(Color color) => DefaultTextStyle(
        style: const TextStyle(fontSize: 20, letterSpacing: 2),
        child: TextoEstiloAnimado('Pays', estilo: TextStyle(color: color)),
      );
      TextStyle estilo() =>
          tester.widget<RichText>(find.byType(RichText)).text.style!;

      await montarMovimiento(tester, texto(Colors.black));
      expect(estilo().color, Colors.black);
      expect(estilo().fontSize, 20);

      await montarMovimiento(tester, texto(Colors.white));
      await tester.pump(const Duration(milliseconds: 100));
      expect(estilo().color, isNot(Colors.black));
      expect(estilo().color, isNot(Colors.white));
      await tester.pumpAndSettle();
      expect(estilo().color, Colors.white);
      expect(estilo().letterSpacing, 2);
      expect(find.text('Pays'), findsOneWidget);
    });

    testWidgets(
      'AparicionFoto: en caché se pinta tal cual, de red con fundido',
      (
        tester,
      ) async {
        const foto = SizedBox.square(dimension: 10);
        await montarMovimiento(
          tester,
          const AparicionFoto(foto: foto, cuadro: null, sincrona: true),
        );
        expect(find.byType(AnimatedOpacity), findsNothing);

        await montarMovimiento(
          tester,
          const AparicionFoto(foto: foto, cuadro: null, sincrona: false),
        );
        double opacidad() => tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .opacity;
        expect(opacidad(), 0);

        await montarMovimiento(
          tester,
          const AparicionFoto(foto: foto, cuadro: 0, sincrona: false),
        );
        expect(opacidad(), 1);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('BrilloUnaVez cruza una vez y termina; reducido no anima', (
      tester,
    ) async {
      const insignia = SizedBox(width: 80, height: 20);
      await montarMovimiento(
        tester,
        const BrilloUnaVez(radio: BorderRadius.zero, child: insignia),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(const SizedBox());
      await montarMovimiento(
        tester,
        const BrilloUnaVez(radio: BorderRadius.zero, child: insignia),
        reducido: true,
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('Vaiven empieza y termina en 0 sin pasarse de su amplitud', () {
      const vaiven = Vaiven();
      expect(vaiven.amplitud, 0.04);
      expect(vaiven.transform(0), 0);
      expect(vaiven.transform(1), closeTo(0, 1e-9));
      for (var t = 0.0; t <= 1; t += 0.05) {
        expect(vaiven.transform(t).abs(), lessThanOrEqualTo(0.04));
      }
    });

    testWidgets('TarjetaProductoAngosta solo tiene Hero con ámbito', (
      tester,
    ) async {
      final producto = Product.fromJson(_producto(5, 'Rosca'));
      Widget tarjeta({String? ambito}) => SizedBox(
        height: 310,
        child: TarjetaProductoAngosta(
          producto: producto,
          precio: 300,
          boton: const SizedBox.shrink(),
          ambitoFoto: ambito,
        ),
      );
      // Inicio repite productos entre carruseles: sin ámbito, ningún Hero.
      await montarMovimiento(tester, tarjeta());
      expect(find.byType(Hero), findsNothing);

      await montarMovimiento(tester, tarjeta(ambito: 'recomendado-1'));
      expect(
        tester.widget<Hero>(find.byType(Hero)).tag,
        FotoProductoHero.etiqueta('5', ambito: 'recomendado-1'),
      );
    });
  });

  group('catálogo', () {
    testWidgets('las tarjetas entran en cascada y buscar no las repite', (
      tester,
    ) async {
      _pantallaAlta(tester);
      await tester.pumpApp(const ProductsScreen(), api: _backendCatalogo());
      await _hastaQueAparezca(tester, find.text('Rosca'));

      // Recién construidas: todavía no aparecen y la tercera espera más.
      expect(opacidadEn(tester, _entradaDe('Chocoflan')), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        opacidadEn(tester, _entradaDe('Chocoflan')),
        greaterThan(opacidadEn(tester, _entradaDe('Rosca'))),
      );
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('Rosca')), 1);

      // Buscar filtra al instante: lo que sigue (o vuelve) no se repite.
      await tester.enterText(find.byType(TextField), 'Ch');
      await tester.pump();
      expect(find.text('Rosca'), findsNothing);
      expect(opacidadEn(tester, _entradaDe('Chocoflan')), 1);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('Rosca')), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('cambiar de categoría vuelve a repartir las tarjetas', (
      tester,
    ) async {
      _pantallaAlta(tester);
      await tester.pumpApp(const ProductsScreen(), api: _backendCatalogo());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pays').first);
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('Cheesecake')), 0);
      // Arranca en el cuadro siguiente (post-frame) y luego avanza.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacidadEn(tester, _entradaDe('Cheesecake')), greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('Cheesecake')), 1);
      // "Quitar filtros" abrió su espacio y se puede tocar.
      expect(find.text('Quitar filtros'), findsOneWidget);
      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar filtros'), findsNothing);
    });

    testWidgets('el estado vacío entra en cascada y termina quieto', (
      tester,
    ) async {
      _pantallaAlta(tester);
      await tester.pumpApp(const ProductsScreen(), api: _backendCatalogo());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      double opacidadDe(String texto) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(texto),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacidadDe('Sin resultados'), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacidadDe('Sin resultados'), greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacidadDe('Sin resultados'), 1);
      expect(opacidadDe('Limpiar filtros'), 1);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets(
      'con sesión, el + rebota, vuelve a su tamaño y pasa a palomita',
      (
        tester,
      ) async {
        _pantallaAlta(tester);
        final carrito = _Carrito();
        await tester.pumpApp(
          const ProductsScreen(),
          api: _backendCatalogo(carrito: carrito),
        );
        await tester.iniciarSesion(find.byType(ProductsScreen));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(LucideIcons.plus).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        Rect boton() => tester.getRect(
          find
              .ancestor(
                of: find.byIcon(LucideIcons.check),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        // A media animación el botón no está en su tamaño...
        expect(boton().width, isNot(closeTo(34, 0.01)));
        await tester.pumpAndSettle();
        // ...y al terminar vuelve exacto (antes se quedaba al 130 %).
        expect(boton().width, closeTo(34, 0.01));
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
        expect(find.text('Chocoflan agregado'), findsOneWidget);
        expect(carrito.lineas, hasLength(1));
      },
    );

    testWidgets('con «reducir movimiento» el + no rebota y pasa a palomita', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      _pantallaAlta(tester);
      final carrito = _Carrito();
      await tester.pumpApp(
        const ProductsScreen(),
        api: _backendCatalogo(carrito: carrito),
      );
      await tester.iniciarSesion(find.byType(ProductsScreen));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _rebotes(tester, find.byType(ProductoCatalogoCard)),
          everyElement(1),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Chocoflan agregado'), findsOneWidget);
      expect(carrito.lineas, hasLength(1));
    });

    testWidgets(
      'una categoría pedida desde el inicio fuera de la vista llega a la fila',
      (tester) async {
        // El celular de main_screen_test: la fila de chips mide casi el triple
        // de la pantalla.
        tester.view
          ..physicalSize = const Size(1440, 3040)
          ..devicePixelRatio = 2.5;
        addTearDown(tester.view.reset);
        await tester.pumpApp(const ProductsScreen(), api: _backendFilaLarga());
        await tester.pumpAndSettle();
        final chip = find.descendant(
          of: find.byType(CatalogoCategorias),
          matching: find.text('Cafetería'),
        );
        // Al fondo de la fila: no se ve.
        expect(chip, findsNothing);

        tester
            .element(find.byType(ProductsScreen))
            .read<NavigationProvider>()
            .goCatalogo(categoria: 'Cafetería');
        await tester.pumpAndSettle();

        // La fila se deslizó hasta el chip elegido y quedó completo a la vista.
        expect(chip, findsOneWidget);
        final fila = tester.getRect(find.byType(CatalogoCategorias));
        final elegido = tester.getRect(chip);
        expect(elegido.left, greaterThanOrEqualTo(fila.left));
        expect(elegido.right, lessThanOrEqualTo(fila.right));
        expect(find.text('Capuchino'), findsOneWidget);
      },
    );

    testWidgets('con movimiento reducido las tarjetas ya están en su lugar', (
      tester,
    ) async {
      _pantallaAlta(tester);
      await tester.pumpApp(
        const ConMovimientoReducido(child: ProductsScreen()),
        api: _backendCatalogo(),
      );
      await _hastaQueAparezca(tester, find.text('Rosca'));
      expect(opacidadEn(tester, _entradaDe('Chocoflan')), 1);
      expect(opacidadEn(tester, _entradaDe('Rosca')), 1);
      await tester.pumpAndSettle();
    });
  });

  group('detalle', () {
    testWidgets('la hoja de información entra después del push', (
      tester,
    ) async {
      _pantallaAlta(tester);
      await tester.pumpApp(const _Anfitrion(), api: _backendDetalle());
      await tester.tap(find.text('Abrir'));
      // El primer cuadro del push la construye fuera de escena (el
      // HeroController mide); en el segundo ya está a la vista.
      await tester.pump();
      await tester.pump();

      final titulo = _entradaDe('Chocoflan');
      expect(
        tester.widget<EntradaSuave>(titulo).retraso,
        AppMovimiento.trasEmpuje,
      );
      expect(opacidadEn(tester, titulo), 0);
      await tester.pumpAndSettle();
      expect(opacidadEn(tester, _entradaDe('Chocoflan')), 1);
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('el total rueda al cambiar de tamaño y termina exacto', (
      tester,
    ) async {
      await _abrirDetalle(tester);
      expect(find.text(r'$300.00'), findsOneWidget);

      await tester.tap(find.text('Grande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text(r'$300.00'), findsOneWidget);
      expect(find.text(r'$500.00'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(r'$300.00'), findsNothing);
      expect(find.text(r'$500.00'), findsOneWidget);
    });

    testWidgets('− en 1 sacude la píldora y la cantidad sigue en 1', (
      tester,
    ) async {
      await _abrirDetalle(tester);
      double desplazamiento() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(Sacudida),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .x;

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(desplazamiento(), isNot(0));
      await tester.pumpAndSettle();
      expect(desplazamiento(), 0);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('si el backend rechaza el alta, Añadir vuelve a su tamaño', (
      tester,
    ) async {
      final api = await _abrirDetalle(tester, conSesion: true);
      api.fallar(ApiConstants.carrito, 'No hay stock suficiente');

      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      final boton = find.ancestor(
        of: find.text('Añadir'),
        matching: find.byType(ElevatedButton),
      );
      // Sin escala encima (antes se quedaba al 108 %).
      expect(tester.getRect(boton).width, tester.getSize(boton).width);
      expect(find.text('No hay stock suficiente'), findsOneWidget);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
    });

    testWidgets('con movimiento reducido la hoja ya está y nada se sacude', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      _pantallaAlta(tester);
      await tester.pumpApp(const _Anfitrion(), api: _backendDetalle());
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump();
      expect(opacidadEn(tester, _entradaDe('Chocoflan')), 1);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final sacudida = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(Sacudida),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(sacudida.transform.getTranslation().x, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('el + de un recomendado rebota al tocarlo, sin esperar al '
        'backend (como «Añadir»)', (tester) async {
      final api = await _abrirDetalle(tester, conSesion: true);
      api.demorar(ApiConstants.carrito, const Duration(seconds: 1));
      final recomendado = find.byType(ProductoRelacionadoCard);

      await tester.tap(find.byIcon(LucideIcons.plus).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // El backend aún no responde y el botón ya va a media animación.
      expect(find.text('Pay de queso agregado'), findsNothing);
      expect(_rebotes(tester, recomendado).single, isNot(1));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Pay de queso agregado'), findsOneWidget);
      expect(_rebotes(tester, recomendado).single, 1);
    });

    testWidgets('con «reducir movimiento» ni «Añadir» ni el + de un '
        'recomendado rebotan', (tester) async {
      activarReducirMovimientoIos(tester);
      final api = await _abrirDetalle(tester, conSesion: true);
      final recomendado = find.byType(ProductoRelacionadoCard);
      double anadir() => tester
          .widget<ScaleTransition>(
            find
                .ancestor(
                  of: find.text('Añadir'),
                  matching: find.byType(ScaleTransition),
                )
                .first,
          )
          .scale
          .value;

      await tester.tap(find.byIcon(LucideIcons.plus).last);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_rebotes(tester, recomendado), everyElement(1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Pay de queso agregado'), findsOneWidget);
      // Se va el aviso (2 s) para que el del rechazo no espere en la cola.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Rechazado: el detalle sigue abierto y se puede mirar el botón.
      api.fallar(ApiConstants.carrito, 'No hay stock suficiente');
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(anadir(), 1);
      }
      await tester.pumpAndSettle();
      expect(find.text('No hay stock suficiente'), findsOneWidget);
    });

    testWidgets('la foto de un recomendado vuela con el ámbito de su detalle', (
      tester,
    ) async {
      await _abrirDetalle(tester);
      final tarjeta = tester.widget<FotoProductoHero>(
        find.descendant(
          of: find.byType(TarjetaProductoAngosta),
          matching: find.byType(FotoProductoHero),
        ),
      );
      expect(tarjeta.ambito, startsWith('recomendado-'));

      await tester.tap(find.text('Pay de queso'));
      await tester.pumpAndSettle();
      final galeria = tester.widget<FotoProductoHero>(
        find.descendant(
          of: find.byType(DetalleGaleria),
          matching: find.byType(FotoProductoHero),
        ),
      );
      expect(galeria.productoId, '8');
      expect(galeria.ambito, tarjeta.ambito);
    });
  });

  group('en el shell', () {
    testWidgets('la primera tanda espera a que se abra la pestaña', (
      tester,
    ) async {
      await _montarShell(tester, _backendCatalogo());
      // Construidas con la pestaña oculta: esperan, sin gastar su entrada.
      final oculta = _entradaEnCatalogo('Rosca');
      expect(
        tester.widget<EntradaSuave>(oculta).retraso,
        AppMovimiento.trasPestana,
      );
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .descendant(
                    of: oculta,
                    matching: find.byType(FadeTransition, skipOffstage: false),
                    skipOffstage: false,
                  )
                  .first,
            )
            .opacity
            .value,
        0,
      );

      await _irAlCatalogo(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacidadEn(tester, _entradaDe('Rosca')), 1);
      await _desmontar(tester);
    });

    testWidgets('con sesión, el + del catálogo lanza la miniatura al carrito', (
      tester,
    ) async {
      await _montarShell(tester, _backendCatalogo());
      await tester.iniciarSesion(find.byType(MainScreen));
      await _irAlCatalogo(tester);
      await tester.pump(const Duration(seconds: 1));

      final antes = find.byType(ClipOval).evaluate().length;
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      expect(find.byType(ClipOval), findsNWidgets(antes + 1));
      // El carrito del encabezado no se adelanta: su insignia espera a que la
      // miniatura llegue a la barra para aparecer.
      final insigniaEncabezado = find.descendant(
        of: find.byType(CatalogoHeader),
        matching: find.byType(InsigniaCarrito),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(escalaEn(tester, insigniaEncabezado), 0);

      await tester.pump(AppMovimiento.vuelo - const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ClipOval), findsNWidgets(antes));
      // Aterrizó: la insignia de la barra ya muestra el producto.
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // ...y la del encabezado empieza a crecer junto con ella.
      await tester.pump(const Duration(milliseconds: 60));
      expect(escalaEn(tester, insigniaEncabezado), greaterThan(0));
      await _desmontar(tester);
    });

    testWidgets('la foto vuela al detalle y «Añadir» manda la miniatura', (
      tester,
    ) async {
      // A 1080 de ancho: con la fuente de pruebas el detalle no cabe en menos.
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(const MainScreen(), api: _backendCatalogo());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.iniciarSesion(find.byType(MainScreen));
      await _irAlCatalogo(tester);
      await tester.pump(const Duration(seconds: 1));

      final fotoTarjeta = find
          .ancestor(
            of: find.text('Chocoflan'),
            matching: find.byType(ProductoCatalogoCard),
          )
          .first;
      Finder imagenDe(Finder tarjeta) => find.descendant(
        of: find.descendant(
          of: tarjeta,
          matching: find.byType(FotoProductoHero),
        ),
        matching: find.byType(Image),
      );
      expect(imagenDe(fotoTarjeta), findsOneWidget);

      await tester.tap(find.text('Chocoflan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // A medio vuelo la tarjeta deja su hueco (la foto va en el aire).
      expect(imagenDe(fotoTarjeta), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProductDetailScreen), findsOneWidget);

      final antes = find.byType(ClipOval).evaluate().length;
      await tester.tap(find.text('Añadir'));
      await tester.pump();
      // El backend aceptó: la miniatura sale del botón y el detalle se va.
      expect(find.byType(ClipOval), findsNWidgets(antes + 1));
      expect(find.text('1 × Chocoflan agregado'), findsOneWidget);

      await tester.pump(AppMovimiento.vuelo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProductDetailScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await _desmontar(tester);
    });
  });
}
