// test/aceptacion/repartidor/disponibilidad_test.dart — escenarios Gherkin
// de «Mis entregas» del repartidor: activar la disponibilidad, aceptar un
// pedido del pool y no tomar pedidos sin estar disponible (#68; historia
// #45), sin red.
//
// Cada prueba abre el panel con la sesión del repartidor
// (helpers/montar_repartidor.dart) y toca el mismo interruptor y los mismos
// botones que él. El backend es BackendEntregas, que guarda la
// disponibilidad, el pool y las entregas y responde como
// routes/entregasRoutes.js: lo que se ve en el panel es lo que el
// «servidor» tiene.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';

import '../../fakes/entregas_json.dart';
import '../../helpers/montar_repartidor.dart';

/// El interruptor de disponibilidad de la pestaña que se ve.
Switch _interruptor(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch));

void main() {
  group('#45 Repartidor: disponibilidad y aceptación de pedidos', () {
    // Escenario: activar la disponibilidad
    //   Dado que inicié sesión como repartidor
    //   Cuando me marco como disponible para entregas
    //   Entonces la app muestra los pedidos disponibles para tomar
    testWidgets('Escenario: activar la disponibilidad', (tester) async {
      // Dado que inicié sesión como repartidor (todavía no disponible)
      final backend = BackendEntregas(
        disponible: false,
        pool: [pedidoListoJson(41)],
      );
      await abrirPanelRepartidor(tester, backend);
      expect(find.text('Mis entregas'), findsOneWidget);
      expect(find.text('LH'), findsOneWidget); // Luis Hernández
      expect(_interruptor(tester).value, isFalse);
      expect(find.text('No estás recibiendo entregas'), findsOneWidget);
      expect(find.text('No estás disponible'), findsOneWidget);
      // Ajuste: el pool se lista aunque el repartidor no esté disponible,
      // igual que en la web: GET /entregas/disponibles no depende de la
      // disponibilidad y el backend la revisa al aceptar (ver «sin
      // disponibilidad»). Activarse cambia el interruptor y las
      // invitaciones de la pantalla y deja tomar los pedidos.
      expect(tarjetaDelPool('PIER-41'), findsOneWidget);

      // Cuando me marco como disponible para entregas
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Entonces la app muestra los pedidos disponibles para tomar
      final cambio = backend.api.ultima(ApiConstants.disponibilidad)!;
      expect(cambio.metodo, 'PUT-Auth');
      expect(cambio.body, {'disponible': true});
      expect(backend.disponible, isTrue);
      expect(_interruptor(tester).value, isTrue);
      expect(find.text('Sin entregas activas por ahora'), findsOneWidget);
      expect(find.text('Sin entregas por ahora'), findsOneWidget);
      expect(
        find.text('Toma un pedido de "Disponibles"\ny aparecerá aquí.'),
        findsOneWidget,
      );
      expect(find.text('Disponibles'), findsOneWidget);
      expect(tarjetaDelPool('PIER-41'), findsOneWidget);
      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('Aviación'), findsOneWidget);
      expect(find.text('Tomar entrega'), findsOneWidget);
    });

    // Escenario: aceptar un pedido
    //   Dado que estoy disponible y hay pedidos disponibles
    //   Cuando acepto uno
    //   Entonces pasa a mi lista de entregas en curso
    testWidgets('Escenario: aceptar un pedido', (tester) async {
      // Dado que estoy disponible y hay pedidos disponibles
      final backend = BackendEntregas(
        pool: [pedidoListoJson(41), pedidoListoJson(42)],
      );
      await abrirPanelRepartidor(tester, backend);
      expect(_interruptor(tester).value, isTrue);
      expect(tarjetaDelPool('PIER-41'), findsOneWidget);
      expect(tarjetaDelPool('PIER-42'), findsOneWidget);
      expect(find.text('Sin entregas por ahora'), findsOneWidget);

      // Cuando acepto uno
      await tester.tap(
        find.descendant(
          of: tarjetaDelPool('PIER-41'),
          matching: find.text('Tomar entrega'),
        ),
      );
      await tester.pumpAndSettle();

      // Entonces pasa a mi lista de entregas en curso
      final aceptar = backend.api.ultima(ApiConstants.entregasAceptar)!;
      expect(aceptar.metodo, 'POST-Auth');
      expect(aceptar.body, {'pedido_id': '41'});
      expect(find.text('Tomaste el pedido #PIER-41'), findsOneWidget);
      expect(tarjetaEnCurso('PIER-41'), findsOneWidget);
      expect(
        find.descendant(
          of: tarjetaEnCurso('PIER-41'),
          matching: find.text('Asignada'),
        ),
        findsOneWidget,
      );
      expect(tarjetaDelPool('PIER-41'), findsNothing);
      expect(find.text('Tienes 1 entrega activa para hoy'), findsOneWidget);
      expect(backend.entregas.single['estado'], 'asignada');
      // El otro pedido sigue en el pool para tomarlo.
      expect(tarjetaDelPool('PIER-42'), findsOneWidget);
    });

    // Escenario: sin disponibilidad
    //   Dado que me marqué como no disponible
    //   Cuando abro «Mis entregas»
    //   Entonces la app no me ofrece pedidos nuevos para tomar
    testWidgets('Escenario: sin disponibilidad', (tester) async {
      // Dado que me marqué como no disponible (desde mi perfil)
      final backend = BackendEntregas(pool: [pedidoListoJson(41)]);
      await abrirPanelRepartidor(tester, backend);
      await irAPestana(tester, 'Perfil');
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text('No disponible'), findsOneWidget);
      expect(backend.api.ultima(ApiConstants.disponibilidad)!.body, {
        'disponible': false,
      });

      // Cuando abro «Mis entregas»
      await irAPestana(tester, 'Entregas');
      expect(find.text('Mis entregas'), findsOneWidget);

      // Entonces la app no me ofrece pedidos nuevos para tomar: dice que no
      // estoy recibiendo entregas y me invita a activarme.
      expect(_interruptor(tester).value, isFalse);
      expect(find.text('No estás recibiendo entregas'), findsOneWidget);
      expect(find.text('No estás disponible'), findsOneWidget);
      expect(
        find.text('Actívate arriba para tomar\nnuevas entregas.'),
        findsOneWidget,
      );
      // Ajuste: el pool se sigue listando (igual que en la web), pero no
      // deja tomar pedidos: el backend rechaza «Tomar entrega» con su
      // mensaje y nada pasa a «En curso».
      await tester.tap(find.text('Tomar entrega'));
      await tester.pumpAndSettle();
      expect(
        find.text('Activa tu disponibilidad en Perfil para aceptar entregas'),
        findsOneWidget,
      );
      expect(backend.api.llamo(ApiConstants.entregasAceptar), isTrue);
      expect(backend.entregas, isEmpty);
      expect(tarjetaEnCurso('PIER-41'), findsNothing);
      expect(tarjetaDelPool('PIER-41'), findsOneWidget);
      expect(find.text('No estás disponible'), findsOneWidget);
    });
  });
}
