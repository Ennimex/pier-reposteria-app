// test/widget/actividad/bitacora_tab_test.dart — la pestaña «Bitácora» de
// Actividad del equipo (#139) sin red: cada movimiento con su fecha y hora
// de México, la entidad legible, los detalles sin escapes (los largos con
// «Ver completo») y quién lo hizo con su rol o «Sistema»; filtrar por
// entidad, por persona y por fecha (con el calendario y la tache); «Cargar
// más» y la página siguiente al llegar al final; el vacío con «Limpiar
// filtros», el mensaje del backend con «Reintentar» y el aviso cuando
// jalar hacia abajo falla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';

import '../../fakes/actividad_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_actividad.dart';
import '../../helpers/montar_atencion.dart';

/// Monta la pantalla y abre la pestaña «Bitácora».
Future<void> _bitacora(WidgetTester tester, FakeApiClient api) async {
  await montarActividad(tester, api);
  await irAPestana(tester, 'Bitácora');
}

/// Elige [opcion] en la lista que hoy muestra [actual].
Future<void> _elegir(WidgetTester tester, String actual, String opcion) async {
  await tester.tap(find.text(actual));
  await tester.pumpAndSettle();
  // La del menú, que se abre encima de la pestaña.
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

void main() {
  group('BitacoraTab', () {
    testWidgets('cada movimiento: fecha de México, acción, entidad, '
        'detalles y quién lo hizo', (tester) async {
      final api = backendActividad();
      await _bitacora(tester, api);

      expect(api.llamo(consultaBitacora(), metodo: 'GET-Auth'), isTrue);
      for (final texto in [
        'Mostrando 3 movimientos; hay más antiguos',
        '31 Oct 2026 · 11:05 hrs',
        'Cambió el estado del pedido',
        'Pedido · ID 42',
        'De "listo" a "entregado"',
        'Ana Ruiz · Gerencia',
        'IP 10.0.0.7',
        '30 Oct 2026 · 17:40 hrs',
        'Desactivó producto',
        'Producto · ID 5',
        'Sistema',
        '29 Oct 2026 · 09:00 hrs',
        'Zona de envío',
        'Luis Pérez · Repartidor',
        'Todas las entidades',
        'Todas las personas',
        'Cargar más',
      ]) {
        expect(find.text(texto), findsOneWidget, reason: texto);
      }
      expect(find.text('Cualquier día'), findsNWidgets(2));
      // Sin filtros no hay nada que limpiar.
      expect(find.text('Limpiar filtros'), findsNothing);
    });

    testWidgets('los detalles largos se abren con Ver completo',
        (tester) async {
      await _bitacora(tester, backendActividad());
      Text detalles() => tester.widget<Text>(find.text(detallesLargos));
      expect(detalles().maxLines, 3);

      await tester.tap(find.text('Ver completo'));
      await tester.pumpAndSettle();

      expect(detalles().maxLines, isNull);
      expect(find.text('Ver menos'), findsOneWidget);
    });

    testWidgets('filtrar por entidad pide solo esa entidad', (tester) async {
      final api = backendActividad()
        ..responder(
          consultaBitacora('&entidad=producto'),
          paginaJson([productoDelSistemaJson]),
        );
      await _bitacora(tester, api);

      await _elegir(tester, 'Todas las entidades', 'Producto');

      expect(
        api.llamo(consultaBitacora('&entidad=producto'), metodo: 'GET-Auth'),
        isTrue,
      );
      expect(find.text('Desactivó producto'), findsOneWidget);
      expect(find.text('Cambió el estado del pedido'), findsNothing);
      expect(find.text('Mostrando 1 movimiento'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);
    });

    testWidgets('las fechas se eligen en el calendario y se quitan',
        (tester) async {
      final api = backendActividad();
      await _bitacora(tester, api);

      // «Desde» es el primero de los dos.
      await tester.tap(find.text('Cualquier día').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('15'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        api.llamo(consultaBitacora('&desde=2026-10-15'), metodo: 'GET-Auth'),
        isTrue,
      );
      expect(find.text('15/10/2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar la fecha «Desde»'));
      await tester.pumpAndSettle();

      expect(find.text('15/10/2026'), findsNothing);
      expect(consultasDe(api, consultaBitacora()), 2);

      // «Hasta» es el segundo.
      await tester.tap(find.text('Cualquier día').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('20'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        api.llamo(consultaBitacora('&hasta=2026-10-20'), metodo: 'GET-Auth'),
        isTrue,
      );
      expect(find.text('20/10/2026'), findsOneWidget);
    });

    testWidgets('sin resultados con estos filtros, Limpiar filtros vuelve '
        'a todos', (tester) async {
      final api = backendActividad()
        ..responder(consultaBitacora('&usuario_id=3'), paginaJson([]));
      await _bitacora(tester, api);

      await _elegir(tester, 'Todas las personas', 'Luis Pérez · Repartidor');

      expect(
        api.llamo(consultaBitacora('&usuario_id=3'), metodo: 'GET-Auth'),
        isTrue,
      );
      expect(find.text('No hay movimientos con estos filtros'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(consultasDe(api, consultaBitacora()), 2);
      expect(find.text('Todas las personas'), findsOneWidget);
      expect(find.text('Cambió el estado del pedido'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsNothing);
    });

    testWidgets('Cargar más trae la página siguiente', (tester) async {
      final api = backendActividad();
      await _bitacora(tester, api);

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(
        api.llamo(consultaBitacora('&antes_de_id=30'), metodo: 'GET-Auth'),
        isTrue,
      );
      expect(find.text('Creó promoción'), findsOneWidget);
      expect(find.text('Promoción · ID 3'), findsOneWidget);
      expect(find.text('Mostrando 4 movimientos'), findsOneWidget);
      // Era la última página.
      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('si la página siguiente no llega, el motivo y Reintentar',
        (tester) async {
      final api = backendActividad()
        ..fallar(consultaBitacora('&antes_de_id=30'), 'Sin conexión');
      await _bitacora(tester, api);

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Cambió el estado del pedido'), findsOneWidget);

      api.responder(consultaBitacora('&antes_de_id=30'), segundaPaginaJson);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Creó promoción'), findsOneWidget);
      expect(find.text('Sin conexión'), findsNothing);
    });

    testWidgets('sin movimientos ni filtros lo dice', (tester) async {
      final api = backendActividad()
        ..responder(ApiConstants.auditoria, paginaJson([]));
      await _bitacora(tester, api);

      expect(find.text('Aún no hay movimientos registrados'), findsOneWidget);
      expect(find.text('Mostrando 0 movimientos'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
    });

    testWidgets('al llegar al final pide sola la página siguiente',
        (tester) async {
      final api = backendActividad()
        ..responder(
          ApiConstants.auditoria,
          paginaJson(
            [for (var id = 90; id > 40; id--) registroJson(id: id)],
            siguiente: 41,
          ),
        )
        ..responder(
          consultaBitacora('&antes_de_id=41'),
          paginaJson([registroJson(id: 40, accion: 'El primero de todos')]),
        );
      await _bitacora(tester, api);
      expect(api.llamo(consultaBitacora('&antes_de_id=41')), isFalse);

      // Hasta el final, de a poco: cada paso avisa que se desplazó.
      for (var paso = 0; paso < 6; paso++) {
        await tester.drag(listaDe('bitacora'), const Offset(0, -3000));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(consultasDe(api, consultaBitacora('&antes_de_id=41')), 1);
    });

    testWidgets('si no carga muestra el mensaje del backend y reintenta',
        (tester) async {
      final api = backendActividad()
        ..fallar(ApiConstants.auditoria, 'Error al obtener auditoría');
      await _bitacora(tester, api);

      expect(find.text('No pudimos cargar la bitácora'), findsOneWidget);
      expect(find.text('Error al obtener auditoría'), findsOneWidget);

      api.responder(ApiConstants.auditoria, primeraPaginaJson);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Cambió el estado del pedido'), findsOneWidget);
    });

    testWidgets('si jalar hacia abajo falla conserva lo cargado y avisa',
        (tester) async {
      final api = backendActividad();
      await _bitacora(tester, api);
      api.fallar(ApiConstants.auditoria, 'Sin conexión');

      // Largo: la pantalla de prueba es muy alta.
      await tester.drag(listaDe('bitacora'), const Offset(0, 1200));
      await tester.pumpAndSettle();

      expect(consultasDe(api, consultaBitacora()), 2);
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Cambió el estado del pedido'), findsOneWidget);
    });
  });
}
