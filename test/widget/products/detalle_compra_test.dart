// test/widget/products/detalle_compra_test.dart — la barra de compra del
// detalle (#364): en pantallas de menos de 400 de ancho el botón no cabía con
// su texto junto al total y la cantidad y se quedaba solo con el ícono del
// carrito (visto en Firebase Test Lab, #81). Ahí baja a su propio renglón y
// ocupa el ancho completo; en las pantallas anchas la barra sigue en un
// renglón.
@Tags(['regresion'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/repositories/productos_repository.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_reposteria/ui/products/widgets/detalle_compra.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// Margen de la hoja del detalle a cada lado y relleno de la barra.
const double _margenDeLaHoja = 20;
const double _rellenoDeLaBarra = 20;

Product _producto({bool agotado = false}) => Product.fromJson({
      'id': 7,
      'nombre': 'Chocoflan',
      'descripcion': 'Pastel de chocolate con flan',
      'precio_chico': 350,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'activo': true,
      'stock_online': agotado ? 0 : null,
      'rating': 4.5,
    });

/// Lo que se tocó en la barra.
class _Toques {
  int agregar = 0;
  int avisarme = 0;
}

/// Monta la barra como va en el detalle (con el margen de la hoja) en un
/// celular de [pantalla] de ancho y con la letra del sistema a [letra].
Future<_Toques> _montar(
  WidgetTester tester, {
  required double pantalla,
  double letra = 1,
  bool agotado = false,
}) async {
  tester.view
    ..physicalSize = Size(pantalla, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final toques = _Toques();
  ProductDetailViewModel? vm;
  addTearDown(() => vm?.dispose());
  await tester.pumpApp(
    Builder(
      builder: (context) {
        final modelo = vm ??= ProductDetailViewModel(
          producto: _producto(agotado: agotado),
          productosRepo: context.read<ProductosRepository>(),
          favoritosRepo: context.read<FavoritosRepository>(),
          resenasRepo: context.read<ResenasRepository>(),
          demandaRepo: context.read<DemandaRepository>(),
        );
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _margenDeLaHoja),
            child: Center(
              child: ListenableBuilder(
                listenable: modelo,
                builder: (context, _) => DetalleBarraCompra(
                  viewModel: modelo,
                  promociones: context.read<ProductProvider>(),
                  animacion: kAlwaysCompleteAnimation,
                  onAgregar: () => toques.agregar++,
                  onAvisarme: () => toques.avisarme++,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return toques;
}

final Finder _boton = find.byType(ElevatedButton);
final Finder _mas = find.byIcon(LucideIcons.plus);

/// El ancho de la barra por dentro en un celular de [pantalla] de ancho.
double _anchoPorDentro(double pantalla) =>
    pantalla - 2 * _margenDeLaHoja - 2 * _rellenoDeLaBarra;

void main() {
  group('DetalleBarraCompra en pantallas angostas (#364)', () {
    for (final pantalla in <double>[320, 360, 393]) {
      testWidgets('en un celular de ${pantalla.round()} de ancho el botón '
          'baja a su renglón, a todo lo ancho y con su texto', (tester) async {
        await _montar(tester, pantalla: pantalla);

        expect(find.text('Añadir'), findsOneWidget);
        final boton = tester.getRect(_boton);
        expect(boton.top, greaterThan(tester.getRect(_mas).bottom));
        expect(boton.width, moreOrLessEquals(_anchoPorDentro(pantalla)));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el botón de su renglón añade al carrito', (tester) async {
      final toques = await _montar(tester, pantalla: 360);

      await tester.tap(find.text('Añadir'));

      expect(toques.agregar, 1);
      expect(toques.avisarme, 0);
    });

    testWidgets('un producto agotado dice «Avísame» en su renglón',
        (tester) async {
      final toques = await _montar(tester, pantalla: 360, agotado: true);

      expect(find.text('Añadir'), findsNothing);
      await tester.tap(find.text('Avísame'));

      expect(toques.avisarme, 1);
      expect(toques.agregar, 0);
    });

    // Antes, en 393 de ancho el texto del botón desaparecía al pasar de
    // $1,000 (3 piezas de $350).
    testWidgets('al sumar piezas el botón no cambia de lugar ni pierde su '
        'texto', (tester) async {
      await _montar(tester, pantalla: 393);
      final antes = tester.getRect(_boton);

      for (var i = 0; i < 3; i++) {
        await tester.tap(_mas);
        await tester.pumpAndSettle();
      }

      expect(find.text(r'$1400.00'), findsOneWidget);
      expect(find.text('Añadir'), findsOneWidget);
      final despues = tester.getRect(_boton);
      expect(despues.left, antes.left);
      expect(despues.width, antes.width);
      expect(despues.top, greaterThan(tester.getRect(_mas).bottom));
    });
  });

  group('DetalleBarraCompra en pantallas anchas', () {
    testWidgets('en un celular de 411 de ancho el botón sigue junto al '
        'total y la cantidad', (tester) async {
      await _montar(tester, pantalla: 411);

      final boton = tester.getRect(_boton);
      final mas = tester.getRect(_mas);
      expect(boton.left, greaterThan(mas.right));
      expect(boton.center.dy, moreOrLessEquals(mas.center.dy, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con la letra del sistema al 130 % el botón baja también en '
        'un celular de 411 de ancho', (tester) async {
      await _montar(tester, pantalla: 411, letra: 1.3);

      expect(find.text('Añadir'), findsOneWidget);
      final boton = tester.getRect(_boton);
      expect(boton.top, greaterThan(tester.getRect(_mas).bottom));
      expect(boton.width, moreOrLessEquals(_anchoPorDentro(411)));
    });
  });
}
