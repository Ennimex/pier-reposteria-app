// test/widget/actividad/actividad_equipo_screen_test.dart — «Actividad del
// equipo» (#139) sin red y con el reloj fijo: gerencia y dirección la abren
// desde la agenda (el mostrador y producción no la ven) y solo se pide la
// pestaña que se ve; la pestaña «Equipo» con sus cifras, el último acceso
// de cada persona, la cuenta inactiva, las entregas del repartidor, las
// zonas y los últimos movimientos; el mensaje del backend con
// «Reintentar», el aviso cuando jalar hacia abajo falla y el atajo a la
// bitácora completa.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/actividad/widgets/actividad_equipo_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';

import '../../fakes/actividad_json.dart';
import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_actividad.dart';
import '../../helpers/montar_comandas.dart';

FakeApiClient _conAgenda() => backendActividad()
  ..responder(ApiConstants.agendaComandas('proximas'), agendaJson([]));

void main() {
  group('ActividadEquipoScreen', () {
    for (final rol in ['gerencia', 'direccion_general']) {
      testWidgets('$rol la abre desde la agenda', (tester) async {
        final api = _conAgenda();
        await montarComandas(
          tester,
          api,
          pantalla: const AgendaComandasScreen(),
          rol: rol,
        );

        await tester.tap(find.byTooltip('Actividad del equipo'));
        await tester.pumpAndSettle();

        expect(find.byType(ActividadEquipoScreen), findsOneWidget);
        expect(find.text('Tu equipo'), findsOneWidget);
        expect(
          api.llamo(ApiConstants.actividadEquipo, metodo: 'GET-Auth'),
          isTrue,
        );
        // La bitácora se pide hasta que se abre su pestaña.
        expect(api.llamo(consultaBitacora()), isFalse);
      });
    }

    for (final rol in ['empleado', 'hornos']) {
      testWidgets('$rol no la ve', (tester) async {
        await montarComandas(
          tester,
          _conAgenda(),
          pantalla: const AgendaComandasScreen(),
          rol: rol,
        );

        expect(find.byTooltip('Actividad del equipo'), findsNothing);
      });
    }

    testWidgets('Equipo: cifras, personas, zonas y últimos movimientos',
        (tester) async {
      await montarActividad(tester, backendActividad());

      for (final texto in [
        'Cifras de la operación',
        'Clientes atendidos',
        '1,234',
        'Con pedido en los últimos 30 días',
        'Pedidos cerrados',
        '56',
        'Avisos de demora',
        'Enviados a clientes, en total',
        'Ana Ruiz',
        'Gerencia',
        'Último acceso: Hace 5 min',
        '12 movimientos',
        'Luis Pérez',
        'Repartidor',
        'Último acceso: Hace 3 h',
        '8 entregas · 2 en curso',
        'Rosa Díaz',
        'Decoración',
        'Último acceso: Hace 2 días',
        '1 movimiento',
        'Pedro Sol',
        'Último acceso: Nunca',
        '0 movimientos',
        'Zonas con más entregas',
        'San Juan & Anexas',
        'Norte',
        'Sin colonia',
        'Últimos movimientos del equipo',
        'Ana Ruiz · Aprobó reembolso',
        'Reembolso',
        'Pedido PIER-41 & cliente avisado',
        'Hace 30 min',
        'Sistema · Canceló pedido sin pago',
        'Hace 1 día',
      ]) {
        expect(find.text(texto), findsOneWidget, reason: texto);
      }
      // Solo la cuenta deshabilitada lleva la marca.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('miembro-5')),
          matching: find.text('Inactiva'),
        ),
        findsOneWidget,
      );
      expect(find.text('Inactiva'), findsOneWidget);
    });

    testWidgets('sin personal, zonas ni movimientos lo dice', (tester) async {
      final api = backendActividad()
        ..responder(ApiConstants.actividadEquipo, {'success': true});
      await montarActividad(tester, api);

      expect(find.text('Aún no hay personal registrado'), findsOneWidget);
      expect(find.text('Aún no hay entregas a domicilio'), findsOneWidget);
      expect(find.text('Aún no hay movimientos registrados'), findsOneWidget);
      // Sin cifras no se muestra su sección.
      expect(find.text('Cifras de la operación'), findsNothing);
    });

    testWidgets('si no carga muestra el mensaje del backend y reintenta',
        (tester) async {
      final api = backendActividad()
        ..fallar(
          ApiConstants.actividadEquipo,
          'Error al obtener la actividad del equipo',
        );
      await montarActividad(tester, api);

      expect(
        find.text('No pudimos cargar la actividad del equipo'),
        findsOneWidget,
      );
      expect(
        find.text('Error al obtener la actividad del equipo'),
        findsOneWidget,
      );

      api.responder(ApiConstants.actividadEquipo, actividadJson);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Tu equipo'), findsOneWidget);
    });

    testWidgets('si jalar hacia abajo falla conserva lo cargado y avisa',
        (tester) async {
      final api = backendActividad();
      await montarActividad(tester, api);
      api.fallar(ApiConstants.actividadEquipo, 'Sin conexión');

      // Largo: la pantalla de prueba es muy alta.
      await tester.drag(listaDe('equipo'), const Offset(0, 1200));
      await tester.pumpAndSettle();

      expect(consultasDe(api, ApiConstants.actividadEquipo), 2);
      expect(find.text('Tu equipo'), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('el atajo abre la bitácora completa', (tester) async {
      final api = backendActividad();
      await montarActividad(tester, api);

      await tester.tap(find.text('Ver la bitácora completa'));
      await tester.pumpAndSettle();

      expect(api.llamo(consultaBitacora(), metodo: 'GET-Auth'), isTrue);
      expect(find.text('Cambió el estado del pedido'), findsOneWidget);
    });
  });
}
