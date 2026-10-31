// test/widget/atencion/resenas_personal_tab_test.dart — la pestaña «Reseñas»
// de Atención a clientes (#138) sin red: la tarjeta de cada reseña con sus
// estrellas (para el lector de pantalla) y marcas, las pendientes primero,
// aprobar, responder como Pier Repostería, rechazar con motivo y cancelar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';

import '../../fakes/atencion_json.dart';
import '../../helpers/montar_atencion.dart';

/// Las estrellas que anuncian «N de 5 estrellas».
Finder _estrellas(int n) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '$n de 5 estrellas',
    );

void main() {
  group('ResenasPersonalTab', () {
    testWidgets('cada reseña con producto, autor, estrellas y marcas',
        (tester) async {
      await montarAtencion(tester, backendAtencion());
      await irAPestana(tester, 'Reseñas');

      expect(
        find.text('Calificación baja (menos de 4 estrellas): requiere revisión'),
        findsOneWidget,
      );
      expect(find.text('Rosa Díaz'), findsNWidgets(4));
      expect(_estrellas(2), findsOneWidget);
      expect(_estrellas(5), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
      expect(find.text('Aprobada automáticamente'), findsOneWidget);
      expect(find.text('Compra verificada'), findsNWidgets(3));
      expect(find.text('Respuesta de Pier Repostería'), findsOneWidget);
      expect(find.text('Gracias & vuelve pronto'), findsOneWidget);
      expect(find.text('Motivo del rechazo'), findsOneWidget);
      expect(find.text('Lenguaje inapropiado en el texto'), findsOneWidget);
      double arriba(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('resena-$id'))).dy;
      expect(arriba('9'), lessThan(arriba('7')));
    });

    testWidgets('aprobar una pendiente y responder una aprobada',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.moderarResena('9'), {'success': true})
        ..responder(ApiConstants.moderarResena('7'), {'success': true});
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reseñas');

      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('De Rosa Díaz · Chocoflan'), findsOneWidget);
      expect(find.text('Se verá públicamente en la página del producto.'),
          findsOneWidget);
      await tester.tap(botonDelDialogo('Aprobar'));
      await tester.pumpAndSettle();
      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'estado': 'aprobada'});
      expect(find.text('Reseña aprobada'), findsOneWidget);

      await tester.tap(find.text('Responder como Pier Repostería'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ok');
      await tester.tap(botonDelDialogo('Publicar respuesta'));
      await tester.pumpAndSettle();
      expect(find.text('La respuesta debe tener al menos 5 caracteres.'),
          findsOneWidget);

      await tester.enterText(
          find.byType(TextField), '¡Gracias por tu preferencia!');
      await tester.tap(botonDelDialogo('Publicar respuesta'));
      await tester.pumpAndSettle();
      expect(api.ultima(ApiConstants.moderarResena('7'))!.body,
          {'respuesta_negocio': '¡Gracias por tu preferencia!'});
      expect(find.text('Respuesta publicada'), findsOneWidget);
    });

    testWidgets('rechazar pide el motivo; cancelar no cambia nada',
        (tester) async {
      final api = backendAtencion()
        ..responder(ApiConstants.moderarResena('9'), {'success': true});
      await montarAtencion(tester, api);
      await irAPestana(tester, 'Reseñas');

      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('«El pan estaba duro»'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.llamo(ApiConstants.moderarResena('9')), isFalse);

      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Feo');
      await tester.tap(botonDelDialogo('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('El motivo debe tener al menos 10 caracteres.'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Lenguaje ofensivo');
      await tester.tap(botonDelDialogo('Rechazar'));
      await tester.pumpAndSettle();

      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'estado': 'rechazada', 'motivo_rechazo': 'Lenguaje ofensivo'});
      expect(find.text('Reseña rechazada'), findsOneWidget);
    });
  });
}
