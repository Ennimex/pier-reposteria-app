// test/widget/core/movimiento/entrada_suave_test.dart — EntradaSuave entra
// una sola vez (fundido + subida en dp), en cascada, se puede tocar desde el
// primer cuadro, espera a verse si su pestaña está oculta y respeta
// «reducir movimiento»; AmbitoEntradas anima cada id una sola vez.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

Finder _entrada(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.byType(EntradaSuave));

double _opacidad(WidgetTester tester, String texto) =>
    opacidadEn(tester, _entrada(texto));

/// Cuánto está corrido el texto respecto a su lugar (solo se pinta movido:
/// la caja de EntradaSuave no se mueve).
Offset _corrimiento(WidgetTester tester, String texto) =>
    tester.getCenter(find.text(texto)) - tester.getCenter(_entrada(texto));

/// Lista con su ámbito; cada elemento lleva su id y una Key estable. La
/// columna cambia de Key con la generación (como un filtro nuevo).
class _Lista extends StatelessWidget {
  const _Lista({
    required this.ids,
    this.generacion,
    this.soloPrimeraTanda = true,
  });

  final List<String> ids;
  final Object? generacion;
  final bool soloPrimeraTanda;

  @override
  Widget build(BuildContext context) => AmbitoEntradas(
    generacion: generacion,
    soloPrimeraTanda: soloPrimeraTanda,
    child: Column(
      key: ValueKey(generacion),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in ids)
          EntradaSuave(key: ValueKey(id), id: id, child: Text(id)),
      ],
    ),
  );
}

void main() {
  group('EntradaSuave', () {
    testWidgets('arranca transparente y abajo, y se asienta en su lugar', (
      tester,
    ) async {
      await montarMovimiento(tester, const EntradaSuave(child: Text('Hola')));

      expect(_opacidad(tester, 'Hola'), 0);
      expect(
        _corrimiento(tester, 'Hola').dy,
        closeTo(AppMovimiento.distancia, 0.01),
      );
      await tester.pump(); // primer tick (arrancó en un post-frame)
      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacidad(tester, 'Hola'), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_opacidad(tester, 'Hola'), 1);
      expect(_corrimiento(tester, 'Hola'), Offset.zero);
    });

    testWidgets('se puede tocar desde el primer cuadro', (tester) async {
      var toques = 0;
      await montarMovimiento(
        tester,
        EntradaSuave(
          child: ElevatedButton(
            onPressed: () => toques++,
            child: const Text('Pedir'),
          ),
        ),
      );

      await tester.tap(find.text('Pedir'));
      await tester.pump();
      expect(toques, 1);
    });

    testWidgets('en cascada cada escalón espera su turno', (tester) async {
      await montarMovimiento(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EntradaSuave(child: Text('Primero')),
            EntradaSuave(orden: 4, child: Text('Quinto')),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(_opacidad(tester, 'Primero'), greaterThan(0));
      expect(_opacidad(tester, 'Quinto'), 0); // su turno llega a los 200 ms
      await tester.pump(const Duration(milliseconds: 500));
      expect(_opacidad(tester, 'Quinto'), 1);
    });

    testWidgets('respeta el retraso, la escala inicial y el desplazamiento', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const EntradaSuave(
          retraso: AppMovimiento.trasEmpuje,
          escalaInicial: 0.9,
          desplazamiento: Offset(AppMovimiento.distanciaLarga, 0),
          child: Text('Lado'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacidad(tester, 'Lado'), 0); // aún en el retraso
      expect(_corrimiento(tester, 'Lado').dx, closeTo(24, 0.01));
      final escalas = tester
          .widgetList<Transform>(
            find.descendant(
              of: _entrada('Lado'),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.entry(0, 0));
      expect(escalas, anyElement(closeTo(0.9, 0.001)));

      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, 'Lado'), 1);
      expect(_corrimiento(tester, 'Lado'), Offset.zero);
    });

    testWidgets('no se repite al reconstruir', (tester) async {
      await montarMovimiento(tester, const EntradaSuave(child: Text('Uno')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacidad(tester, 'Uno'), 1);

      await montarMovimiento(tester, const EntradaSuave(child: Text('Dos')));
      expect(_opacidad(tester, 'Dos'), 1);
    });

    testWidgets('animar en falso aparece ya en su lugar', (tester) async {
      await montarMovimiento(
        tester,
        const EntradaSuave(animar: false, child: Text('Quieto')),
      );
      expect(_opacidad(tester, 'Quieto'), 1);
      expect(_corrimiento(tester, 'Quieto'), Offset.zero);
    });

    testWidgets('una duración cero no anima', (tester) async {
      await montarMovimiento(
        tester,
        const EntradaSuave(duracion: Duration.zero, child: Text('Ya')),
      );
      expect(_opacidad(tester, 'Ya'), 1);
    });

    testWidgets('con «Quitar animaciones» aparece ya en su lugar', (
      tester,
    ) async {
      await montarMovimiento(
        tester,
        const EntradaSuave(child: Text('Hola')),
        reducido: true,
      );
      expect(_opacidad(tester, 'Hola'), 1);
      expect(_corrimiento(tester, 'Hola'), Offset.zero);
    });

    testWidgets('con «Reducir movimiento» de iOS aparece ya en su lugar', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await montarMovimiento(tester, const EntradaSuave(child: Text('Hola')));
      expect(_opacidad(tester, 'Hola'), 1);
    });

    testWidgets('en una pestaña oculta espera a mostrarse', (tester) async {
      var visible = false;
      late StateSetter cambiar;
      await montarMovimiento(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            cambiar = setState;
            return TickerMode(
              enabled: visible,
              child: const EntradaSuave(child: Text('Oculta')),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_opacidad(tester, 'Oculta'), 0); // no gastó la entrada oculta

      // Al mostrarse: un cuadro reactiva el ticker, el siguiente es su
      // primer tick (ahí empieza a contar) y después avanza.
      cambiar(() => visible = true);
      await tester.pump();
      await tester.pump();
      expect(_opacidad(tester, 'Oculta'), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacidad(tester, 'Oculta'), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacidad(tester, 'Oculta'), 1);
    });
  });

  group('AmbitoEntradas', () {
    testWidgets('la primera tanda entra en cascada', (tester) async {
      await montarMovimiento(tester, const _Lista(ids: ['a', 'b', 'c', 'd']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(_opacidad(tester, 'a'), greaterThan(_opacidad(tester, 'd')));
      await tester.pump(const Duration(milliseconds: 600));
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(_opacidad(tester, id), 1);
      }
    });

    testWidgets('un id que ya entró no se repite al volver', (tester) async {
      await montarMovimiento(tester, const _Lista(ids: ['a', 'b']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Como al hacer scroll: «b» sale del árbol y luego vuelve.
      await montarMovimiento(tester, const _Lista(ids: ['a']));
      expect(find.text('b'), findsNothing);
      await montarMovimiento(tester, const _Lista(ids: ['a', 'b']));
      expect(_opacidad(tester, 'b'), 1);
    });

    testWidgets('lo que llega después de la primera tanda llega quieto', (
      tester,
    ) async {
      await montarMovimiento(tester, const _Lista(ids: ['a']));
      await tester.pump();
      await montarMovimiento(tester, const _Lista(ids: ['a', 'nuevo']));
      expect(_opacidad(tester, 'nuevo'), 1);
    });

    testWidgets('sin soloPrimeraTanda cada tanda nueva entra', (tester) async {
      await montarMovimiento(
        tester,
        const _Lista(ids: ['a'], soloPrimeraTanda: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await montarMovimiento(
        tester,
        const _Lista(ids: ['a', 'nuevo'], soloPrimeraTanda: false),
      );
      expect(_opacidad(tester, 'a'), 1);
      expect(_opacidad(tester, 'nuevo'), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, 'nuevo'), 1);
    });

    testWidgets('una generación nueva vuelve a animar lo ya visto', (
      tester,
    ) async {
      await montarMovimiento(tester, const _Lista(ids: ['a'], generacion: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, 'a'), 1);

      await montarMovimiento(tester, const _Lista(ids: ['a'], generacion: 2));
      expect(_opacidad(tester, 'a'), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_opacidad(tester, 'a'), 1);
    });

    testWidgets('sin ámbito, un id no cambia nada', (tester) async {
      await montarMovimiento(
        tester,
        const EntradaSuave(id: 'suelto', child: Text('Suelto')),
      );
      expect(_opacidad(tester, 'Suelto'), 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacidad(tester, 'Suelto'), 1);
    });
  });
}
