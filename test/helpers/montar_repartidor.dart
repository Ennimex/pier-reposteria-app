// test/helpers/montar_repartidor.dart — abre el panel del repartidor
// (RepartidorMainScreen, que arma su ViewModel con el EntregasRepository de
// dependencies.dart) con la sesión del repartidor iniciada sobre
// BackendEntregas, y reúne los atajos del panel que usan las pruebas de
// aceptación de las historias #45 y #46 (#68).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/entregas_tarjetas.dart';
import 'package:pier_reposteria/ui/repartidor/widgets/repartidor_main_screen.dart';

import '../fakes/entregas_json.dart';
import 'pump_app.dart';

/// Monta el panel en un celular (412×869 lógicos, como el Note 10+), inicia
/// la sesión del repartidor y espera a que termine la primera carga.
Future<void> abrirPanelRepartidor(
  WidgetTester tester,
  BackendEntregas backend,
) async {
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const RepartidorMainScreen(), api: backend.api);
  await tester.iniciarSesion(find.byType(RepartidorMainScreen));
  await tester.pumpAndSettle();
}

/// Cambia de pestaña con la barra de abajo (Entregas, Historial o Perfil).
Future<void> irAPestana(WidgetTester tester, String pestana) async {
  await tester.tap(find.text(pestana).last);
  await tester.pumpAndSettle();
}

/// Jala «Mis entregas» hacia abajo para volver a pedir las entregas.
Future<void> recargarEntregas(WidgetTester tester) async {
  await tester.fling(
    find.text('Disponible para entregas'),
    const Offset(0, 400),
    1000,
  );
  await tester.pumpAndSettle();
}

/// La tarjeta del pool (la de «Tomar entrega») del pedido [numero].
Finder tarjetaDelPool(String numero) => find.ancestor(
  of: find.text(numero),
  matching: find.byType(DisponibleCard),
);

/// La tarjeta de «En curso» de la entrega [numero].
Finder tarjetaEnCurso(String numero) => find.ancestor(
  of: find.text(numero),
  matching: find.byType(EntregaCard),
);
