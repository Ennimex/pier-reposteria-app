// test_driver/perf_driver.dart — #61: recibe las trazas de
// integration_test/rendimiento/rendimiento_test.dart (una por traceAction) y
// escribe, por cada medición, build/<medición>.timeline_summary.json con el
// tiempo por cuadro. `dart run tool/resumen_pruebas.dart tiempos` las junta
// en una tabla.
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (datos) async {
    if (datos == null) return;
    for (final MapEntry(:key, :value) in datos.entries) {
      final traza = driver.Timeline.fromJson(value as Map<String, dynamic>);
      await driver.TimelineSummary.summarize(
        traza,
      ).writeTimelineToFile(key, pretty: true);
    }
  },
);
