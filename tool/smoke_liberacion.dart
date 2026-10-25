// tool/smoke_liberacion.dart — corre el smoke del candidato de liberación
// en el emulador conectado por adb (release.yml, «Pruebas en el entorno de
// liberación»). El APK ya debe estar instalado. Los pasos y el resumen están
// en tool/resumen/smoke_liberacion.dart; aquí solo se habla con adb.
//
//   dart run tool/smoke_liberacion.dart <paquete> <carpeta> --app <nombre> \
//     --usuario <correo> --clave <contraseña> --producto <nombre> \
//     --saludo <texto>
//
// Deja en <carpeta> las capturas de cada paso (01_catalogo.png,
// 02_inicio_de_sesion.png, 03_sesion_iniciada.png; fallo.png y
// pantalla_fallo.xml si algo falla) y smoke_liberacion.json, y agrega la
// tabla al resumen de la corrida (GITHUB_STEP_SUMMARY). Termina con 1 si
// algún paso falló.
import 'dart:convert';
import 'dart:io';

import 'resumen/smoke_liberacion.dart';

const _uso = '''
Uso: dart run tool/smoke_liberacion.dart <paquete> <carpeta> --app <nombre>
  --usuario <correo> --clave <contraseña> --producto <nombre> --saludo <texto>''';

Future<void> main(List<String> argumentos) async {
  final posicionales = <String>[];
  final opciones = <String, String>{};
  for (var i = 0; i < argumentos.length; i++) {
    final argumento = argumentos[i];
    if (argumento.startsWith('--') && i + 1 < argumentos.length) {
      opciones[argumento.substring(2)] = argumentos[++i];
    } else {
      posicionales.add(argumento);
    }
  }
  const obligatorias = ['app', 'usuario', 'clave', 'producto', 'saludo'];
  if (posicionales.length != 2 || !obligatorias.every(opciones.containsKey)) {
    stderr.writeln(_uso);
    exitCode = 64;
    return;
  }

  final paquete = posicionales[0];
  final carpeta = Directory(posicionales[1])..createSync(recursive: true);
  final datos = DatosDelSmoke(
    nombreDeLaApp: opciones['app']!,
    usuario: opciones['usuario']!,
    clave: opciones['clave']!,
    producto: opciones['producto']!,
    saludo: opciones['saludo']!,
  );

  final reloj = Stopwatch()..start();
  final resultado = await correrSmoke(
    _EmuladorPorAdb(paquete: paquete, carpeta: carpeta.path),
    datos,
    transcurrido: () => reloj.elapsed,
    registrar: stdout.writeln,
  );

  // El reporte con cada paso y, si falló, la última pantalla que se leyó.
  File('${carpeta.path}/smoke_liberacion.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'paso': resultado.paso,
      'pasos': [for (final paso in resultado.pasos) paso.aJson()],
    }),
  );
  if (!resultado.paso) {
    File('${carpeta.path}/pantalla_fallo.xml')
        .writeAsStringSync(resultado.ultimaPantalla);
  }

  final resumen = resumenSmoke(resultado);
  stdout.writeln(resumen);
  final archivoDelResumen = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (archivoDelResumen != null && archivoDelResumen.isNotEmpty) {
    File(archivoDelResumen).writeAsStringSync(
      '$resumen\n',
      mode: FileMode.append,
    );
  }
  if (!resultado.paso) {
    final fallido = resultado.pasos.last;
    stderr.writeln('::error::Smoke del candidato: «${fallido.nombre}» '
        'falló: ${fallido.detalle}.');
    exitCode = 1;
  }
}

/// El emulador (o celular) conectado, manejado con adb.
class _EmuladorPorAdb implements Dispositivo {
  _EmuladorPorAdb({required this.paquete, required this.carpeta});

  final String paquete;
  final String carpeta;

  /// Dónde deja uiautomator su volcado dentro del emulador.
  static const _volcadoEnElEmulador = '/sdcard/smoke_pantalla.xml';

  Future<ProcessResult> _adb(List<String> argumentos, {bool bytes = false}) =>
      Process.run(
        'adb',
        argumentos,
        stdoutEncoding: bytes ? null : utf8,
        stderrEncoding: utf8,
      );

  @override
  Future<String> abrirApp() async {
    final salida = await _adb(
      ['shell', 'am', 'start', '-W', '-n', '$paquete/.MainActivity'],
    );
    final texto = (salida.stdout as String).replaceAll('\r', '');
    stdout.writeln(texto);
    return texto;
  }

  @override
  Future<String> volcarPantalla() async {
    final volcado = await _adb(
      ['shell', 'uiautomator', 'dump', _volcadoEnElEmulador],
    );
    // Mientras la app arranca, uiautomator a veces no logra leerla: la
    // pantalla cuenta como vacía y el smoke vuelve a intentar.
    if (volcado.exitCode != 0) return '';
    final contenido = await _adb(['exec-out', 'cat', _volcadoEnElEmulador]);
    return contenido.exitCode == 0 ? contenido.stdout as String : '';
  }

  @override
  Future<void> tocar(int x, int y) =>
      _adb(['shell', 'input', 'tap', '$x', '$y']);

  // Entre comillas simples para que el shell del emulador no interprete
  // nada del texto (la cuenta de la semilla no lleva comillas).
  @override
  Future<void> escribir(String texto) =>
      _adb(['shell', 'input', 'text', "'$texto'"]);

  @override
  Future<void> pulsarEnter() =>
      _adb(['shell', 'input', 'keyevent', 'KEYCODE_ENTER']);

  @override
  Future<void> guardarCaptura(String nombre) async {
    final captura = await _adb(['exec-out', 'screencap', '-p'], bytes: true);
    if (captura.exitCode != 0) return;
    File('$carpeta/$nombre.png').writeAsBytesSync(captura.stdout as List<int>);
  }

  @override
  Future<void> esperar(Duration tiempo) => Future<void>.delayed(tiempo);
}
