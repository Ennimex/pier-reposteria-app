// test/regresion/conteo_analisis_test.dart — regresión de #87: el control de
// análisis estático nunca bloqueaba un Pull Request, porque en Linux (el CI)
// flutter analyze separa los campos con «•» y el conteo solo reconocía el
// «-» de Windows. Ejecuta tool/contar_analisis.sh, el conteo que usa
// tool/check_analysis.sh, con una salida de cada formato.
@Tags(['regresion'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El bash con que se ejecuta el script. En Windows, «bash» a secas abre el
/// de WSL (System32 se busca antes que el PATH) y se queda esperando: se usa
/// el de Git for Windows, el primero de `where bash` fuera de System32.
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

/// Guarda [salida] en un archivo temporal y devuelve lo que imprime el
/// conteo: «errores advertencias avisos».
Future<String> _contar(String salida) async {
  final carpeta = await Directory.systemTemp.createTemp('analisis_');
  addTearDown(() => carpeta.delete(recursive: true));
  final archivo = File('${carpeta.path}/analisis.txt');
  await archivo.writeAsString(salida);

  final resultado = await Process.run(_bash(), [
    'tool/contar_analisis.sh',
    archivo.path,
  ]);

  expect(resultado.exitCode, 0, reason: '${resultado.stderr}');
  return (resultado.stdout as String).trim();
}

void main() {
  test('cuenta los hallazgos con el formato de Linux («•»)', () async {
    const salidaDeLinux = '''
Analyzing pier_reposteria...

warning • The value of the local variable 'sinUsar' isn't used • lib/utils/demo.dart:5:9 • unused_local_variable
   info • Use 'const' with the constructor to improve performance • lib/a.dart:3:7 • prefer_const_constructors
   info • Sort child properties last in widget instance creations • lib/b.dart:9:2 • sort_child_properties_last

3 issues found. (ran in 12.3s)
''';

    expect(await _contar(salidaDeLinux), '0 1 2');
  });

  test('cuenta también el formato de Windows («-»)', () async {
    const salidaDeWindows = '''
Analyzing pier_reposteria...

  error - Undefined name 'pastel' - lib/c.dart:2:3 - undefined_identifier
   info - Unnecessary use of 'unawaited' - test/d_test.dart:4:4 - unnecessary_unawaited

2 issues found. (ran in 9.1s)
''';

    expect(await _contar(salidaDeWindows), '1 0 1');
  });

  test('sin hallazgos imprime ceros y termina bien', () async {
    const salidaLimpia = '''
Analyzing pier_reposteria...
No issues found! (ran in 8.4s)
''';

    expect(await _contar(salidaLimpia), '0 0 0');
  });
}
