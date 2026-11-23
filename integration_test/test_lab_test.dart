// integration_test/test_lab_test.dart — entrada única para Firebase Test Lab
// (#81). Con -Ptarget= solo cabe un archivo por APK de prueba y cada
// combinación de modelo y versión gasta una corrida de la cuota del día, así
// que el smoke y el flujo principal van juntos. Los dos usan FakeApiClient:
// no tocan el backend ni datos reales. Ver tool/test_lab.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'aceptacion/flujo_principal_test.dart' as flujo_principal;
import 'app_smoke_test.dart' as smoke;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Cada archivo corre con la política de cuadros con la que corre solo: el
  // flujo principal la cambia a fullyLive al declararse y, sin esto, el smoke
  // la heredaría. El smoke va primero: el flujo principal deja una sesión
  // iniciada.
  group('Smoke', () {
    setUp(() => binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.fadePointers);
    smoke.main();
  });
  group('Flujo principal', () {
    setUp(() => binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.fullyLive);
    flujo_principal.main();
  });
}
