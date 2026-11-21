// test/widget/products/producto_catalogo_card_test.dart — la tarjeta del
// catálogo cabe en su celda en pantallas angostas y con la letra del sistema
// grande (#362). La celda mide lo que le da la pantalla (su ancho entre una
// proporción), no lo que mide el texto: en un celular de 360 de ancho la
// cuadrícula se desbordaba 9.1 px y la lista, 5.5 px (visto en Firebase Test
// Lab, #81).
@Tags(['regresion'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/state/product_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_theme.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// Larga: en lista ocupa dos renglones en cualquier pantalla.
const _descripcion =
    'Pastel de chocolate con flan napolitano y cajeta, para diez personas';

final Product _producto = Product.fromJson({
  'id': 7,
  'nombre': 'Chocoflan',
  'descripcion': _descripcion,
  'precio_chico': 350,
  'categoria': 'Pasteles',
  'imagen_url': '',
  'activo': true,
  'rating': 4.5,
});

/// El margen del catálogo a cada lado y la separación entre sus tarjetas
/// (products_screen.dart).
const double _margen = 16;
const double _separacion = 12;

/// La celda del catálogo en un celular de [pantalla] de ancho con la letra
/// del sistema a [letra].
Size _celda(double pantalla, {required bool cuadricula, double letra = 1}) {
  final ancho = cuadricula
      ? (pantalla - 2 * _margen - _separacion) / 2
      : pantalla - 2 * _margen;
  final proporcion = ProductoCatalogoCard.proporcionDeLaCelda(
    enCuadricula: cuadricula,
    letra: TextScaler.linear(letra),
  );
  return Size(ancho, ancho / proporcion);
}

/// Monta la tarjeta en la celda que le toca en un celular de [pantalla] de
/// ancho, con la letra del sistema a [letra], y devuelve esa celda. Va con el
/// tema de la app: de su interlineado sale lo que mide el texto.
Future<Size> _montar(
  WidgetTester tester, {
  required double pantalla,
  required bool cuadricula,
  double letra = 1,
}) async {
  tester.view
    ..physicalSize = Size(pantalla, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final celda = _celda(pantalla, cuadricula: cuadricula, letra: letra);
  await tester.pumpApp(
    Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: celda,
              child: ProductoCatalogoCard(
                producto: _producto,
                promociones: context.read<ProductProvider>(),
                enCuadricula: cuadricula,
                esFavorito: false,
                onTap: () {},
                onToggleFavorito: () {},
                onAgregar: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return celda;
}

/// Pantallas (ancho) con la letra del sistema agrandada.
const List<(double, double)> _conLetraGrande = [
  (320, 1.3),
  (360, 1.3),
  (360, 1.5),
  (411, 1.3),
  (411, 2),
];

void main() {
  group('ProductoCatalogoCard cabe en su celda (#362)', () {
    for (final cuadricula in [true, false]) {
      final modo = cuadricula ? 'cuadrícula' : 'lista';

      for (final pantalla in <double>[320, 360, 384, 411]) {
        testWidgets('en $modo, en un celular de ${pantalla.round()} de ancho',
            (tester) async {
          await _montar(tester, pantalla: pantalla, cuadricula: cuadricula);

          expect(tester.takeException(), isNull);
        });
      }

      for (final (pantalla, letra) in _conLetraGrande) {
        testWidgets('en $modo, en un celular de ${pantalla.round()} de ancho '
            'con la letra del sistema al ${(letra * 100).round()} %',
            (tester) async {
          await _montar(
            tester,
            pantalla: pantalla,
            cuadricula: cuadricula,
            letra: letra,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('ProductoCatalogoCard.proporcionDeLaCelda', () {
    double proporcion({required bool cuadricula, required double letra}) =>
        ProductoCatalogoCard.proporcionDeLaCelda(
          enCuadricula: cuadricula,
          letra: TextScaler.linear(letra),
        );

    test('en cuadrícula no depende de la letra: la foto cede su lugar', () {
      expect(proporcion(cuadricula: true, letra: 1), 0.63);
      expect(proporcion(cuadricula: true, letra: 2), 0.63);
    });

    test('en lista la celda crece con la letra del sistema', () {
      expect(proporcion(cuadricula: false, letra: 1), 3.2);
      expect(
        proporcion(cuadricula: false, letra: 1.5),
        moreOrLessEquals(3.2 / 1.5),
      );
    });

    test('en lista la celda no se encoge con la letra chica', () {
      expect(proporcion(cuadricula: false, letra: 0.85), 3.2);
    });
  });

  group('ProductoCatalogoCard en cuadrícula', () {
    testWidgets('donde el texto cabe, la foto ocupa el 55 % de la celda',
        (tester) async {
      final celda = await _montar(tester, pantalla: 411, cuadricula: true);

      expect(
        tester.getSize(find.byType(FotoDeTarjeta)).height,
        moreOrLessEquals(celda.height * 0.55, epsilon: 0.01),
      );
    });

    testWidgets('en un celular de 360 de ancho la foto cede y el botón de '
        'agregar queda dentro de la tarjeta', (tester) async {
      final celda = await _montar(tester, pantalla: 360, cuadricula: true);

      expect(
        tester.getSize(find.byType(FotoDeTarjeta)).height,
        lessThan(celda.height * 0.55),
      );
      final tarjeta = tester.getRect(find.byType(ProductoCatalogoCard));
      final boton = tester.getRect(find.ancestor(
        of: find.byIcon(LucideIcons.plus),
        matching: find.byType(AnimatedContainer),
      ));
      // Con su margen de 8 abajo, como en las pantallas anchas.
      expect(boton.bottom, lessThanOrEqualTo(tarjeta.bottom - 8 + 0.01));
    });
  });

  group('ProductoCatalogoCard en lista', () {
    int? renglones(WidgetTester tester) =>
        tester.widget<Text>(find.text(_descripcion)).maxLines;

    testWidgets('donde caben, la descripción ocupa dos renglones',
        (tester) async {
      await _montar(tester, pantalla: 411, cuadricula: false);

      expect(renglones(tester), 2);
    });

    testWidgets('en un celular de 360 de ancho la descripción ocupa un '
        'renglón', (tester) async {
      await _montar(tester, pantalla: 360, cuadricula: false);

      expect(renglones(tester), 1);
    });

    testWidgets('en un celular de 320 de ancho no cabe la descripción y lo '
        'demás sigue', (tester) async {
      await _montar(tester, pantalla: 320, cuadricula: false);

      expect(find.text(_descripcion), findsNothing);
      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.text(r'$350'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
