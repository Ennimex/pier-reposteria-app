// test/widget/roles/panel_web_screen_test.dart — aviso de panel web para los
// roles internos: cada rol ve su propio panel (#126: hornos y decoración ven
// el de Producción en lugar de caer en la tienda).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/roles/widgets/panel_web_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// Monta el aviso con una sesión abierta del [rol] dado.
Future<void> _montarCon(WidgetTester tester, String rol) async {
  await tester.pumpApp(const PanelWebScreen());
  tester
      .element(find.byType(PanelWebScreen))
      .read<AuthProvider>()
      .abrirSesion({'id': 1, 'nombre': 'Rosa Pérez', 'rol': rol});
  await tester.pump();
}

void main() {
  group('PanelWebScreen', () {
    final paneles = {
      'empleado': 'Panel de Operación',
      'gerencia': 'Panel de Gerencia',
      'direccion_general': 'Panel de Dirección',
      'hornos': 'Panel de Producción',
      'decoracion': 'Panel de Producción',
    };
    for (final MapEntry(key: rol, value: panel) in paneles.entries) {
      testWidgets('$rol ve el $panel', (tester) async {
        await _montarCon(tester, rol);

        expect(find.text('¡Hola, Rosa!'), findsOneWidget);
        expect(find.text(panel), findsOneWidget);
        expect(find.text('Abrir sitio web'), findsOneWidget);
      });
    }

    testWidgets('producción ve la descripción de comandas', (tester) async {
      await _montarCon(tester, 'hornos');

      expect(find.textContaining('comandas'), findsOneWidget);
    });
  });
}
