// test/widget/comandas/comandas_personal_screen_test.dart — comandas para
// empleado, gerencia y dirección (#129) sin red: agenda y detalle con montos
// y firmas, entregar con el saldo cobrado, cancelar con motivo, sin permiso
// para cancelar, imprimir en la web y acceso al panel web.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_screen.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';
import '../../helpers/montar_comandas.dart';

const _detalle = '/comandas/7';
const _entregar = '/comandas/7/entregar';
const _cancelar = '/comandas/7/cancelar';

final Map<String, dynamic> _firmada = firmaJson(
  vigente: true,
  version: 1,
  usuario: 'Rosa Pérez',
);

Map<String, dynamic> _conMontos({bool cancelar = true}) => detalleJson(
  confirmar: null,
  total: '850.00',
  anticipo: '200.00',
  saldo: '650.00',
  entregar: true,
  cancelar: cancelar,
  imprimir: true,
);

Future<void> _detalleEmpleado(WidgetTester tester, FakeApiClient api) =>
    montarComandas(
      tester,
      api,
      pantalla: const DetalleComandaScreen(id: 7),
      rol: 'empleado',
    );

void main() {
  group('Agenda para quien cobra', () {
    testWidgets('sin pendientes de área, con total y saldo en la tarjeta', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(
          '/comandas?vista=proximas',
          agendaJson([
            comandaJson(
              total: '850.00',
              anticipo: '200.00',
              saldo: '650.00',
              hornos: _firmada,
            ),
          ]),
        );
      await montarComandas(
        tester,
        api,
        pantalla: const AgendaComandasScreen(),
        rol: 'gerencia',
      );

      expect(find.text('Comandas'), findsOneWidget);
      expect(
        find.textContaining('Pendientes de tu confirmación'),
        findsNothing,
      );
      expect(find.text(r'Total $850.00 · Saldo $650.00'), findsOneWidget);
      expect(find.text('Hornos: confirmó'), findsOneWidget);
      expect(api.llamo('/comandas?vista=activas'), isFalse);
    });

    testWidgets('el menú lleva al panel web', (tester) async {
      final urls = capturarUrls(tester);
      final api = FakeApiClient()
        ..responder('/comandas?vista=proximas', agendaJson(const []));
      await montarComandas(
        tester,
        api,
        pantalla: const AgendaComandasScreen(),
        rol: 'direccion_general',
      );

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir panel web'));
      await tester.pumpAndSettle();

      expect(urls, ['https://pier-reposteria.vercel.app']);
    });
  });

  group('Detalle para quien cobra', () {
    testWidgets('cobro y firmas, sin botón Enterado', (tester) async {
      final api = FakeApiClient()..responder(_detalle, _conMontos());
      await _detalleEmpleado(tester, api);

      expect(find.text('Cobro'), findsOneWidget);
      expect(find.text(r'$850.00'), findsWidgets);
      expect(find.text(r'$200.00'), findsOneWidget);
      expect(find.text(r'$650.00'), findsOneWidget);
      expect(find.text('Hornos: pendiente'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Enterado'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Entregar'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar comanda'),
        findsOneWidget,
      );
    });

    testWidgets('entregar: saldo pendiente sugerido, aviso de firmas y '
        'advertencias', (tester) async {
      final api = FakeApiClient()
        ..responder(_detalle, _conMontos())
        ..responder(_entregar, {
          'success': true,
          'message': 'Comanda #5003 entregada',
          'advertencias': [
            'Hornos no confirmó de enterado la versión 1',
            'Decoración no confirmó de enterado la versión 1',
          ],
        });
      await _detalleEmpleado(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar entregada la comanda #5003'), findsOneWidget);
      expect(find.text('650.00'), findsOneWidget);
      expect(find.text('Si no se cobró nada, escribe 0.'), findsOneWidget);
      expect(
        find.text(
          'Producción aún no confirma la versión actual: faltan '
          'Hornos y Decoración. Puedes entregarla de todos modos.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(
        find.text(
          'Escribe una cantidad válida: 0 o más, con hasta dos decimales.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Marcar entregada'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), '600');
      await tester.pump();
      expect(
        find.text(
          r'Es distinto del saldo pendiente ($650.00). '
          'Revisa que sea correcto.',
        ),
        findsOneWidget,
      );
      api.responder(
        _detalle,
        detalleJson(
          confirmar: null,
          estado: 'entregada',
          semaforo: null,
          total: '850.00',
          saldoCobrado: '600.00',
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Marcar entregada'));
      await tester.pumpAndSettle();

      expect(api.ultima(_entregar)!.body, {'saldo_cobrado': 600.0});
      expect(find.textContaining('Comanda #5003 entregada'), findsOneWidget);
      expect(
        find.textContaining('Hornos no confirmó de enterado'),
        findsOneWidget,
      );
      expect(find.text('Comanda entregada'), findsOneWidget);
      expect(find.text(r'$600.00'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entregar'), findsNothing);
    });

    testWidgets('cancelar: pide un motivo de al menos 5 caracteres', (
      tester,
    ) async {
      final api = FakeApiClient()
        ..responder(_detalle, _conMontos())
        ..responder(_cancelar, {
          'success': true,
          'message': 'Comanda #5003 cancelada',
        });
      await _detalleEmpleado(tester, api);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar comanda'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar la comanda #5003'), findsOneWidget);
      FilledButton boton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sí, cancelar'),
      );
      expect(boton().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'No');
      await tester.pump();
      expect(boton().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'El cliente ya no vino');
      await tester.pump();
      api.responder(
        _detalle,
        detalleJson(
          confirmar: null,
          estado: 'cancelada',
          semaforo: null,
          motivoCancelacion: 'El cliente ya no vino',
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(api.ultima(_cancelar)!.body, {'motivo': 'El cliente ya no vino'});
      expect(find.text('Comanda #5003 cancelada'), findsOneWidget);
      expect(
        find.text('Comanda cancelada: El cliente ya no vino'),
        findsOneWidget,
      );
    });

    testWidgets('Volver no cancela', (tester) async {
      final api = FakeApiClient()..responder(_detalle, _conMontos());
      await _detalleEmpleado(tester, api);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar comanda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(api.llamo(_cancelar), isFalse);
    });

    testWidgets('si falla al entregar lo avisa', (tester) async {
      final api = FakeApiClient()
        ..responder(_detalle, _conMontos())
        ..fallar(
          _entregar,
          'Esta comanda ya fue cancelada y no se puede entregar',
        );
      await _detalleEmpleado(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Marcar entregada'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta comanda ya fue cancelada y no se puede entregar'),
        findsOneWidget,
      );
    });

    testWidgets('sin permiso para cancelar no ve el botón', (tester) async {
      final api = FakeApiClient()
        ..responder(_detalle, _conMontos(cancelar: false));
      await _detalleEmpleado(tester, api);

      expect(
        find.widgetWithText(OutlinedButton, 'Cancelar comanda'),
        findsNothing,
      );
      expect(find.widgetWithText(FilledButton, 'Entregar'), findsOneWidget);
    });

    testWidgets('imprimir abre la hoja de impresión de la web', (tester) async {
      final urls = capturarUrls(tester);
      final api = FakeApiClient()..responder(_detalle, _conMontos());
      await _detalleEmpleado(tester, api);

      await tester.tap(find.byTooltip('Imprimir'));
      await tester.pumpAndSettle();

      expect(urls, ['https://pier-reposteria.vercel.app/comandas/7/imprimir']);
    });
  });
}
