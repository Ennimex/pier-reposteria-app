// test/widget/core/movimiento/app_movimiento_test.dart — los tokens de
// movimiento: la regla de «reducir movimiento» (Android e iOS), los
// ayudantes de duración y cascada, los estilos de diálogo, hoja y
// desplegable, y el pulso de los botones «agregar».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Monta un Builder y devuelve su contexto (dentro de MaterialApp).
Future<BuildContext> _contexto(
  WidgetTester tester, {
  bool reducido = false,
}) async {
  late BuildContext contexto;
  await montarMovimiento(
    tester,
    Builder(
      builder: (context) {
        contexto = context;
        return const SizedBox();
      },
    ),
    reducido: reducido,
  );
  return contexto;
}

void main() {
  group('AppMovimiento.reducido', () {
    testWidgets('sin banderas el movimiento es normal', (tester) async {
      final contexto = await _contexto(tester);
      expect(AppMovimiento.reducido(contexto), isFalse);
    });

    testWidgets('«Quitar animaciones» de Android (MediaQuery) lo reduce', (
      tester,
    ) async {
      final contexto = await _contexto(tester, reducido: true);
      expect(AppMovimiento.reducido(contexto), isTrue);
    });

    testWidgets(
      '«Reducir movimiento» de iOS (accessibilityFeatures) lo reduce',
      (tester) async {
        activarReducirMovimientoIos(tester);
        final contexto = await _contexto(tester);
        expect(MediaQuery.disableAnimationsOf(contexto), isFalse);
        expect(AppMovimiento.reducido(contexto), isTrue);
      },
    );

    testWidgets('sin MediaQuery usa la bandera de la plataforma', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      late BuildContext contexto;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            contexto = context;
            return const SizedBox();
          },
        ),
      );
      expect(AppMovimiento.reducido(contexto), isTrue);
    });
  });

  group('Ayudantes de tiempo', () {
    testWidgets('duracion se vuelve cero con movimiento reducido', (
      tester,
    ) async {
      final normal = await _contexto(tester);
      expect(
        AppMovimiento.duracion(normal, AppMovimiento.media),
        AppMovimiento.media,
      );
      final reducido = await _contexto(tester, reducido: true);
      expect(
        AppMovimiento.duracion(reducido, AppMovimiento.media),
        Duration.zero,
      );
    });

    test('la cascada da 50 ms por escalón y se acota a 6 escalones', () {
      expect(AppMovimiento.retrasoCascada(0), Duration.zero);
      expect(
        AppMovimiento.retrasoCascada(3),
        const Duration(milliseconds: 150),
      );
      expect(
        AppMovimiento.retrasoCascada(20),
        const Duration(milliseconds: 300),
      );
      expect(AppMovimiento.retrasoCascada(-2), Duration.zero);
    });

    test('el contenido espera a que su pestaña o su página raíz se vea', () {
      // La pestaña que entra es transparente hasta el 30 % de media y
      // paginaRaiz hasta el 30 % de raiz; el push no tapa su contenido.
      expect(AppMovimiento.trasPestana, AppMovimiento.media * 0.3);
      expect(
        AppMovimiento.trasRaiz,
        greaterThanOrEqualTo(AppMovimiento.raiz * 0.3),
      );
      expect(AppMovimiento.trasRaiz, lessThan(AppMovimiento.raiz * 0.4));
      expect(AppMovimiento.trasEmpuje, lessThan(AppMovimiento.empuje));
    });

    test('las duraciones caben en los presupuestos de las pruebas', () {
      // Pestañas ≤ 300 ms, rutas raíz ≤ 400 ms, montos ≤ 450 ms,
      // celebraciones ≤ 1.6 s.
      expect(AppMovimiento.media.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppMovimiento.raiz.inMilliseconds, lessThanOrEqualTo(400));
      expect(AppMovimiento.conteo.inMilliseconds, lessThanOrEqualTo(450));
      expect(
        AppMovimiento.celebracion.inMilliseconds,
        lessThanOrEqualTo(1600),
      );
    });
  });

  group('Estilos de diálogo, hoja y desplegable', () {
    testWidgets('con movimiento normal usan las curvas de Pier', (
      tester,
    ) async {
      final contexto = await _contexto(tester);

      final dialogo = AppMovimiento.estiloDialogo(contexto);
      expect(dialogo.duration, AppMovimiento.corta);
      expect(dialogo.curve, AppMovimiento.curvaEnfasis);
      expect(dialogo.reverseCurve, AppMovimiento.curvaEnfasisSalida);

      final hoja = AppMovimiento.estiloHoja(contexto);
      expect(hoja.duration, const Duration(milliseconds: 320));
      expect(hoja.reverseDuration, AppMovimiento.corta);
      expect(hoja.curve, AppMovimiento.curvaEnfasis);

      final expansion = AppMovimiento.estiloExpansion(contexto);
      expect(expansion.duration, const Duration(milliseconds: 280));
    });

    testWidgets('con movimiento reducido quitan el desplazamiento', (
      tester,
    ) async {
      final contexto = await _contexto(tester, reducido: true);

      final dialogo = AppMovimiento.estiloDialogo(contexto);
      expect(dialogo.duration, AppMovimiento.rapida);
      expect(dialogo.curve, isNull);
      expect(AppMovimiento.estiloHoja(contexto), AnimationStyle.noAnimation);
      expect(
        AppMovimiento.estiloExpansion(contexto),
        AnimationStyle.noAnimation,
      );
    });
  });

  test('el pulso hunde, rebota y siempre termina en 1', () {
    final pulso = AppMovimiento.pulso;
    expect(pulso.transform(0), 1);
    expect(pulso.transform(0.15), lessThan(1));
    expect(pulso.transform(0.5), greaterThan(1));
    expect(pulso.transform(1), closeTo(1, 1e-9));
  });

  test('la curva de salida acelera al reproducirse hacia atrás', () {
    // Como reverseCurve, el valor va de 1 a 0: al principio cambia poco
    // (arranca lento) y al final mucho (sale rápido).
    const curva = AppMovimiento.curvaEnfasisSalida;
    final alInicio = 1 - curva.transform(0.9);
    final alFinal = curva.transform(0.1);
    expect(alInicio, lessThan(alFinal));
  });
}
