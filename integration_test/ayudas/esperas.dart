// integration_test/ayudas/esperas.dart — esperas por condición que comparten
// las pruebas de integración (#215). En el emulador el teclado y los
// diálogos se cierran con su propio ritmo (el del teclado es nativo y
// pumpAndSettle no lo espera): en vez de dar un tiempo fijo y confiar, se
// espera a que la condición se cumpla, con un límite. Y un toque que no llega
// a su widget hace fallar la prueba en ese paso, no más adelante.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un toque que cae en otro widget (p. ej. uno que todavía se está
/// cerrando) falla en el paso donde ocurre en lugar de solo avisar. Se
/// llama al inicio de cada archivo de integración.
void toquesPerdidosFallan() =>
    WidgetController.hitTestWarningShouldBeFatal = true;

/// Espera a que aparezca [buscado] dando cuadros con tiempo real: con el
/// servidor real no sirve pumpAndSettle (las animaciones de carga no paran).
Future<void> esperar(
  WidgetTester tester,
  Finder buscado, {
  Duration limite = const Duration(seconds: 30),
  String? motivo,
  bool obligatorio = true,
}) => esperarQue(
  tester,
  () => buscado.evaluate().isNotEmpty,
  limite: limite,
  motivo: motivo ?? 'no apareció $buscado',
  obligatorio: obligatorio,
);

/// Da cuadros cada 250 ms hasta que se cumpla [condicion] o pase [limite].
Future<void> esperarQue(
  WidgetTester tester,
  bool Function() condicion, {
  required String motivo,
  Duration limite = const Duration(seconds: 60),
  bool obligatorio = true,
}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condicion()) return;
  }
  if (obligatorio) fail('$motivo (${limite.inSeconds} s)');
}

/// Cierra el teclado y espera a que de verdad se haya ido (el borde inferior
/// de la vista vuelve a 0). Si se toca antes, el botón puede seguir tapado
/// y un SnackBar flotante no cabe («presented off screen», PR #214).
Future<void> cerrarTeclado(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await esperarQue(
    tester,
    () => tester.view.viewInsets.bottom == 0,
    motivo: 'el teclado no se cerró',
    limite: const Duration(seconds: 10),
  );
}

/// Espera a que ya no esté [dialogo] (p. ej. el selector de fecha), para
/// que el siguiente toque no caiga en él mientras se cierra.
Future<void> esperarQueSeCierre(WidgetTester tester, Finder dialogo) =>
    esperarQue(
      tester,
      () => dialogo.evaluate().isEmpty,
      motivo: 'no se cerró $dialogo',
      limite: const Duration(seconds: 10),
    );
