// test/widget/atencion/quejas_personal_tab_test.dart — la pestaña «Quejas»
// de Atención a clientes (#138) sin red: la tarjeta de cada ticket con los
// pendientes primero, el detalle, responder y resolver (con la respuesta
// mínima), marcar en proceso, una respuesta rápida sin cerrar el ticket y
// un ticket resuelto que ya no se responde.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';

import '../../fakes/atencion_json.dart';
import '../../helpers/montar_atencion.dart';

const _asunto = 'Pan & café "frío"';

void main() {
  group('QuejasPersonalTab', () {
    testWidgets('cada ticket con su tipo, estado y prioridad; pendientes '
        'primero', (tester) async {
      await montarAtencion(tester, backendAtencion());

      expect(find.text('TKT-001 · Ana Ruiz'), findsOneWidget);
      expect(find.text('Sugerencia'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('Prioridad alta'), findsOneWidget);
      double arriba(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('queja-$id'))).dy;
      expect(arriba('1'), lessThan(arriba('2')));
      expect(arriba('2'), lessThan(arriba('3')));
    });

    testWidgets('responder y resolver; una respuesta corta no se manda',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.atenderQueja('1'), {'success': true});
      await montarAtencion(tester, api);

      await tester.tap(find.text(_asunto));
      await tester.pumpAndSettle();
      expect(find.text('Llegó con la cobertura corrida'), findsOneWidget);
      expect(find.text('Ana Ruiz\nana@correo.mx\n7711234567'), findsOneWidget);
      expect(find.text('PIER-12'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Perdón');
      await tester.tap(find.text('Responder y resolver'));
      await tester.pumpAndSettle();
      expect(find.text('La respuesta debe tener al menos 10 caracteres.'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.atenderQueja('1')), isFalse);

      await tester.enterText(
          find.byType(TextField), 'Te llamamos hoy para reponerlo');
      await tester.tap(find.text('Responder y resolver'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body, {
        'estado': 'resuelto',
        'respuesta': 'Te llamamos hoy para reponerlo',
      });
      expect(find.text('Respuesta enviada: TKT-001 quedó resuelto'),
          findsOneWidget);
    });

    testWidgets('marcar en proceso; la tarjeta espera a que termine',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.atenderQueja('1'), {'success': true})
        ..demorar(ApiConstants.atenderQueja('1'),
            const Duration(milliseconds: 300));
      await montarAtencion(tester, api);

      await tester.tap(find.text(_asunto));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar en proceso'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body,
          {'estado': 'en_proceso'});
      expect(find.text('TKT-001 quedó en proceso'), findsOneWidget);
    });

    testWidgets('una respuesta rápida sin cerrar el ticket', (tester) async {
      const rapida = '¡Excelente sugerencia! La compartiremos con nuestro '
          'equipo para evaluarla. Gracias por ayudarnos a mejorar.';
      final api = backendAtencion()
        ..responder(ApiConstants.atenderQueja('2'), {'success': true});
      await montarAtencion(tester, api);

      await tester.tap(find.text('Más sabores'));
      await tester.pumpAndSettle();
      // Ya en proceso: su respuesta, sin «Marcar en proceso».
      expect(find.text('Respuesta de Pier Repostería'), findsOneWidget);
      expect(find.text('Lo vemos el 5/11'), findsOneWidget);
      expect(find.text('Sin pedido'), findsOneWidget);
      expect(find.text('Marcar en proceso'), findsNothing);

      await tester.tap(find.text(rapida));
      await tester.pump();
      await tester.tap(find.text('Responder sin cerrar'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.atenderQueja('2'))!.body,
          {'estado': 'en_proceso', 'respuesta': rapida});
      expect(find.text('Respuesta enviada: TKT-002 sigue en proceso'),
          findsOneWidget);
    });

    testWidgets('un ticket resuelto ya no se responde', (tester) async {
      final api = backendAtencion();
      await montarAtencion(tester, api);

      await tester.tap(find.text('Todo muy rico'));
      await tester.pumpAndSettle();
      expect(find.text('¡Gracias por escribirnos!'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Responder y resolver'), findsNothing);

      // Cerrar el detalle sin decidir nada no manda nada.
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(find.text('¡Gracias por escribirnos!'), findsNothing);
      expect(api.llamadas.where((l) => l.metodo == 'PUT-Auth'), isEmpty);
    });
  });
}
