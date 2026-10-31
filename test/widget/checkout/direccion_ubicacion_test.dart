// test/widget/checkout/direccion_ubicacion_test.dart — #227: antes de pedir
// la ubicación la hoja explica para qué; con «Ahora no» no se pide nada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_reposteria/data/services/ubicacion_service.dart';
import 'package:pier_reposteria/ui/checkout/view_model/direccion_form_view_model.dart';
import 'package:pier_reposteria/ui/checkout/widgets/direccion_form_sheet.dart';
import 'package:pier_reposteria/ui/core/ui/explicacion_permiso.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

class _UbicadorFalso implements Ubicador {
  _UbicadorFalso(this.resultado);

  final ResultadoUbicacion resultado;
  int lecturas = 0;
  int ajustes = 0;

  @override
  Future<ResultadoUbicacion> ubicacionActual() async {
    lecturas++;
    return resultado;
  }

  @override
  Future<bool> abrirAjustes() async {
    ajustes++;
    return true;
  }
}

Future<void> _montar(WidgetTester tester, _UbicadorFalso ubicador) async {
  final api = FakeApiClient();
  await tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(
        child: DireccionFormSheet(
          viewModel: DireccionFormViewModel(
            repo: DireccionesRepositoryRemote(api: api),
            ubicador: ubicador,
          ),
        ),
      ),
    ),
    api: api,
  );
  await tester.pumpAndSettle();
}

Future<void> _tocarUsarUbicacion(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Usar mi ubicación'));
  await tester.tap(find.text('Usar mi ubicación'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explica para qué y con «Continuar» agrega la ubicación',
      (tester) async {
    final ubicador = _UbicadorFalso(
        const ResultadoUbicacion(EstadoUbicacion.lista, lat: 21.1, lng: -98.4));
    await _montar(tester, ubicador);

    await _tocarUsarUbicacion(tester);
    expect(find.text(ExplicacionDePermiso.ubicacion.titulo), findsOneWidget);
    expect(find.text(ExplicacionDePermiso.ubicacion.mensaje), findsOneWidget);
    expect(ubicador.lecturas, 0, reason: 'todavía no se pide el permiso');

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(ubicador.lecturas, 1);
    expect(find.text('Ubicación agregada'), findsOneWidget);
  });

  testWidgets('con «Ahora no» no se pide el permiso', (tester) async {
    final ubicador = _UbicadorFalso(
        const ResultadoUbicacion(EstadoUbicacion.lista, lat: 1, lng: 2));
    await _montar(tester, ubicador);

    await _tocarUsarUbicacion(tester);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(ubicador.lecturas, 0);
    expect(find.text('Usar mi ubicación'), findsOneWidget);
  });

  testWidgets('negado para siempre ofrece abrir los Ajustes', (tester) async {
    final ubicador = _UbicadorFalso(
        const ResultadoUbicacion(EstadoUbicacion.sinPermisoParaSiempre));
    await _montar(tester, ubicador);

    await _tocarUsarUbicacion(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Puedes darlo en Ajustes'), findsOneWidget);
    await tester.ensureVisible(find.text('Abrir Ajustes'));
    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(ubicador.ajustes, 1);
  });
}
