// test_driver/aceptacion_driver.dart — el lado de la computadora del flujo
// principal en el emulador (integration_test/aceptacion/flujo_principal_test.dart),
// que corre con:
//
//   flutter drive --driver=test_driver/aceptacion_driver.dart \
//     --target=integration_test/aceptacion/flujo_principal_test.dart
//
// Espera a que termine la prueba en el celular y guarda la evidencia:
//   · build/resultados/capturas/<paso>.png, una captura por paso;
//   · build/resultados/aceptacion_emulador.json, el reporte: si pasó, los
//     pasos con sus segundos, las capturas y, si falló, el detalle.
// Termina con 1 si la prueba falló, así flutter drive (y el paso del
// workflow) también fallan.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

const _carpetaDeResultados = 'build/resultados';
const _carpetaDeCapturas = '$_carpetaDeResultados/capturas';
const _reporte = '$_carpetaDeResultados/aceptacion_emulador.json';

/// Lo más que se espera a que termine la prueba en el celular.
const _limite = Duration(minutes: 10);

Future<void> main() async {
  final conexion = await FlutterDriver.connect();
  final respuestaEnJson = await conexion.requestData(null, timeout: _limite);
  await conexion.close();

  final respuesta = Response.fromJson(respuestaEnJson);
  final datos = respuesta.data ?? const <String, dynamic>{};
  final capturas = await _guardarCapturas(datos['screenshots']);
  final fallas = respuesta.failureDetails ?? const <Failure>[];

  final reporte = <String, dynamic>{
    'escenario': 'Flujo principal #34 → #35 → #36: del inicio de sesión al '
        'checkout',
    'aprobado': respuesta.allTestsPassed,
    'pasos': datos['pasos'] ?? const <dynamic>[],
    'capturas': capturas,
    'fallas': [
      for (final falla in fallas)
        {'prueba': falla.methodName, 'detalle': falla.details},
    ],
  };
  final archivoDelReporte = File(_reporte);
  await archivoDelReporte.create(recursive: true);
  await archivoDelReporte.writeAsString(
    const JsonEncoder.withIndent('  ').convert(reporte),
  );

  stdout
    ..writeln('Reporte: $_reporte (${capturas.length} capturas)')
    ..writeln(respuesta.allTestsPassed
        ? 'El flujo principal pasó.'
        : 'El flujo principal falló:\n${respuesta.formattedFailureDetails}');
  exit(respuesta.allTestsPassed ? 0 : 1);
}

/// Guarda cada captura que tomó la prueba (binding.takeScreenshot) como PNG
/// y devuelve sus rutas, en el orden en que se tomaron.
Future<List<String>> _guardarCapturas(Object? capturas) async {
  final rutas = <String>[];
  for (final captura in (capturas as List<dynamic>?) ?? const <dynamic>[]) {
    final datos = captura as Map<String, dynamic>;
    final nombre = datos['screenshotName'] as String;
    final bytes = (datos['bytes'] as List<dynamic>).cast<int>();
    final archivo = File('$_carpetaDeCapturas/$nombre.png');
    await archivo.create(recursive: true);
    await archivo.writeAsBytes(bytes);
    rutas.add(archivo.path);
  }
  return rutas;
}
