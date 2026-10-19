// tool/resumen/cli.dart — comandos de tool/resumen_pruebas.dart (#157).
// Cada comando lee lo que dejó un paso del workflow, escribe el resumen en
// la salida (queda en el log) y lo agrega al archivo de GITHUB_STEP_SUMMARY,
// que GitHub muestra en la página de la corrida (pestaña Summary).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'analisis.dart';
import 'cobertura.dart';
import 'esfuerzo.dart';
import 'markdown.dart';
import 'pruebas.dart';
import 'regresion.dart';
import 'release.dart';
import 'rendimiento.dart';

// Archivos que dejan los pasos de los workflows.
const _rutaAnalisis = 'build/resultados/analisis.txt';
const _rutaLineaBase = 'tool/check_analysis.sh';
const _rutaIntegracion = 'build/resultados/integracion.json';
const _rutaSuite = 'build/resultados/suite.json';
const _rutaCobertura = 'coverage/lcov.info';
const _carpetaApk = 'build/app/outputs/flutter-apk';

const _uso = '''
Uso: dart run tool/resumen_pruebas.dart <comando> [opciones]

Comandos:
  pruebas <reporte.json> --titulo <texto> [--detalle] [--cobertura <lcov.info>]
      Reporte de flutter test --file-reporter json:<reporte.json>. Con
      --detalle lista cada prueba agrupada por historia.
  analisis [salida.txt]
      Salida de flutter analyze que guarda tool/check_analysis.sh (por
      omisión $_rutaAnalisis) contra su línea base.
  peso [app-release.apk] [apk-code-size-analysis.json]
      Peso del APK de flutter build apk --analyze-size (busca el APK en
      $_carpetaApk y el desglose en ~/.flutter-devtools/).
  tiempos [carpeta]
      Archivos *.timeline_summary.json de flutter drive (por omisión build/).
  monkey <monkey.txt> [logcat.txt]
      Bitácora de adb shell monkey -v y, si hubo fallas, errores de logcat.
  regresion --integracion <r> --analisis <r> --suite <r> --apk <r>
      Tabla de etapas de regresion.yml; <r> es steps.<id>.outcome (success,
      failure, skipped o cancelled).
  version <tag>
      Comprueba que el tag (vX.Y.Z) sea la versión de pubspec.yaml.
  notas <tag> <commits.txt>
      Notas de la Release a partir de git log --format=%s desde el tag
      anterior.
''';

/// Devuelve el código de salida: 0 aunque las pruebas hayan fallado (eso ya
/// lo marca su propio paso); 1 si falta la línea base, si el tag no es la
/// versión del pubspec o si falta la lista de commits; 64 si el comando está
/// mal escrito.
int ejecutar(
  List<String> argumentos, {
  required String raiz,
  required Map<String, String> entorno,
  required StringSink salida,
}) {
  final opciones = _Argumentos(argumentos);
  final archivos = _Archivos(raiz);
  final resultado = switch (opciones.posicional(0)) {
    'pruebas' => _pruebas(opciones, archivos),
    'analisis' => _analisis(opciones, archivos),
    'peso' => _peso(opciones, archivos, entorno),
    'tiempos' => _tiempos(opciones, archivos),
    'monkey' => _monkey(opciones, archivos),
    'regresion' => _regresion(opciones, archivos, entorno),
    'version' => _version(opciones, archivos),
    'notas' => _notas(opciones, archivos),
    _ => null,
  };
  if (resultado == null) {
    salida.write(_uso);
    return 64;
  }

  final (texto, codigo) = resultado;
  salida.write(texto);
  final resumen = entorno['GITHUB_STEP_SUMMARY'] ?? '';
  if (resumen.isNotEmpty) {
    File(resumen).writeAsStringSync('$texto\n', mode: FileMode.append);
  }
  return codigo;
}

(String, int)? _pruebas(_Argumentos opciones, _Archivos archivos) {
  final reporte = opciones.posicional(1);
  final titulo = opciones.valores['titulo'];
  if (reporte == null || titulo == null) return null;
  final contenido = archivos.leer(reporte);
  if (contenido == null) {
    return (
      '### 🧪 $titulo\n\n> ⚠️ No se generó el reporte de pruebas '
          '(`$reporte`): el paso falló antes de correrlas. Revisa el log del '
          'paso.\n',
      0,
    );
  }
  final texto = StringBuffer(
    resumenPruebas(
      leerReporte(contenido, raiz: archivos.raiz),
      titulo: titulo,
      detalle: opciones.banderas.contains('detalle'),
    ),
  );
  final lcov = opciones.valores['cobertura'];
  if (lcov != null) {
    texto.write(resumenCobertura(leerLcov(archivos.leer(lcov) ?? '')));
  }
  return (texto.toString(), 0);
}

(String, int) _analisis(_Argumentos opciones, _Archivos archivos) {
  const titulo = '### 🔍 Análisis estático (flutter analyze)\n\n';
  final base = leerLineaBase(archivos.leer(_rutaLineaBase) ?? '');
  if (base == null) {
    return (
      '$titulo> ❌ No se encontró la línea base en `$_rutaLineaBase` '
          '(baseline_errors, baseline_warnings y baseline_infos).\n',
      1,
    );
  }
  final ruta = opciones.posicional(1) ?? _rutaAnalisis;
  final salida = archivos.leer(ruta);
  if (salida == null) {
    return (
      '$titulo> ⚠️ No se generó la salida de flutter analyze (`$ruta`): '
          'revisa el log del paso.\n',
      0,
    );
  }
  final texto = resumenAnalisis(leerAnalisis(salida), base);
  // flutter analyze siempre cierra con «N issues found» o «No issues
  // found!»; sin esa línea se cayó a la mitad y el conteo no es confiable.
  if (RegExp('issues? found').hasMatch(salida)) return (texto, 0);
  return (
    texto.replaceFirst(
      titulo,
      '$titulo> ⚠️ La salida de flutter analyze está incompleta (no trae el '
      'conteo final): revisa el log del paso.\n\n',
    ),
    0,
  );
}

(String, int) _peso(
  _Argumentos opciones,
  _Archivos archivos,
  Map<String, String> entorno,
) {
  final rutaApk = opciones.posicional(1);
  final apk = rutaApk != null
      ? archivos.archivo(rutaApk)
      : archivos.buscar(_carpetaApk, (nombre) => nombre.endsWith('-release.apk'));
  if (apk == null || !apk.existsSync()) {
    return (
      '### 📦 Peso del APK de release\n\n> ⚠️ No se encontró el APK de '
          'release en `$_carpetaApk`: revisa el log del paso.\n',
      0,
    );
  }
  // flutter build --analyze-size escribe el desglose en
  // ~/.flutter-devtools/apk-code-size-analysis_NN.json (android/gradle.dart
  // de flutter_tools); NN crece en cada compilación: se toma el último.
  bool esDesglose(String nombre) =>
      nombre.startsWith('apk-code-size-analysis_') && nombre.endsWith('.json');
  final casa = entorno['HOME'] ?? entorno['USERPROFILE'];
  final rutaJson = opciones.posicional(2);
  final json = rutaJson != null
      ? archivos.archivo(rutaJson)
      : (casa == null
              ? null
              : archivos.buscar(
                  '$casa/.flutter-devtools',
                  esDesglose,
                  ultimo: true,
                )) ??
          archivos.buscar('build', esDesglose, ultimo: true);
  final datos = json == null ? null : archivos.leerJson(json.path);
  return (
    resumenPeso(
      apk: _nombreDe(apk.path),
      bytes: apk.lengthSync(),
      analisis: datos == null ? null : leerAnalisisDePeso(datos),
    ),
    0,
  );
}

(String, int) _tiempos(_Argumentos opciones, _Archivos archivos) {
  const sufijo = '.timeline_summary.json';
  final carpeta = archivos.carpeta(opciones.posicional(1) ?? 'build');
  final rutas = carpeta.existsSync()
      ? (carpeta
              .listSync()
              .whereType<File>()
              .map((archivo) => archivo.path)
              .where((ruta) => ruta.endsWith(sufijo))
              .toList()
            ..sort())
      : <String>[];
  final mediciones = <String, Map<String, dynamic>>{};
  for (final ruta in rutas) {
    final datos = archivos.leerJson(ruta);
    if (datos == null) continue;
    final nombre = _nombreDe(ruta);
    mediciones[nombre.substring(0, nombre.length - sufijo.length)] = datos;
  }
  return (resumenTiempos(mediciones), 0);
}

(String, int)? _monkey(_Argumentos opciones, _Archivos archivos) {
  final ruta = opciones.posicional(1);
  if (ruta == null) return null;
  final bitacora = archivos.leer(ruta);
  if (bitacora == null) {
    return (
      '### 🐒 Uso aleatorio (monkey)\n\n> ⚠️ No se generó la bitácora de '
          'monkey (`$ruta`): el emulador no arrancó o el paso falló antes. '
          'Revisa el log del paso.\n',
      0,
    );
  }
  final logcat = opciones.posicional(2);
  return (
    resumenMonkey(
      leerMonkey(bitacora),
      logcat: logcat == null ? '' : archivos.leer(logcat) ?? '',
    ),
    0,
  );
}

(String, int)? _regresion(
  _Argumentos opciones,
  _Archivos archivos,
  Map<String, String> entorno,
) {
  final integracion = opciones.valores['integracion'];
  final analisis = opciones.valores['analisis'];
  final suite = opciones.valores['suite'];
  final apk = opciones.valores['apk'];
  if (integracion == null || analisis == null || suite == null || apk == null) {
    return null;
  }
  // Una etapa que no corrió puede haber dejado archivos de una corrida vieja.
  bool corrio(String resultado) =>
      resultado == 'success' || resultado == 'failure';

  final pruebasDeIntegracion =
      corrio(integracion) ? archivos.corrida(_rutaIntegracion) : null;
  final pruebasDeLaSuite = corrio(suite) ? archivos.corrida(_rutaSuite) : null;

  String? lineaDeAnalisis;
  final base = leerLineaBase(archivos.leer(_rutaLineaBase) ?? '');
  final salidaDeAnalisis = archivos.leer(_rutaAnalisis);
  if (corrio(analisis) && base != null && salidaDeAnalisis != null) {
    lineaDeAnalisis = lineaAnalisis(leerAnalisis(salidaDeAnalisis), base);
  }

  String? lineaDeLaSuite;
  if (pruebasDeLaSuite != null) {
    final lcov = archivos.leer(_rutaCobertura);
    lineaDeLaSuite = lcov == null
        ? lineaPruebas(pruebasDeLaSuite)
        : '${lineaPruebas(pruebasDeLaSuite)} · ${lineaCobertura(leerLcov(lcov))}';
  }

  String? lineaDelApk;
  final archivoApk = apk == 'success'
      ? archivos.buscar(_carpetaApk, (nombre) => nombre.endsWith('-debug.apk'))
      : null;
  if (archivoApk != null) {
    lineaDelApk = '✅ ${tamano(archivoApk.lengthSync())}, guardado en Artifacts';
  }

  final rama = entorno['GITHUB_REF_NAME'];
  final commit = entorno['GITHUB_SHA'];
  return (
    resumenRegresion(
      [
        Etapa(
          nombre: 'Integración en el emulador',
          resultado: integracion,
          linea: pruebasDeIntegracion == null
              ? null
              : lineaPruebas(pruebasDeIntegracion),
        ),
        Etapa(
          nombre: 'Análisis estático',
          resultado: analisis,
          linea: lineaDeAnalisis,
        ),
        Etapa(
          nombre: 'Unitarias, de widget y de aceptación',
          resultado: suite,
          linea: lineaDeLaSuite,
        ),
        Etapa(nombre: 'APK de depuración', resultado: apk, linea: lineaDelApk),
      ],
      version: rama == null || commit == null
          ? ''
          : 'Versión `$rama` · commit '
              '`${commit.substring(0, min(7, commit.length))}`',
      corridas: [?pruebasDeIntegracion, ?pruebasDeLaSuite],
    ),
    0,
  );
}

(String, int)? _version(_Argumentos opciones, _Archivos archivos) {
  final tag = opciones.posicional(1);
  if (tag == null) return null;
  const titulo = '### 🏷️ Versión\n\n';
  final error = diferenciaDeVersion(tag, archivos.leer('pubspec.yaml') ?? '');
  if (error != null) return ('$titulo> ❌ $error\n', 1);
  return ('$titulo✅ El tag `$tag` es la versión de pubspec.yaml.\n', 0);
}

(String, int)? _notas(_Argumentos opciones, _Archivos archivos) {
  final tag = opciones.posicional(1);
  final ruta = opciones.posicional(2);
  if (tag == null || ruta == null) return null;
  final commits = archivos.leer(ruta);
  if (commits == null) {
    return (
      '### 📝 Notas de la versión\n\n> ❌ No se generó la lista de commits '
          '(`$ruta`): revisa el log del paso.\n',
      1,
    );
  }
  return (notasDeRelease(tag, commits.split('\n')), 0);
}

String _nombreDe(String ruta) => ruta.replaceAll(r'\', '/').split('/').last;

/// Argumentos de la línea de comandos: posicionales, `--opcion valor` y las
/// banderas sin valor (--detalle).
class _Argumentos {
  _Argumentos(List<String> argumentos) {
    for (var i = 0; i < argumentos.length; i++) {
      final argumento = argumentos[i];
      if (!argumento.startsWith('--')) {
        _posicionales.add(argumento);
        continue;
      }
      final nombre = argumento.substring(2);
      if (_banderasConocidas.contains(nombre) || i + 1 == argumentos.length) {
        banderas.add(nombre);
      } else {
        valores[nombre] = argumentos[++i];
      }
    }
  }

  static const _banderasConocidas = {'detalle'};

  final _posicionales = <String>[];
  final valores = <String, String>{};
  final banderas = <String>{};

  String? posicional(int indice) => _posicionales.elementAtOrNull(indice);
}

/// Rutas relativas a la carpeta del repositorio.
class _Archivos {
  const _Archivos(this.raiz);

  final String raiz;

  File archivo(String ruta) => File(_completa(ruta));

  Directory carpeta(String ruta) => Directory(_completa(ruta));

  /// Contenido del archivo o null si no existe. Las bitácoras de Android
  /// pueden traer bytes que no son UTF-8: se reemplazan en vez de fallar.
  String? leer(String ruta) {
    final archivo = this.archivo(ruta);
    if (!archivo.existsSync()) return null;
    return archivo.readAsStringSync(
      encoding: const Utf8Codec(allowMalformed: true),
    );
  }

  Map<String, dynamic>? leerJson(String ruta) {
    final contenido = leer(ruta);
    if (contenido == null) return null;
    try {
      final datos = jsonDecode(contenido);
      return datos is Map<String, dynamic> ? datos : null;
    } on FormatException {
      return null;
    }
  }

  Corrida? corrida(String ruta) {
    final contenido = leer(ruta);
    return contenido == null ? null : leerReporte(contenido, raiz: raiz);
  }

  /// Primer archivo de [ruta] (en orden alfabético) cuyo nombre cumple
  /// [condicion]; con [ultimo], el último.
  File? buscar(
    String ruta,
    bool Function(String nombre) condicion, {
    bool ultimo = false,
  }) {
    final carpeta = this.carpeta(ruta);
    if (!carpeta.existsSync()) return null;
    final archivos = carpeta
        .listSync()
        .whereType<File>()
        .where((archivo) => condicion(_nombreDe(archivo.path)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return ultimo ? archivos.lastOrNull : archivos.firstOrNull;
  }

  String _completa(String ruta) {
    final absoluta =
        ruta.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(ruta);
    return absoluta ? ruta : '$raiz/$ruta';
  }
}
