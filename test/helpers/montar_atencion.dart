// test/helpers/montar_atencion.dart — monta «Atención a clientes» (#138)
// con la sesión de un rol del personal sobre el backend falso (con
// montarComandas: pantalla alta y router con login), y atajos para cambiar
// de pestaña y tocar el botón principal del diálogo abierto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/atencion/widgets/atencion_clientes_screen.dart';

import '../fakes/fake_api_client.dart';
import 'montar_comandas.dart';

Future<void> montarAtencion(
  WidgetTester tester,
  FakeApiClient api, {
  String rol = 'empleado',
}) =>
    montarComandas(
      tester,
      api,
      pantalla: const AtencionClientesScreen(),
      rol: rol,
    );

/// Pasa a la pestaña [nombre] (Quejas, Reembolsos o Reseñas). Las pestañas
/// se recorren de lado si no caben: primero se trae a la vista.
Future<void> irAPestana(WidgetTester tester, String nombre) async {
  final pestana = find.widgetWithText(Tab, nombre);
  await tester.ensureVisible(pestana);
  await tester.pumpAndSettle();
  await tester.tap(pestana);
  await tester.pumpAndSettle();
}

/// El botón principal [texto] del diálogo abierto.
Finder botonDelDialogo(String texto) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, texto),
    );
