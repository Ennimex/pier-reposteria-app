// test/helpers/pantalla_apretada.dart — un celular donde el contenido ya no
// cabe en lo que queda de pantalla (#285): acostado, con la letra del
// sistema grande o con el teclado abierto. Sirve para comprobar que un
// estado vacío no se desborda y que lo de abajo se alcanza desplazándose.
//
//   for (final apreton in Apreton.values) {
//     testWidgets('cabe ${apreton.descripcion}', (tester) async {
//       await _montar(tester);            // como en las demás pruebas
//       await tester.apretar(apreton);    // y luego se acaba el espacio
//       await tester.alcanzar(find.text('Reintentar'));
//     });
//   }
//
// Los celulares van acostados: la letra de las pruebas (FlutterTest) dibuja
// cada letra tan ancha como alta, casi el doble que las de la app, y de pie
// los encabezados se desbordarían a lo ancho. Acostados conservan el ancho y
// se quedan con poca altura, que es lo que corta un estado vacío.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las formas en que se acaba la altura de una pantalla.
enum Apreton {
  /// Un celular de 360×640 lógicos acostado.
  acostado('con el celular acostado', Size(640, 360)),

  /// El Note 10+ acostado (869×412) con la letra del sistema al 150 %; con
  /// la letra normal el estado vacío de Opiniones sí cabe.
  letraGrande('con la letra grande', Size(869, 412), escalaTexto: 1.5),

  /// El Note 10+ acostado con el teclado abierto.
  tecladoAbierto('con el teclado abierto', Size(869, 412), teclado: 180);

  const Apreton(
    this.descripcion,
    this.tamano, {
    this.escalaTexto = 1,
    this.teclado = 0,
  });

  /// Cómo se nombra en las pruebas: «… se alcanza con el celular acostado».
  final String descripcion;

  /// Tamaño de la pantalla en píxeles lógicos.
  final Size tamano;

  /// Escala de la letra del sistema (accesibilidad).
  final double escalaTexto;

  /// Alto del teclado en píxeles lógicos (0: cerrado).
  final double teclado;
}

/// La lista principal de la pantalla (el buscador también es un
/// Scrollable, pero horizontal, como las categorías del catálogo).
final Finder _listaVertical = find.byWidgetPredicate((widget) =>
    widget is Scrollable &&
    axisDirectionToAxis(widget.axisDirection) == Axis.vertical);

extension PantallaApretada on WidgetTester {
  /// Deja la pantalla como dice [apreton] (todo vuelve a su estado al
  /// terminar la prueba) y espera a que se acomode.
  Future<void> apretar(Apreton apreton) async {
    view
      ..devicePixelRatio = 1
      ..physicalSize = apreton.tamano
      ..viewInsets = FakeViewPadding(bottom: apreton.teclado);
    addTearDown(view.reset);
    platformDispatcher.textScaleFactorTestValue = apreton.escalaTexto;
    addTearDown(platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAndSettle();
  }

  /// Nada se desbordó (ningún «A RenderFlex overflowed») y [destino] se
  /// puede tocar, si hace falta desplazando la lista hasta él.
  Future<void> alcanzar(Finder destino) async {
    expect(takeException(), isNull, reason: 'el contenido se desbordó');
    await scrollUntilVisible(destino, 100, scrollable: _listaVertical);
    await pumpAndSettle();
    expect(destino.hitTestable(), findsOneWidget);
  }
}
