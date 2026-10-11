// test/widget/core/movimiento/icono_pestana_test.dart — IconoPestana: al
// montarse (al elegir la pestaña) crece una píldora detrás del ícono y el
// ícono da un pop; la píldora se pinta fuera de su caja, así que en la barra
// inferior las etiquetas no se mueven; con «reducir movimiento» aparece ya
// completo.
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
}
