// test/widget/core/movimiento/entrada_dialogo_test.dart — EntradaDialogo
// hace crecer el diálogo de 0.92 a 1 con la animación de su ruta (junto con
// AppMovimiento.estiloDialogo), no escala con «reducir movimiento» y no
// falla fuera de una ruta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

import '../../../helpers/movimiento.dart';

/// Pantalla con un botón que abre un diálogo de Pier.
class _ConDialogo extends StatelessWidget {
  const _ConDialogo();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (_) => const EntradaDialogo(
        child: AlertDialog(title: Text('¿Cerrar sesión?')),
      ),
    ).ignore(),
    child: const Text('Abrir'),
  );
}

double _escala(WidgetTester tester) =>
    escalaEn(tester, find.byType(EntradaDialogo));

void main() {
  testWidgets('el diálogo crece de 0.92 a 1 mientras aparece', (tester) async {
    await montarMovimiento(tester, const _ConDialogo());
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    expect(_escala(tester), closeTo(0.92, 0.001));

    await tester.pump(const Duration(milliseconds: 80));
    expect(_escala(tester), inExclusiveRange(0.92, 1));

    // estiloDialogo: el diálogo termina de entrar en 220 ms.
    await tester.pump(const Duration(milliseconds: 160));
    expect(_escala(tester), 1);
    expect(
      ModalRoute.of(
        tester.element(find.text('¿Cerrar sesión?')),
      )!.animation!.isCompleted,
      isTrue,
    );
  });

  testWidgets('con movimiento reducido no escala', (tester) async {
    // La bandera de la plataforma: el diálogo vive en el Navigator raíz y no
    // hereda un MediaQuery puesto solo alrededor del botón.
    activarReducirMovimientoIos(tester);
    await montarMovimiento(tester, const _ConDialogo());
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    expect(_escala(tester), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('fuera de una ruta no falla', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: EntradaDialogo(child: Text('Suelto')),
      ),
    );
    expect(_escala(tester), 1);
  });
}
