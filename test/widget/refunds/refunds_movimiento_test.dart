// test/widget/refunds/refunds_movimiento_test.dart — el movimiento de
// «Reembolsos»: el botón «Nueva Solicitud» sigue a la animación de las
// pestañas (se apaga, deja de recibir toques y sale del árbol; con
// movimiento reducido no se encoge), el título rueda y el «?» aparece y se
// va, volver a «Mis Solicitudes» no repite la entrada de las tarjetas, solo
// la solicitud recién llegada trae el aro dorado y enviar incompleto sacude
// los campos con error. Sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/public/widgets/movimiento_contenido.dart';
import 'package:pier_pasteleria/ui/refunds/view_model/refunds_view_model.dart';
import 'package:pier_pasteleria/ui/refunds/widgets/refunds_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _reembolso(int id, String numero) => {
  'id': id,
  'pedido_numero': numero,
  'monto': '640',
  'motivo': 'Producto dañado',
  'estado': 'pendiente',
  'created_at': '2026-10-01T18:00:00',
};

/// Backend cuyo historial se puede cambiar entre cargas.
FakeApiClient _backend(
  List<Map<String, dynamic>> reembolsos, {
  List<Map<String, dynamic>> pedidos = const [],
}) => FakeApiClient(
  respuestas: {
    ApiConstants.misReembolsos: (LlamadaApi _) => <String, dynamic>{
      'success': true,
      'reembolsos': [...reembolsos],
    },
    ApiConstants.misPedidos: {'success': true, 'pedidos': pedidos},
  },
);

Future<RefundsViewModel> _montar(WidgetTester tester, FakeApiClient api) async {
  final vm = RefundsViewModel(
    reembolsosRepo: ReembolsosRepositoryRemote(api: api),
    pedidosRepo: PedidosRepositoryRemote(api: api),
  );
  await tester.pumpApp(RefundsScreen(viewModel: vm), api: api);
  await tester.pump();
  return vm;
}

/// El botón flotante, envuelto en lo que lo apaga.
Finder get _fab => find.byType(FloatingActionButton);

double _opacidadFab(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _fab, matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<void> _irANueva(WidgetTester tester) async {
  await tester.tap(find.text('Nueva Solicitud').first);
  await tester.pump();
}

/// Desplazamiento horizontal actual de la sacudida que envuelve a [hijo].
double _dxSacudida(WidgetTester tester, Finder hijo) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.ancestor(of: hijo, matching: find.byType(Sacudida)).first,
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Reembolsos', () {
    testWidgets('el botón flotante sigue a la pestaña y sale del árbol', (
      tester,
    ) async {
      await _montar(tester, _backend([]));
      await tester.pumpAndSettle();
      expect(_opacidadFab(tester), 1);

      await _irANueva(tester);
      await tester.pump(const Duration(milliseconds: 150));
      // A media salida ya está apagándose y no recibe toques.
      expect(_opacidadFab(tester), lessThan(1));
      final ignora = tester.widget<IgnorePointer>(
        find.ancestor(of: _fab, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignora.ignoring, isTrue);

      await tester.pumpAndSettle();
      expect(_fab, findsNothing);

      await tester.tap(find.text('Mis Solicitudes'));
      await tester.pumpAndSettle();
      expect(_fab, findsOneWidget);
      expect(_opacidadFab(tester), 1);
    });

    testWidgets('con movimiento reducido el botón se apaga sin encogerse', (
      tester,
    ) async {
      activarReducirMovimientoIos(tester);
      await _montar(tester, _backend([]));
      await tester.pumpAndSettle();
      await _irANueva(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final escala = tester
          .widget<Transform>(
            find.ancestor(of: _fab, matching: find.byType(Transform)).first,
          )
          .transform
          .getMaxScaleOnAxis();
      expect(escala, 1);
      await tester.pumpAndSettle();
      expect(_fab, findsNothing);
    });

    testWidgets('el título rueda y el «?» aparece solo en Nueva Solicitud', (
      tester,
    ) async {
      await _montar(tester, _backend([]));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.circleHelp), findsNothing);

      await _irANueva(tester);
      await tester.pump(const Duration(milliseconds: 60));
      // Mientras rueda, el anterior todavía se va.
      expect(find.text('Reembolsos'), findsOneWidget);
      expect(find.text('Solicitar Reembolso'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleHelp), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Reembolsos'), findsNothing);
      expect(find.text('Solicitar Reembolso'), findsOneWidget);

      await tester.tap(find.text('Mis Solicitudes'));
      await tester.pumpAndSettle();
      expect(find.text('Reembolsos'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleHelp), findsNothing);
    });

    testWidgets('volver a Mis Solicitudes no repite la entrada', (
      tester,
    ) async {
      await _montar(tester, _backend([_reembolso(3, 'PIER-9')]));
      await tester.pumpAndSettle();
      Finder tarjeta() => find
          .ancestor(
            of: find.text('Pedido #PIER-9'),
            matching: find.byType(EntradaSuave),
          )
          .first;
      expect(opacidadEn(tester, tarjeta()), 1);

      await _irANueva(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis Solicitudes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(opacidadEn(tester, tarjeta()), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('solo la solicitud recién llegada trae el aro dorado', (
      tester,
    ) async {
      final reembolsos = [_reembolso(3, 'PIER-9')];
      final vm = await _montar(tester, _backend(reembolsos));
      await tester.pumpAndSettle();
      bool resaltada(String numero) => tester
          .widget<ResaltadoUnaVez>(
            find
                .ancestor(
                  of: find.text('Pedido #$numero'),
                  matching: find.byType(ResaltadoUnaVez),
                )
                .first,
          )
          .activo;
      expect(resaltada('PIER-9'), isFalse);

      reembolsos.insert(0, _reembolso(4, 'PIER-12'));
      await vm.cargarReembolsos();
      await tester.pump();
      expect(resaltada('PIER-12'), isTrue);
      expect(resaltada('PIER-9'), isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('enviar incompleto sacude el motivo y la descripción', (
      tester,
    ) async {
      await _montar(
        tester,
        _backend(
          [],
          pedidos: [
            {
              'id': 9,
              'numero': 'PIER-9',
              'estado': 'completado',
              'total': '640',
            },
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _irANueva(tester);
      await tester.pumpAndSettle();

      final boton = find.text('Enviar Solicitud');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Los textos de error son los de siempre.
      expect(find.text('Mínimo 10 caracteres'), findsOneWidget);
      expect(
        _dxSacudida(tester, find.text('Selecciona un motivo').first),
        isNot(0),
      );
      expect(
        _dxSacudida(tester, find.text('Describe el problema con detalle...')),
        isNot(0),
      );
      await tester.pumpAndSettle();
      expect(
        _dxSacudida(tester, find.text('Describe el problema con detalle...')),
        0,
      );
    });
  });
}
