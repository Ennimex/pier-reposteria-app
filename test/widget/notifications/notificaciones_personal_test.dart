// test/widget/notifications/notificaciones_personal_test.dart — notificaciones
// del personal (#136) sin red: la campana de la agenda cuenta las no leídas,
// las alertas tienen su ícono, tocar un aviso de comanda abre esa comanda (o
// regresa a la agenda si no se encuentra) y al cerrar sesión la campana se
// vacía.
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_screen.dart';
import 'package:pier_reposteria/ui/core/state/notification_provider.dart';
import 'package:pier_reposteria/ui/home/widgets/home_encabezado.dart';
import 'package:pier_reposteria/ui/notifications/widgets/notifications_screen.dart';
import 'package:provider/provider.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart';

Map<String, dynamic> _aviso(
  int id,
  String tipo,
  String titulo, {
  bool leida = false,
}) => {
  'id': id,
  'tipo': tipo,
  'titulo': titulo,
  'mensaje': 'Detalle $id',
  'leida': leida,
  'created_at': '2026-10-12T15:00:00Z',
};

FakeApiClient _backend({List<Map<String, dynamic>>? avisos}) => FakeApiClient()
  ..responder(ApiConstants.agendaComandas('proximas'), agendaJson([]))
  ..responder(ApiConstants.notificaciones, {
    'success': true,
    'notificaciones':
        avisos ??
        [
          _aviso(1, 'pedido', 'Nueva comanda #5001'),
          _aviso(2, 'alerta', 'Comanda #5009 cancelada'),
          _aviso(3, 'aviso', 'Mensaje de contacto: Ana', leida: true),
        ],
  })
  ..responder(ApiConstants.marcarNotificacionLeida('1'), {'success': true})
  ..responder(ApiConstants.marcarNotificacionLeida('2'), {'success': true});

Future<void> _abrirNotificaciones(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Notificaciones'));
  await tester.pumpAndSettle();
  expect(find.byType(NotificationsScreen), findsOneWidget);
}

void main() {
  group('Notificaciones del personal (#136)', () {
    testWidgets('la campana de la agenda cuenta las no leídas', (tester) async {
      final api = _backend();
      await montarComandas(tester, api, pantalla: const AgendaComandasScreen());

      expect(api.llamo(ApiConstants.notificaciones), isTrue);
      final campana = tester.widget<CampanaNotificaciones>(
        find.byType(CampanaNotificaciones),
      );
      expect(campana.cantidad, 2);
    });

    testWidgets('las alertas tienen su propio ícono', (tester) async {
      await montarComandas(
        tester,
        _backend(),
        pantalla: const AgendaComandasScreen(),
      );
      await _abrirNotificaciones(tester);

      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
      expect(find.byIcon(LucideIcons.mail), findsOneWidget);
    });

    testWidgets('tocar un aviso de comanda la busca por folio y la abre', (
      tester,
    ) async {
      final api = _backend()
        ..responder(
          ApiConstants.agendaComandas('activas', busqueda: '5001'),
          agendaJson([comandaJson(id: 11)]),
        )
        ..responder(
          ApiConstants.comandaDetalle(11),
          detalleJson(id: 11, folio: 5001),
        );
      await montarComandas(tester, api, pantalla: const AgendaComandasScreen());
      await _abrirNotificaciones(tester);

      await tester.tap(find.text('Nueva comanda #5001'));
      await tester.pumpAndSettle();

      expect(find.byType(DetalleComandaScreen), findsOneWidget);
      expect(api.llamo(ApiConstants.comandaDetalle(11)), isTrue);
      expect(api.llamo(ApiConstants.marcarNotificacionLeida('1')), isTrue);
    });

    testWidgets('si no encuentra la comanda regresa a la agenda', (
      tester,
    ) async {
      final api = _backend()
        ..responder(
          ApiConstants.agendaComandas('canceladas', busqueda: '5009'),
          agendaJson([]),
        )
        ..responder(
          ApiConstants.agendaComandas('activas', busqueda: '5009'),
          agendaJson([]),
        );
      await montarComandas(tester, api, pantalla: const AgendaComandasScreen());
      await _abrirNotificaciones(tester);

      await tester.tap(find.text('Comanda #5009 cancelada'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.byType(DetalleComandaScreen), findsNothing);
      expect(find.byType(AgendaComandasScreen), findsOneWidget);
      // Primero entre las canceladas, luego entre las activas.
      expect(
        api.llamo(ApiConstants.agendaComandas('canceladas', busqueda: '5009')),
        isTrue,
      );
      expect(
        api.llamo(ApiConstants.agendaComandas('activas', busqueda: '5009')),
        isTrue,
      );
    });

    testWidgets('un aviso que no es de comanda solo se marca como leído', (
      tester,
    ) async {
      final api = _backend(
        avisos: [_aviso(1, 'alerta', 'Cobro sin pedido')],
      );
      await montarComandas(tester, api, pantalla: const AgendaComandasScreen());
      await _abrirNotificaciones(tester);

      await tester.tap(find.text('Cobro sin pedido'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(api.llamo(ApiConstants.marcarNotificacionLeida('1')), isTrue);
      // No buscó ninguna comanda por folio.
      expect(
        api.llamadas.where((l) => l.endpoint.contains('busqueda=')),
        isEmpty,
      );
    });

    testWidgets('sin notificaciones ofrece volver a las comandas', (
      tester,
    ) async {
      await montarComandas(
        tester,
        _backend(avisos: []),
        pantalla: const AgendaComandasScreen(),
      );
      await _abrirNotificaciones(tester);

      expect(
        find.textContaining('las comandas nuevas, sus cambios'),
        findsOneWidget,
      );
      expect(find.text('Explorar Menú'), findsNothing);
      await tester.tap(find.text('Ver comandas'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.byType(AgendaComandasScreen), findsOneWidget);
    });

    testWidgets('al cerrar sesión la campana se vacía', (tester) async {
      final api = _backend();
      await montarComandas(tester, api, pantalla: const AgendaComandasScreen());

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      final notificaciones = Provider.of<NotificationProvider>(
        tester.element(find.text('LOGIN')),
        listen: false,
      );
      expect(notificaciones.notificaciones, isEmpty);
    });
  });
}
