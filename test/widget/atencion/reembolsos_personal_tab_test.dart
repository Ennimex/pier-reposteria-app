// test/widget/atencion/reembolsos_personal_tab_test.dart — la pestaña
// «Reembolsos» de Atención a clientes (#138) sin red: la tarjeta de cada
// solicitud, el mostrador que solo la pasa a revisión (y amplía las fotos),
// gerencia que aprueba o rechaza con justificación, dirección que la marca
// como devuelta, lo que ve el mostrador mientras decide gerencia y el
// mensaje del backend cuando otra persona ya la cambió.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';

import '../../fakes/atencion_json.dart';
import '../../helpers/montar_atencion.dart';

void main() {
  group('ReembolsosPersonalTab', () {
    testWidgets('cada solicitud con pedido, monto, motivo y estado',
        (tester) async {
      await montarAtencion(tester, backendAtencion());
      await irAPestana(tester, 'Reembolsos');

      expect(find.text('Pedido PIER-41'), findsOneWidget);
      expect(find.text(r'$320.50'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Devuelto'), findsOneWidget);
      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.text('Automático por cancelación'), findsOneWidget);
      expect(find.text('Otro motivo'), findsOneWidget);
      expect(find.text('2 fotos'), findsOneWidget);
      // Las que esperan una decisión primero.
      double arriba(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('reembolso-$id'))).dy;
      expect(arriba('1'), lessThan(arriba('2')));
      expect(arriba('3'), lessThan(arriba('4')));
    });

    testWidgets('el mostrador solo la pasa a revisión; las fotos se amplían',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.resolverReembolso('1'), {'success': true});
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reembolsos');

      await tester.tap(find.text('Pedido PIER-41'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud del pedido PIER-41'), findsOneWidget);
      expect(find.text('La caja llegó abierta & el pan duro'), findsOneWidget);
      expect(find.text('Evidencia fotográfica (2)'), findsOneWidget);
      expect(find.text('Aprobar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);

      await tester.tap(find.byTooltip('Ampliar la foto 2'));
      await tester.pumpAndSettle();
      expect(find.text('Evidencia fotográfica'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Evidencia fotográfica'), findsNothing);

      await tester.tap(find.text('Pasar a revisión'));
      await tester.pumpAndSettle();
      expect(find.text(r'Pedido PIER-41 · $150.00'), findsOneWidget);
      await tester.tap(botonDelDialogo('Pasar a revisión'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.resolverReembolso('1'))!.body, {
        'estado': 'en_revision',
        'respuesta_admin': 'Recibimos tu solicitud; gerencia la revisará hoy.',
      });
      expect(find.text('La solicitud del pedido PIER-41 pasó a revisión'),
          findsOneWidget);
    });

    testWidgets('gerencia aprueba y rechaza con justificación',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.resolverReembolso('2'), {'success': true})
        ..responder(ApiConstants.resolverReembolso('1'), {'success': true});
      await montarAtencion(tester, api, rol: 'gerencia');
      await irAPestana(tester, 'Reembolsos');

      // En revisión: aprobar avisa que la devolución se hace en Stripe.
      await tester.tap(find.text('Pedido PIER-42'));
      await tester.pumpAndSettle();
      expect(find.text('Gerencia decide si se aprueba o se rechaza.'),
          findsNothing);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('la devolución del dinero se hace en Stripe'),
          findsOneWidget);
      await tester.tap(botonDelDialogo('Aprobar'));
      await tester.pumpAndSettle();
      expect(api.ultima(ApiConstants.resolverReembolso('2'))!.body,
          {'estado': 'aprobado', 'respuesta_admin': 'Reembolso aprobado'});
      expect(find.text('Reembolso del pedido PIER-42 aprobado'), findsOneWidget);

      // Pendiente: rechazar exige la justificación.
      await tester.tap(find.text('Pedido PIER-41'));
      await tester.pumpAndSettle();
      expect(find.text('Pasar a revisión'), findsOneWidget);
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'No procede');
      await tester.tap(botonDelDialogo('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('La justificación debe tener al menos 20 caracteres.'),
          findsOneWidget);
      expect(api.llamo(ApiConstants.resolverReembolso('1')), isFalse);

      await tester.enterText(
          find.byType(TextField), 'La foto no muestra ningún daño en el pastel');
      await tester.tap(botonDelDialogo('Rechazar'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.resolverReembolso('1'))!.body, {
        'estado': 'rechazado',
        'justificacion_rechazo': 'La foto no muestra ningún daño en el pastel',
      });
      expect(find.text('Reembolso del pedido PIER-41 rechazado'),
          findsOneWidget);
    });

    testWidgets('dirección la marca como devuelta después de Stripe',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.resolverReembolso('3'), {'success': true});
      await montarAtencion(tester, api, rol: 'direccion_general');
      await irAPestana(tester, 'Reembolsos');

      await tester.tap(find.text('Pedido PIER-43'));
      await tester.pumpAndSettle();
      expect(find.text('Te lo devolvemos & avisamos'), findsOneWidget);
      await tester.tap(find.text('Marcar como devuelto'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          r'Esto solo registra la devolución: hazla primero en Stripe por $320.50.',
        ),
        findsOneWidget,
      );
      await tester.tap(botonDelDialogo('Marcar como devuelto'));
      await tester.pumpAndSettle();

      // Parte del mensaje que ya ve el cliente, tal como se escribió.
      expect(api.ultima(ApiConstants.resolverReembolso('3'))!.body, {
        'estado': 'procesado',
        'respuesta_admin': 'Te lo devolvemos & avisamos',
      });
      expect(find.text('Reembolso del pedido PIER-43 marcado como devuelto'),
          findsOneWidget);
    });

    testWidgets('el mostrador ve que decide gerencia y por qué se rechazó',
        (tester) async {
      final api = backendAtencion();
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reembolsos');

      await tester.tap(find.text('Pedido PIER-42'));
      await tester.pumpAndSettle();
      expect(find.text('Gerencia decide si se aprueba o se rechaza.'),
          findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pedido PIER-44'));
      await tester.pumpAndSettle();
      expect(find.text('Justificación del rechazo'), findsOneWidget);
      expect(find.text('La foto no muestra ningún daño en el pastel'),
          findsOneWidget);
      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pedido PIER-46'));
      await tester.pumpAndSettle();
      expect(find.text('Reembolso automático por cancelación'), findsOneWidget);
      expect(api.llamadas.where((l) => l.metodo == 'PUT-Auth'), isEmpty);
    });

    testWidgets('si otra persona ya la cambió muestra el mensaje y recarga',
        (tester) async {
      final api = backendAtencion()
        ..fallar(ApiConstants.resolverReembolso('1'),
            'Esta solicitud ya no está pendiente');
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reembolsos');

      await tester.tap(find.text('Pedido PIER-41'));
      await tester.pumpAndSettle();
      // Cancelar deja el detalle abierto y no manda nada.
      await tester.tap(find.text('Pasar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud del pedido PIER-41'), findsOneWidget);
      expect(api.llamo(ApiConstants.resolverReembolso('1')), isFalse);

      await tester.tap(find.text('Pasar a revisión'));
      await tester.pumpAndSettle();
      await tester.tap(botonDelDialogo('Pasar a revisión'));
      await tester.pumpAndSettle();

      expect(find.text('Esta solicitud ya no está pendiente'), findsOneWidget);
      expect(cargasDe(api, ApiConstants.reembolsosPersonal), 2);
    });
  });
}
