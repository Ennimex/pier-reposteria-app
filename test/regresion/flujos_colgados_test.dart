// test/regresion/flujos_colgados_test.dart — regresión de #375: en el
// emulador de Android 10 del pipeline, a veces la GPU emulada no le
// responde a la app cuando se abre, Android la marca como «isn't
// responding» y flutter test la esperaba hasta que GitHub cancelaba el
// trabajo a los 40 min. tool/flujos_entorno_aislado.sh vigila, corta y
// vuelve a correr una vez lo que no terminó. Se prueba con un flutter y un
// adb falsos: el flutter falso se «cuelga» en el archivo que se le indica y
// el adb falso reporta la app «isn't responding» mientras siga abierta.
@Tags(['regresion'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/resumen/pruebas.dart';

/// El bash con que se ejecuta el script. En Windows, «bash» a secas abre el
/// de WSL (System32 se busca antes que el PATH): se usa el de Git for
/// Windows, el primero de `where bash` fuera de System32.
String _bash() {
  if (!Platform.isWindows) return 'bash';
  final encontrados = Process.runSync('where', ['bash']).stdout as String;
  return encontrados
      .split(RegExp(r'\r?\n'))
      .map((ruta) => ruta.trim())
      .firstWhere(
        (ruta) => ruta.isNotEmpty && !ruta.toLowerCase().contains('system32'),
        orElse: () => 'bash',
      );
}

/// flutter falso. Cada llamada lee su guion de `FALSO_n` (n = 1, 2…): qué
/// pasa con cada archivo, en orden: «pasa», «falla» o «cuelga» (escribe el
/// inicio, deja la marca de la app «isn't responding» y se queda dormido).
/// Anota en llamadas.txt los archivos que recibió.
const _flutterFalso = '#!/usr/bin/env bash$_cuerpoDelFlutter';
const _cuerpoDelFlutter = r'''
dir="$(cd "$(dirname "$0")" && pwd)"
n=$(( $(cat "$dir/n" 2> /dev/null || echo 0) + 1 ))
echo "$n" > "$dir/n"
eval "guion=(\${FALSO_$n})"
archivos=()
reporte=""
for argumento in "$@"; do
  case "$argumento" in
    *.dart) archivos+=("$argumento") ;;
    json:*) reporte="${argumento#json:}" ;;
  esac
done
echo "${archivos[*]}" >> "$dir/llamadas.txt"
exito=true
i=0
for archivo in "${archivos[@]}"; do
  i=$((i + 1))
  echo "corriendo $archivo"
  echo "{\"type\":\"suite\",\"suite\":{\"id\":$i,\"path\":\"/ci/$archivo\"}}" >> "$reporte"
  echo "{\"type\":\"testStart\",\"test\":{\"id\":$((i * 10)),\"name\":\"loading /ci/$archivo\",\"suiteID\":$i}}" >> "$reporte"
  case "${guion[$((i - 1))]}" in
    cuelga)
      touch "$dir/anr"
      exec sleep 120
      ;;
    falla) resultado=failure; exito=false ;;
    *) resultado=success ;;
  esac
  echo "{\"type\":\"testDone\",\"testID\":$((i * 10)),\"result\":\"success\",\"hidden\":true}" >> "$reporte"
  echo "{\"type\":\"testStart\",\"test\":{\"id\":$((i * 10 + 1)),\"name\":\"Escenario de $archivo\",\"suiteID\":$i}}" >> "$reporte"
  echo "{\"type\":\"testDone\",\"testID\":$((i * 10 + 1)),\"result\":\"$resultado\",\"hidden\":false}" >> "$reporte"
done
echo "{\"type\":\"done\",\"success\":$exito}" >> "$reporte"
[ "$exito" = true ]
''';

/// adb falso: la app sigue «isn't responding» hasta que la detienen.
const _adbFalso = '#!/usr/bin/env bash$_cuerpoDelAdb';
const _cuerpoDelAdb = r'''
dir="$(cd "$(dirname "$0")" && pwd)"
case "$*" in
  *dumpsys\ window*)
    if [ -f "$dir/anr" ]; then
      echo "  mCurrentFocus=Window{1 u0 Application Not Responding: mx.com.pierreposteria}"
    else
      echo "  mCurrentFocus=Window{1 u0 com.android.launcher3/.Launcher}"
    fi
    ;;
  *force-stop*) rm -f "$dir/anr" ;;
esac
''';

const _archivos = [
  'integration_test/flujos/compra_test.dart',
  'integration_test/flujos/catalogo_resena_test.dart',
  'integration_test/flujos/entrega_reembolso_test.dart',
];

/// Corre el script con los guiones [guiones] (uno por llamada a flutter).
Future<({int codigo, String salida, List<String> llamadas, Corrida reporte})>
    _correr(List<String> guiones) async {
  final carpeta = await Directory.systemTemp.createTemp('flujos_');
  addTearDown(() => carpeta.delete(recursive: true));
  final dir = carpeta.path.replaceAll(r'\', '/');
  // Sin «\r»: en Windows este archivo puede tener fin de renglón CRLF.
  File('$dir/flutter')
      .writeAsStringSync(_flutterFalso.replaceAll('\r\n', '\n'));
  File('$dir/adb').writeAsStringSync(_adbFalso.replaceAll('\r\n', '\n'));
  Process.runSync(_bash(), ['-c', 'chmod +x "$dir/flutter" "$dir/adb"']);

  final separador = Platform.isWindows ? ';' : ':';
  final resultado = await Process.run(
    _bash(),
    [
      'tool/flujos_entorno_aislado.sh',
      '$dir/reporte.json',
      'flutter',
      'test',
      ..._archivos,
      '--no-pub',
    ],
    environment: {
      'PATH': '${carpeta.path}$separador${Platform.environment['PATH']}',
      'VIGILANTE_INTERVALO': '1',
      for (final (i, guion) in guiones.indexed) 'FALSO_${i + 1}': guion,
    },
  );
  final llamadas = File('$dir/llamadas.txt').existsSync()
      ? File('$dir/llamadas.txt')
          .readAsLinesSync()
          .map((renglon) => renglon.trim())
          .toList()
      : <String>[];
  return (
    codigo: resultado.exitCode,
    salida: '${resultado.stdout}${resultado.stderr}',
    llamadas: llamadas,
    reporte: leerReporte(File('$dir/reporte.json').readAsStringSync()),
  );
}

/// Cómo quedó cada escenario del reporte, en orden.
List<EstadoPrueba> _escenarios(Corrida reporte) =>
    [for (final prueba in reporte.pruebas) prueba.estado];

/// En Windows, lanzado desde flutter test, el bash de Git se queda
/// esperando a los procesos que el script deja en segundo plano. El script
/// corre en el CI, en Linux, y ahí se prueba.
final Object _soloEnLinux = Platform.isWindows
    ? 'el script corre en el CI (Linux); en Windows bash se queda esperando'
    : false;

void main() {
  test('sin cuelgue corre los flujos una sola vez', () async {
    final r = await _correr(['pasa pasa pasa']);

    expect(r.codigo, 0, reason: r.salida);
    expect(r.llamadas, [_archivos.join(' ')]);
    expect(_escenarios(r.reporte), List.filled(3, EstadoPrueba.paso));
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _soloEnLinux);

  test('#375: si la app se cuelga al abrir, corta y vuelve a correr solo lo '
      'que no terminó', () async {
    final r = await _correr(['pasa cuelga', 'pasa pasa']);

    expect(r.codigo, 0, reason: r.salida);
    expect(r.llamadas, [_archivos.join(' '), _archivos.skip(1).join(' ')]);
    expect(r.salida, contains("«isn't responding»"));
    // El reporte junta los dos intentos y el resumen los lee completos.
    expect(_escenarios(r.reporte), List.filled(3, EstadoPrueba.paso));
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _soloEnLinux);

  test('una prueba que falló antes del corte hace fallar todo', () async {
    final r = await _correr(['falla cuelga', 'pasa pasa']);

    expect(r.codigo, 1, reason: r.salida);
    expect(_escenarios(r.reporte),
        [EstadoPrueba.fallo, EstadoPrueba.paso, EstadoPrueba.paso]);
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _soloEnLinux);

  test('si el reintento también se cuelga, termina con 124', () async {
    final r = await _correr(['cuelga', 'cuelga']);

    expect(r.codigo, 124, reason: r.salida);
    expect(r.llamadas, hasLength(2));
    expect(r.salida, contains('también se cortó en el reintento'));
  }, timeout: const Timeout(Duration(minutes: 1)), skip: _soloEnLinux);
}
