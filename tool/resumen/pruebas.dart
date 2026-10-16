// tool/resumen/pruebas.dart — lee el reporte JSON que escribe
// `flutter test --file-reporter json:<archivo>` y arma su resumen en
// Markdown (#157). Formato de los eventos: protocolo JSON de package:test.
import 'dart:convert';

import 'markdown.dart';

enum EstadoPrueba { paso, fallo, omitida }

class Prueba {
  const Prueba({
    required this.nombre,
    required this.grupo,
    required this.archivo,
    required this.estado,
    this.linea,
    this.detalle = '',
  });

  /// Nombre sin el del grupo: «Escenario: credenciales válidas».
  final String nombre;

  /// Grupo de primer nivel (la historia); si no hay, el archivo.
  final String grupo;

  /// Ruta relativa al repositorio: test/aceptacion/auth/x_test.dart.
  final String archivo;
  final EstadoPrueba estado;

  /// Línea donde se declara la prueba (test o testWidgets).
  final int? linea;

  /// Error de la prueba que falló o motivo de la omitida.
  final String detalle;

  String get ubicacion => linea == null ? archivo : '$archivo:$linea';

  String get titulo => grupo == archivo ? nombre : '$grupo › $nombre';
}

class Corrida {
  const Corrida({
    required this.pruebas,
    required this.termino,
    required this.exito,
    this.duracion,
  });

  final List<Prueba> pruebas;

  /// Llegó el evento final; si no, la corrida se canceló o se cayó.
  final bool termino;
  final bool exito;
  final Duration? duracion;

  int get pasaron => _contar(EstadoPrueba.paso);
  int get fallaron => _contar(EstadoPrueba.fallo);
  int get omitidas => _contar(EstadoPrueba.omitida);

  int _contar(EstadoPrueba estado) =>
      pruebas.where((prueba) => prueba.estado == estado).length;
}

const _maximoDeRenglones = 30;
const _maximoDeFallas = 20;

/// Interpreta el reporte. [raiz] es la carpeta del repositorio, para dejar
/// las rutas relativas; sin ella se recortan desde test/ o integration_test/.
Corrida leerReporte(String contenido, {String raiz = ''}) {
  final suites = <int, String>{};
  final grupos = <int, String>{};
  final inicios = <int, Map<String, dynamic>>{};
  final errores = <int, List<String>>{};
  final impresos = <int, List<String>>{};
  final omisiones = <int, String>{};
  final pruebas = <Prueba>[];
  var termino = false;
  var exito = false;
  Duration? tiempo;

  for (final evento in _eventos(contenido)) {
    switch (evento['type']) {
      case 'suite':
        final suite = evento['suite'] as Map<String, dynamic>;
        suites[suite['id'] as int] = suite['path'] as String? ?? '';
      case 'group':
        final grupo = evento['group'] as Map<String, dynamic>;
        grupos[grupo['id'] as int] = grupo['name'] as String? ?? '';
      case 'testStart':
        final prueba = evento['test'] as Map<String, dynamic>;
        inicios[prueba['id'] as int] = prueba;
      case 'error':
        errores
            .putIfAbsent(evento['testID'] as int, () => [])
            .add(evento['error'] as String? ?? '');
      case 'print':
        final id = evento['testID'] as int;
        final mensaje = evento['message'] as String? ?? '';
        if (evento['messageType'] == 'skip') {
          omisiones[id] = mensaje.replaceFirst('Skip: ', '');
        } else {
          impresos.putIfAbsent(id, () => []).add(mensaje);
        }
      case 'testDone':
        final inicio = inicios[evento['testID'] as int];
        if (evento['hidden'] != true && inicio != null) {
          final id = inicio['id'] as int;
          final estado = evento['skipped'] == true
              ? EstadoPrueba.omitida
              : evento['result'] == 'success'
                  ? EstadoPrueba.paso
                  : EstadoPrueba.fallo;
          pruebas.add(
            _prueba(
              inicio,
              estado: estado,
              rutaSuite: suites[inicio['suiteID']] ?? '',
              raiz: raiz,
              grupos: grupos,
              detalle: switch (estado) {
                EstadoPrueba.paso => '',
                EstadoPrueba.omitida =>
                  omisiones[id] ?? _motivoDeOmision(inicio),
                EstadoPrueba.fallo =>
                  _detalleDeFalla(errores[id] ?? [], impresos[id] ?? []),
              },
            ),
          );
        }
      case 'done':
        termino = true;
        exito = evento['success'] == true;
        tiempo = Duration(milliseconds: evento['time'] as int? ?? 0);
    }
  }

  return Corrida(
    pruebas: pruebas,
    termino: termino,
    exito: exito,
    duracion: tiempo,
  );
}

/// Sección del resumen: totales, pruebas que fallaron y, con [detalle],
/// cada prueba agrupada por historia (aceptación, integración y esfuerzo).
String resumenPruebas(
  Corrida corrida, {
  required String titulo,
  bool detalle = false,
}) {
  final tiempo = corrida.duracion == null ? '—' : duracion(corrida.duracion!);
  final texto = StringBuffer()
    ..writeln('### 🧪 $titulo')
    ..writeln()
    ..writeln('| Resultado | Pruebas | Pasaron | Fallaron | Omitidas | Tiempo |')
    ..writeln('|:-:|--:|--:|--:|--:|--:|')
    ..writeln(
      '| ${_veredicto(corrida)} | ${miles(corrida.pruebas.length)} '
      '| ${miles(corrida.pasaron)} | ${miles(corrida.fallaron)} '
      '| ${miles(corrida.omitidas)} | $tiempo |',
    )
    ..writeln();

  if (!corrida.termino) {
    texto
      ..writeln(
        '> ⚠️ La corrida se detuvo antes de terminar (se canceló o se cayó '
        'el proceso): los números son parciales. Revisa el log del paso.',
      )
      ..writeln();
  }

  texto.write(seccionFallas(corrida));

  if (detalle && corrida.pruebas.isNotEmpty) {
    texto
      ..writeln('#### Detalle')
      ..writeln();
    final porGrupo = <String, List<Prueba>>{};
    for (final prueba in corrida.pruebas) {
      porGrupo.putIfAbsent(prueba.grupo, () => []).add(prueba);
    }
    // Los archivos corren en paralelo: sin ordenar, el resumen cambiaría de
    // una corrida a otra.
    for (final grupo in porGrupo.keys.toList()..sort(_compararGrupos)) {
      final pruebas = porGrupo[grupo]!;
      final pasaron =
          pruebas.where((p) => p.estado == EstadoPrueba.paso).length;
      texto
        ..writeln('**$grupo** ($pasaron de ${pruebas.length} pasaron)')
        ..writeln();
      for (final prueba in pruebas) {
        texto.writeln(switch (prueba.estado) {
          EstadoPrueba.paso => '- ✅ ${prueba.nombre}',
          EstadoPrueba.fallo => '- ❌ ${prueba.nombre}',
          EstadoPrueba.omitida =>
            '- ⏭️ ${prueba.nombre} (omitida: ${prueba.detalle})',
        });
      }
      texto.writeln();
    }
  }

  return texto.toString();
}

/// Cada prueba que falló con su archivo, línea y error (hasta 20); vacío si
/// no falló ninguna.
String seccionFallas(Corrida corrida) {
  final fallas =
      corrida.pruebas.where((p) => p.estado == EstadoPrueba.fallo).toList();
  if (fallas.isEmpty) return '';
  final texto = StringBuffer()
    ..writeln('#### ❌ Pruebas que fallaron (${miles(fallas.length)})')
    ..writeln();
  for (final prueba in fallas.take(_maximoDeFallas)) {
    texto
      ..writeln('**${prueba.titulo}**  ')
      ..writeln('`${prueba.ubicacion}`');
    if (prueba.detalle.isNotEmpty) texto.write(bloque(prueba.detalle));
    texto.writeln();
  }
  if (fallas.length > _maximoDeFallas) {
    texto
      ..writeln(
        '…y ${miles(fallas.length - _maximoDeFallas)} más en el log del paso.',
      )
      ..writeln();
  }
  return texto.toString();
}

/// Una línea para la tabla de etapas de la regresión.
String lineaPruebas(Corrida corrida) {
  final total = corrida.pruebas.length;
  if (total == 0) return '⚠️ Sin pruebas';
  final linea = corrida.fallaron > 0
      ? '❌ ${miles(corrida.fallaron)} de ${miles(total)} pruebas fallaron'
      : corrida.termino
          ? '✅ ${_pruebasPasaron(corrida.pasaron)}'
          : '⚠️ ${_pruebasPasaron(corrida.pasaron)} antes de detenerse';
  final omitidas = corrida.omitidas;
  if (omitidas == 0) return linea;
  return '$linea · ${miles(omitidas)} ${omitidas == 1 ? 'omitida' : 'omitidas'}';
}

String _pruebasPasaron(int cuantas) => cuantas == 1
    ? '1 prueba pasó'
    : '${miles(cuantas)} pruebas pasaron';

/// «#33 …» antes que «#100 …»: por número de historia y, si no tienen, por
/// nombre.
int _compararGrupos(String a, String b) {
  int? numero(String grupo) =>
      int.tryParse(RegExp(r'^#(\d+)').firstMatch(grupo)?.group(1) ?? '');
  final (numeroA, numeroB) = (numero(a), numero(b));
  if (numeroA != null && numeroB != null && numeroA != numeroB) {
    return numeroA.compareTo(numeroB);
  }
  return a.compareTo(b);
}

String _veredicto(Corrida corrida) {
  if (corrida.fallaron > 0) return '❌ Falló';
  if (!corrida.termino) return '⚠️ Incompleta';
  if (!corrida.exito) return '❌ Falló';
  if (corrida.pruebas.isEmpty) return '⚠️ Sin pruebas';
  return '✅ Aprobado';
}

Iterable<Map<String, dynamic>> _eventos(String contenido) sync* {
  for (final renglon in const LineSplitter().convert(contenido)) {
    if (renglon.trim().isEmpty) continue;
    try {
      final evento = jsonDecode(renglon);
      if (evento is Map<String, dynamic>) yield evento;
    } on FormatException {
      // flutter test a veces mezcla avisos de texto en el reporte.
    }
  }
}

Prueba _prueba(
  Map<String, dynamic> inicio, {
  required EstadoPrueba estado,
  required String rutaSuite,
  required String raiz,
  required Map<int, String> grupos,
  required String detalle,
}) {
  final archivo = _rutaRelativa(rutaSuite, raiz);
  final ids = (inicio['groupIDs'] as List<dynamic>? ?? const []).cast<int>();
  final grupo = ids.length > 1 ? grupos[ids[1]] ?? '' : '';
  var nombre = (inicio['name'] as String? ?? '')
      .replaceAll(rutaSuite.isEmpty ? '\u0000' : rutaSuite, archivo);
  if (grupo.isNotEmpty && nombre.startsWith('$grupo ')) {
    nombre = nombre.substring(grupo.length + 1);
  }
  // testWidgets se declara dentro de flutter_test: su línea en el archivo de
  // la prueba viene en root_line.
  final url = (inicio['root_url'] ?? inicio['url']) as String?;
  final linea = (inicio['root_line'] ?? inicio['line']) as int?;
  final enElArchivo = url != null && Uri.decodeFull(url).endsWith(archivo);

  return Prueba(
    nombre: nombre,
    grupo: grupo.isEmpty ? archivo : grupo,
    archivo: archivo,
    estado: estado,
    linea: enElArchivo ? linea : null,
    detalle: detalle,
  );
}

String _rutaRelativa(String ruta, String raiz) {
  final normal = ruta.replaceAll(r'\', '/');
  final base = raiz.replaceAll(r'\', '/');
  if (base.isNotEmpty && normal.startsWith('$base/')) {
    return normal.substring(base.length + 1);
  }
  final carpeta =
      RegExp(r'(?:^|/)((?:integration_)?test/.*)$').firstMatch(normal);
  return carpeta?.group(1) ?? normal;
}

String _motivoDeOmision(Map<String, dynamic> inicio) {
  final metadatos = inicio['metadata'];
  if (metadatos is Map<String, dynamic>) {
    return metadatos['skipReason'] as String? ?? 'sin motivo';
  }
  return 'sin motivo';
}

/// En testWidgets el error dice «See exception logs above» y lo útil está en
/// el registro de la excepción que flutter_test imprime antes.
String _detalleDeFalla(List<String> errores, List<String> impresos) {
  final partes = <String>[];
  for (final error in errores) {
    final excepciones = error.startsWith('Test failed. See exception logs')
        ? impresos.where((m) => m.contains('EXCEPTION CAUGHT BY')).toList()
        : const <String>[];
    if (excepciones.isEmpty) {
      partes.add(error.trim());
    } else {
      partes.addAll(excepciones.map(_limpiarExcepcion));
    }
  }
  return _recortar(partes.where((p) => p.isNotEmpty).join('\n\n'));
}

/// Deja el mensaje de la excepción sin el encabezado ══╡ … ╞══ ni la pila.
String _limpiarExcepcion(String registro) {
  final renglones = registro.split('\n');
  final inicio =
      renglones.indexWhere((r) => r.contains('EXCEPTION CAUGHT BY')) + 1;
  final utiles = <String>[];
  for (final renglon in renglones.skip(inicio)) {
    if (renglon.startsWith('When the exception was thrown') ||
        renglon.startsWith('═')) {
      break;
    }
    utiles.add(renglon);
  }
  return utiles.join('\n').trim();
}

String _recortar(String texto) {
  final renglones = texto.split('\n');
  if (renglones.length <= _maximoDeRenglones) return texto;
  final resto = renglones.length - _maximoDeRenglones;
  return [
    ...renglones.take(_maximoDeRenglones),
    '… ($resto renglones más en el log del paso)',
  ].join('\n');
}
