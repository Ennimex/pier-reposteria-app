// test/widget/notifications/movimiento_notificaciones_test.dart — el
// movimiento de «Notificaciones»: una notificación que llega con la pantalla
// abierta entra sin repetir las que ya estaban y la insignia termina en su
// número exacto; al leer una, su título deja el negrito y el punto sale del
// árbol; del indicador de carga a la lista el indicador sale del árbol; en
// la lista vacía la campana se mece una vez y queda derecha (en el error
// no); con movimiento reducido todo aparece en su lugar. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/notifications/view_model/notifications_view_model.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _notificacion(
  int id,
  String titulo, {
  bool leida = false,
  String creada = '2026-10-10T17:30:00',
}) => {
  'id': id,
  'tipo': 'pedido',
  'titulo': titulo,
  'mensaje': 'Mensaje de $titulo',
  'leida': leida,
  'created_at': creada,
};

Map<String, dynamic> _lista(List<Map<String, dynamic>> notificaciones) => {
  'success': true,
  'notificaciones': notificaciones,
};

/// Pantalla de celular (412×869 lógicos, como el Note 10+).
void _celular(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

Future<(FakeApiClient, NotificationProvider)> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? lista,
  bool reducido = false,
  Duration? demora,
}) async {
  _celular(tester);
  final api = FakeApiClient(
    respuestas: {
      ApiConstants.notificaciones:
          lista ??
          _lista([
            _notificacion(1, 'Tu pedido está listo'),
            _notificacion(
              2,
              'Temporada de fresas',
              leida: true,
              creada: '2026-10-01T12:00:00',
            ),
          ]),
      ApiConstants.marcarNotificacionLeida('1'): {'success': true},
    },
  );
  if (demora != null) api.demorar(ApiConstants.notificaciones, demora);
  final provider = NotificationProvider(
    repo: NotificacionesRepositoryRemote(api: api),
  );
  final pantalla = NotificationsScreen(
    viewModel: NotificationsViewModel(
      notificaciones: provider,
      ahora: () => DateTime(2026, 10, 10, 18),
    ),
  );
  await tester.pumpApp(
    reducido ? ConMovimientoReducido(child: pantalla) : pantalla,
    api: api,
  );
  await tester.pump();
  return (api, provider);
}

/// La entrada (EntradaSuave) más cercana que envuelve a [texto].
Finder _entradaDe(String texto) => find
    .ancestor(of: find.text(texto), matching: find.byType(EntradaSuave))
    .first;

/// Cuánto está girada la campana de la lista vacía (en vueltas).
double _giroCampana(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find
          .ancestor(
            of: find.byIcon(LucideIcons.bellOff),
            matching: find.byType(RotationTransition),
          )
          .first,
    )
    .turns
    .value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('una notificación que llega con la pantalla abierta entra sin '
      'repetir las demás y la insignia termina en su número', (tester) async {
    final (api, provider) = await _montar(tester);
    await tester.pumpAndSettle();
    expect(opacidadEn(tester, _entradaDe('Tu pedido está listo')), 1);
    expect(find.text('1'), findsOneWidget);

    // Como el sondeo: llega una nueva, arriba.
    api.responder(
      ApiConstants.notificaciones,
      _lista([
        _notificacion(3, 'Nueva promoción', creada: '2026-10-10T17:55:00'),
        _notificacion(1, 'Tu pedido está listo'),
        _notificacion(
          2,
          'Temporada de fresas',
          leida: true,
          creada: '2026-10-01T12:00:00',
        ),
      ]),
    );
    await provider.cargar();
    await tester.pump();
    await tester.pump();

    expect(opacidadEn(tester, _entradaDe('Nueva promoción')), lessThan(1));
    expect(opacidadEn(tester, _entradaDe('Tu pedido está listo')), 1);
    expect(opacidadEn(tester, _entradaDe('Temporada de fresas')), 1);

    await tester.pumpAndSettle();
    expect(opacidadEn(tester, _entradaDe('Nueva promoción')), 1);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('al leer una se hunde al tocarla, su título deja el negrito y '
      'el punto sale del árbol', (tester) async {
    await _montar(tester);
    await tester.pumpAndSettle();
    FontWeight? peso() => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text('Tu pedido está listo'),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        )
        .style
        .fontWeight;
    expect(peso(), FontWeight.bold);
    expect(
      find.ancestor(
        of: find.text('Tu pedido está listo'),
        matching: find.byType(PresionEscala),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Tu pedido está listo'));
    await tester.pumpAndSettle();

    expect(peso(), FontWeight.w500);
    expect(find.byKey(const ValueKey('punto-no-leida')), findsNothing);
    expect(find.text('Leer todas'), findsNothing);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('de la carga a la lista el indicador sale del árbol', (
    tester,
  ) async {
    await _montar(tester, demora: const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tu pedido está listo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('vacía: la campana se mece una vez y queda derecha', (
    tester,
  ) async {
    await _montar(tester, lista: _lista([]));
    expect(find.text('Sin notificaciones'), findsOneWidget);
    expect(_giroCampana(tester), 0);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_giroCampana(tester), isNot(0));

    await tester.pumpAndSettle();
    expect(_giroCampana(tester), 0);
  });

  testWidgets('en el error la campana no se mece', (tester) async {
    await _montar(
      tester,
      lista: {'success': false, 'message': 'Sin conexión'},
    );
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(LucideIcons.wifiOff),
        matching: find.byType(RotationTransition),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('con movimiento reducido todo aparece en su lugar', (
    tester,
  ) async {
    await _montar(tester, reducido: true);

    expect(opacidadEn(tester, _entradaDe('Tu pedido está listo')), 1);
    expect(opacidadEn(tester, _entradaDe('Hoy')), 1);
    // Del indicador a la lista queda solo un fundido corto, y nada más.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
