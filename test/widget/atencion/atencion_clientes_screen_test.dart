// test/widget/atencion/atencion_clientes_screen_test.dart — «Atención a
// clientes» (#138) sin red: el mostrador y gerencia la abren desde la
// agenda (producción no), cada pestaña carga lo suyo una vez y lo conserva,
// «Reintentar» cuando no carga, el aviso cuando jalar hacia abajo falla y
// la lista vacía.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/atencion/widgets/atencion_clientes_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';

import '../../fakes/atencion_json.dart';
import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_atencion.dart';
import '../../helpers/montar_comandas.dart';

const _asunto = 'Pan & café "frío"';

FakeApiClient _conAgenda() => backendAtencion()
  ..responder(ApiConstants.agendaComandas('proximas'), agendaJson([]));

void main() {
  group('AtencionClientesScreen', () {
    for (final rol in ['empleado', 'gerencia']) {
      testWidgets('$rol la abre desde la agenda', (tester) async {
        final api = _conAgenda();
        await montarComandas(
          tester,
          api,
          pantalla: const AgendaComandasScreen(),
          rol: rol,
        );

        await tester.tap(find.byTooltip('Atención a clientes'));
        await tester.pumpAndSettle();

        expect(find.byType(AtencionClientesScreen), findsOneWidget);
        expect(find.text(_asunto), findsOneWidget);
        expect(api.llamo(ApiConstants.quejasPersonal, metodo: 'GET-Auth'),
            isTrue);
        // Solo carga la pestaña que se ve.
        expect(api.llamo(ApiConstants.reembolsosPersonal), isFalse);
      });
    }

    testWidgets('producción no la ve', (tester) async {
      await montarComandas(
        tester,
        _conAgenda(),
        pantalla: const AgendaComandasScreen(),
      );

      expect(find.byTooltip('Atención a clientes'), findsNothing);
    });

    testWidgets('cada pestaña carga lo suyo una vez y lo conserva',
        (tester) async {
      final api = backendAtencion();
      await montarAtencion(tester, api);

      await irAPestana(tester, 'Reembolsos');
      expect(find.text('Pedido PIER-41'), findsOneWidget);
      await irAPestana(tester, 'Reseñas');
      expect(find.text('Muy esponjoso'), findsOneWidget);
      await irAPestana(tester, 'Reembolsos');
      await irAPestana(tester, 'Quejas');

      expect(find.text(_asunto), findsOneWidget);
      expect(cargasDe(api, ApiConstants.quejasPersonal), 1);
      expect(cargasDe(api, ApiConstants.reembolsosPersonal), 1);
      expect(cargasDe(api, ApiConstants.resenasPersonal), 1);
    });

    testWidgets('si no carga ofrece reintentar', (tester) async {
      final api = backendAtencion()
        ..fallar(ApiConstants.quejasPersonal, 'Sin conexión');
      await montarAtencion(tester, api);

      expect(find.text('Sin conexión'), findsOneWidget);
      api.responder(ApiConstants.quejasPersonal, quejasJson);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text(_asunto), findsOneWidget);
    });

    testWidgets('si jalar hacia abajo falla conserva la lista y avisa',
        (tester) async {
      final api = backendAtencion();
      await montarAtencion(tester, api);
      api.fallar(ApiConstants.quejasPersonal, 'Sin conexión');

      // Largo: la pantalla de prueba es muy alta.
      await tester.drag(find.byType(ListView), const Offset(0, 1200));
      await tester.pumpAndSettle();

      expect(cargasDe(api, ApiConstants.quejasPersonal), 2);
      expect(find.text(_asunto), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('una lista vacía lo dice', (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.resenasPersonal, {
          'success': true,
          'resenas': <Object>[],
        });
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reseñas');

      expect(find.text('No hay reseñas'), findsOneWidget);
    });
  });
}
