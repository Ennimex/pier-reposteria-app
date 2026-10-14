// test/widget/core/movimiento/icono_pestana_test.dart — IconoPestana: al
// montarse elegido (o al elegir la pestaña) crece una píldora detrás del
// ícono y el ícono da un pop; en las dos ranuras de la barra conserva su
// estado y al dejar la pestaña la píldora se encoge y se apaga; la píldora
// se pinta fuera de su caja, así que las etiquetas no se mueven; con
// «reducir movimiento» cambia al instante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Finder get _pildora => find.descendant(
  of: find.byType(IconoPestana),
  matching: find.byType(DecoratedBox),
);

/// Barra con dos pestañas; `animado` decide si el ícono activo es el animado.
Widget _barra({required int indice, required bool animado}) => MaterialApp(
  home: Scaffold(
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: indice,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          activeIcon: animado
              ? const IconoPestana(Icons.home)
              : const Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.store),
          activeIcon: animado
              ? const IconoPestana(Icons.store)
              : const Icon(Icons.store),
          label: 'Catálogo',
        ),
      ],
    ),
  ),
);

/// Barra con IconoPestana en las dos ranuras de cada pestaña (como
/// MainScreen): la barra pone una u otra en el mismo lugar.
Widget _barraDoble({required int indice, bool reducido = false}) {
  final barra = BottomNavigationBar(
    currentIndex: indice,
    type: BottomNavigationBarType.fixed,
    items: const [
      BottomNavigationBarItem(
        icon: IconoPestana(Icons.home, activo: false),
        activeIcon: IconoPestana(Icons.home),
        label: 'Inicio',
      ),
      BottomNavigationBarItem(
        icon: IconoPestana(Icons.store, activo: false),
        activeIcon: IconoPestana(Icons.store),
        label: 'Catálogo',
      ),
    ],
  );
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: reducido
          ? ConMovimientoReducido(child: barra)
          : barra,
    ),
  );
}

Finder _icono(IconData icono) =>
    find.byWidgetPredicate((w) => w is IconoPestana && w.icono == icono);

Finder _pildoraDe(IconData icono) =>
    find.descendant(of: _icono(icono), matching: find.byType(DecoratedBox));

void main() {
  testWidgets('al montarse crece la píldora y el ícono da un pop', (
    tester,
  ) async {
    await montarMovimiento(tester, const IconoPestana(Icons.home));

    final iconoTile = find.byType(IconoPestana);
    expect(escalaEn(tester, iconoTile), lessThan(1));
    final anchoInicial = tester.getSize(_pildora).width;

    await tester.pump(AppMovimiento.media);
    expect(escalaEn(tester, iconoTile), 1);
    expect(tester.getSize(_pildora).width, greaterThan(anchoInicial));
    expect(tester.getSize(_pildora), const Size(52, 28));
    // La caja del ícono no crece: la píldora se pinta afuera.
    expect(tester.getSize(iconoTile), const Size(24, 24));
  });

  testWidgets('con movimiento reducido aparece ya completo', (tester) async {
    await montarMovimiento(
      tester,
      const IconoPestana(Icons.home),
      reducido: true,
    );
    expect(escalaEn(tester, find.byType(IconoPestana)), 1);
    expect(tester.getSize(_pildora), const Size(52, 28));
  });

  testWidgets('la píldora toma el color del ícono de la barra', (tester) async {
    await montarMovimiento(
      tester,
      const IconTheme(
        data: IconThemeData(color: Colors.green, size: 24),
        child: IconoPestana(Icons.home),
      ),
    );
    await tester.pump(AppMovimiento.media);
    final decoracion =
        tester.widget<DecoratedBox>(_pildora).decoration as BoxDecoration;
    expect(decoracion.color, Colors.green.withValues(alpha: 0.14));
  });

  testWidgets('en la barra no mueve las etiquetas y se anima al elegir', (
    tester,
  ) async {
    await tester.pumpWidget(_barra(indice: 0, animado: false));
    final sinAnimar = tester.getRect(find.text('Catálogo'));

    await tester.pumpWidget(_barra(indice: 0, animado: true));
    await tester.pump(AppMovimiento.media);
    expect(tester.getRect(find.text('Catálogo')), sinAnimar);
    expect(find.byType(IconoPestana), findsOneWidget);

    // Elegir otra pestaña monta su IconoPestana y vuelve a animar.
    await tester.pumpWidget(_barra(indice: 1, animado: true));
    final nuevo = find.byType(IconoPestana);
    expect(tester.widget<IconoPestana>(nuevo).icono, Icons.store);
    expect(escalaEn(tester, nuevo), lessThan(1));
    await tester.pump(AppMovimiento.media);
    expect(escalaEn(tester, nuevo), 1);
  });

  testWidgets('en las dos ranuras la píldora de la pestaña que se deja se '
      'encoge y se apaga', (tester) async {
    await tester.pumpWidget(_barra(indice: 0, animado: false));
    final sinAnimar = tester.getRect(find.text('Catálogo'));

    await tester.pumpWidget(_barraDoble(indice: 0));
    await tester.pump(AppMovimiento.media);
    expect(tester.getRect(find.text('Catálogo')), sinAnimar);
    expect(tester.getSize(_pildoraDe(Icons.home)), const Size(52, 28));
    expect(opacidadEn(tester, _icono(Icons.home)), 1);
    // La pestaña sin elegir no tiene píldora y su ícono no se ve encogido.
    expect(opacidadEn(tester, _icono(Icons.store)), 0);
    expect(escalaEn(tester, _icono(Icons.store)), 1);
    final estadoInicio = tester.state(_icono(Icons.home));

    await tester.pumpWidget(_barraDoble(indice: 1));
    // Es el mismo estado (no se desmonta): por eso puede animar la salida.
    expect(tester.state(_icono(Icons.home)), same(estadoInicio));
    expect(escalaEn(tester, _icono(Icons.store)), lessThan(1)); // su pop

    await tester.pump(const Duration(milliseconds: 165));
    expect(
      tester.getSize(_pildoraDe(Icons.home)).width,
      inExclusiveRange(24, 52),
    );
    expect(opacidadEn(tester, _icono(Icons.home)), inExclusiveRange(0, 1));
    expect(escalaEn(tester, _icono(Icons.home)), 1); // sin pop al dejarla

    await tester.pump(AppMovimiento.media);
    expect(opacidadEn(tester, _icono(Icons.home)), 0);
    expect(tester.getSize(_pildoraDe(Icons.home)).width, 24);
    expect(opacidadEn(tester, _icono(Icons.store)), 1);
    expect(tester.getSize(_pildoraDe(Icons.store)), const Size(52, 28));
    expect(escalaEn(tester, _icono(Icons.store)), 1);
  });

  testWidgets('en las dos ranuras con movimiento reducido cambia al instante', (
    tester,
  ) async {
    await tester.pumpWidget(_barraDoble(indice: 0, reducido: true));
    expect(tester.getSize(_pildoraDe(Icons.home)), const Size(52, 28));
    expect(opacidadEn(tester, _icono(Icons.store)), 0);

    await tester.pumpWidget(_barraDoble(indice: 1, reducido: true));
    await tester.pump();
    expect(opacidadEn(tester, _icono(Icons.home)), 0);
    expect(opacidadEn(tester, _icono(Icons.store)), 1);
    expect(tester.getSize(_pildoraDe(Icons.store)), const Size(52, 28));
    expect(escalaEn(tester, _icono(Icons.store)), 1);
  });
}
