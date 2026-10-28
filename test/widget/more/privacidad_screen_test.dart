// test/widget/more/privacidad_screen_test.dart — «Privacidad» (#223): los
// interruptores de oposición se guardan en el teléfono y apagar los
// diagnósticos se aplica en el momento.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/services/preferencias_service.dart';
import 'package:pier_reposteria/ui/more/view_model/privacidad_view_model.dart';
import 'package:pier_reposteria/ui/more/widgets/privacidad_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

bool _valor(WidgetTester tester, String titulo) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, titulo))
    .value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Monitoreo.diagnosticosPermitidos = true);

  testWidgets('empieza con todo encendido y explica cada interruptor',
      (tester) async {
    await tester.pumpApp(const PrivacidadScreen());
    await tester.pumpAndSettle();

    expect(_valor(tester, PrivacidadScreen.diagnosticos), isTrue);
    expect(_valor(tester, PrivacidadScreen.busquedas), isTrue);
    expect(find.text(PrivacidadScreen.diagnosticosDetalle), findsOneWidget);
    expect(find.text(PrivacidadScreen.busquedasDetalle), findsOneWidget);
  });

  testWidgets('apagar los diagnósticos se guarda y se aplica en el momento',
      (tester) async {
    await tester.pumpApp(const PrivacidadScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text(PrivacidadScreen.diagnosticos));
    await tester.pumpAndSettle();

    expect(_valor(tester, PrivacidadScreen.diagnosticos), isFalse);
    expect(Monitoreo.diagnosticosPermitidos, isFalse);
    expect(await PreferenciasService().enviaDiagnosticos(), isFalse);
    expect(await PreferenciasService().registraBusquedas(), isTrue);
  });

  testWidgets('apagar las búsquedas se guarda', (tester) async {
    await tester.pumpApp(const PrivacidadScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text(PrivacidadScreen.busquedas));
    await tester.pumpAndSettle();

    expect(_valor(tester, PrivacidadScreen.busquedas), isFalse);
    expect(await PreferenciasService().registraBusquedas(), isFalse);
  });

  testWidgets('al volver muestra lo que se eligió antes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pierreposteria_enviar_diagnosticos': false,
      'pierreposteria_registrar_busquedas': false,
    });

    await tester.pumpApp(const PrivacidadScreen());
    await tester.pumpAndSettle();

    expect(_valor(tester, PrivacidadScreen.diagnosticos), isFalse);
    expect(_valor(tester, PrivacidadScreen.busquedas), isFalse);
  });

  testWidgets('lleva al Aviso de Privacidad', (tester) async {
    await tester.pumpApp(const PrivacidadScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leer el Aviso de Privacidad'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalScreen), findsOneWidget);
  });

  test('si la pantalla se cierra mientras carga no avisa', () async {
    final vm = PrivacidadViewModel();
    var avisos = 0;
    vm.addListener(() => avisos++);

    final carga = vm.cargar();
    vm.dispose();
    await carga;

    expect(avisos, 0);
  });
}
