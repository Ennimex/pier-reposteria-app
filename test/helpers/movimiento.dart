// test/helpers/movimiento.dart — utilidades para probar el sistema de
// movimiento (lib/ui/core/ui/movimiento): montar una primitiva suelta, como
// la ven las pruebas de pantalla (MaterialApp sin AppTheme), y pedir
// «reducir movimiento» por las dos vías de AppMovimiento.reducido.
//
//   await montarMovimiento(tester, const EntradaSuave(child: Text('Hola')));
//   await montarMovimiento(tester, hijo, reducido: true); // Android
//   activarReducirMovimientoIos(tester);                   // iOS
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [hijo] centrado en un Scaffold dentro de un MaterialApp sin tema.
/// Con [reducido] llega «Quitar animaciones» de Android por MediaQuery.
Future<void> montarMovimiento(
  WidgetTester tester,
  Widget hijo, {
  bool reducido = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: reducido ? ConMovimientoReducido(child: hijo) : hijo,
        ),
      ),
    ),
  );
}

/// «Quitar animaciones» de Android: la bandera llega por MediaQuery.
class ConMovimientoReducido extends StatelessWidget {
  const ConMovimientoReducido({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  );
}

/// «Reducir movimiento» de iOS: solo vive en accessibilityFeatures (no llega
/// a MediaQuery) y no acelera los AnimationController.
void activarReducirMovimientoIos(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(reduceMotion: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Opacidad actual del primer FadeTransition dentro de [de].
double opacidadEn(WidgetTester tester, Finder de) => tester
    .widget<FadeTransition>(
      find.descendant(of: de, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

/// Escala actual del primer ScaleTransition dentro de [de].
double escalaEn(WidgetTester tester, Finder de) => tester
    .widget<ScaleTransition>(
      find.descendant(of: de, matching: find.byType(ScaleTransition)).first,
    )
    .scale
    .value;
