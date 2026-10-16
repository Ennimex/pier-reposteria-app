// tool/resumen/rendimiento.dart — peso del APK de release (JSON de
// `flutter build apk --analyze-size`) y tiempos por cuadro
// (build/*.timeline_summary.json de flutter_driver) (#157).
import 'markdown.dart';

class Parte {
  const Parte({required this.nombre, required this.bytes});

  final String nombre;
  final int bytes;
}

class AnalisisDePeso {
  const AnalisisDePeso({required this.partes, required this.paquetes});

  /// Archivos del APK (comprimidos), del más pesado al más ligero.
  final List<Parte> partes;

  /// Paquetes de Dart dentro de libapp.so (sin comprimir).
  final List<Parte> paquetes;
}

const _maximoDePartes = 6;
const _maximoDePaquetes = 5;

/// Hasta dónde se abre el árbol del APK: lib/arm64-v8a/libflutter.so.
const _profundidad = 3;

/// [raiz] es el JSON que flutter_tools arma en base/analyze_size.dart: nodos
/// `{n, value, children}`; el nodo «libapp.so (Dart AOT)» cuelga el desglose
/// del código Dart por paquete.
AnalisisDePeso leerAnalisisDePeso(Map<String, dynamic> raiz) {
  final partes = <Parte>[];
  final paquetes = <Parte>[];

  void recorrer(Map<String, dynamic> nodo, String ruta, int nivel) {
    final nombre = nodo['n'] as String? ?? '';
    final camino = ruta.isEmpty ? nombre : '$ruta/$nombre';
    final hijos = _hijos(nodo);
    if (nombre.endsWith('(Dart AOT)')) {
      partes.add(Parte(nombre: camino, bytes: _bytes(nodo)));
      paquetes.addAll([
        for (final paquete in hijos)
          if (_esPaqueteVisible(paquete['n'] as String? ?? ''))
            Parte(
              nombre: _nombreDePaquete(paquete['n'] as String),
              bytes: _bytes(paquete),
            ),
      ]);
    } else if (hijos.isEmpty || nivel == _profundidad) {
      partes.add(Parte(nombre: camino, bytes: _bytes(nodo)));
    } else {
      for (final hijo in hijos) {
        recorrer(hijo, camino, nivel + 1);
      }
    }
  }

  for (final hijo in _hijos(raiz)) {
    recorrer(hijo, '', 1);
  }
  return AnalisisDePeso(
    partes: _mayores(partes, _maximoDePartes),
    paquetes: _mayores(paquetes, _maximoDePaquetes),
  );
}

String resumenPeso({
  required String apk,
  required int bytes,
  AnalisisDePeso? analisis,
}) {
  final texto = StringBuffer()
    ..writeln('### 📦 Peso del APK de release')
    ..writeln()
    ..writeln('| APK | Peso |')
    ..writeln('|---|--:|')
    ..writeln('| `$apk` | **${tamano(bytes)}** |')
    ..writeln();
  if (analisis != null && analisis.partes.isNotEmpty) {
    texto
      ..writeln('#### Lo que más ocupa dentro del APK (comprimido)')
      ..writeln()
      ..write(_tabla('Parte', analisis.partes));
  }
  if (analisis != null && analisis.paquetes.isNotEmpty) {
    texto
      ..writeln('#### Paquetes de Dart que más pesan (código compilado)')
      ..writeln()
      ..write(_tabla('Paquete', analisis.paquetes));
  }
  return texto.toString();
}

/// Una columna por medición (el nombre del archivo sin
/// .timeline_summary.json) y un renglón por dato de flutter_driver.
String resumenTiempos(Map<String, Map<String, dynamic>> mediciones) {
  const titulo = '### ⏱️ Fluidez en el celular\n\n';
  if (mediciones.isEmpty) {
    return '$titulo> ⚠️ No se generaron mediciones '
        '(build/*.timeline_summary.json). Revisa el log del paso.\n';
  }
  final columnas = mediciones.keys.toList();
  final texto = StringBuffer(titulo)
    ..writeln('| | ${columnas.join(' | ')} |')
    ..writeln('|---|${'--:|' * columnas.length}');
  for (final (nombre, llave, esTiempo) in _datosDeTiempo) {
    final valores = [
      for (final columna in columnas)
        switch (mediciones[columna]![llave]) {
          final num valor when esTiempo => '${valor.toStringAsFixed(1)} ms',
          final num valor => miles(valor.round()),
          _ => '—',
        },
    ];
    texto.writeln('| $nombre | ${valores.join(' | ')} |');
  }
  return texto.toString();
}

/// (renglón, llave del JSON, es tiempo en ms).
const _datosDeTiempo = [
  ('Cuadros dibujados', 'frame_count', false),
  ('Construcción promedio', 'average_frame_build_time_millis', true),
  ('Construcción p90', '90th_percentile_frame_build_time_millis', true),
  ('Peor construcción', 'worst_frame_build_time_millis', true),
  (
    'Cuadros que tardaron más de 16 ms en construirse',
    'missed_frame_build_budget_count',
    false,
  ),
  ('Rasterizado promedio', 'average_frame_rasterizer_time_millis', true),
  ('Rasterizado p90', '90th_percentile_frame_rasterizer_time_millis', true),
  ('Peor rasterizado', 'worst_frame_rasterizer_time_millis', true),
  (
    'Cuadros que tardaron más de 16 ms en rasterizarse',
    'missed_frame_rasterizer_budget_count',
    false,
  ),
];

List<Map<String, dynamic>> _hijos(Map<String, dynamic> nodo) =>
    (nodo['children'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

/// Los nodos intermedios del desglose de Dart no siempre traen `value`.
int _bytes(Map<String, dynamic> nodo) =>
    nodo['value'] as int? ??
    _hijos(nodo).fold(0, (suma, hijo) => suma + _bytes(hijo));

/// Igual que flutter_tools: sin @stubs, @shared… ni librerías dart:_.
bool _esPaqueteVisible(String nombre) =>
    nombre.isNotEmpty && !nombre.startsWith('@') && !nombre.startsWith('dart:_');

/// Igual que flutter_tools (_formatExtraLeadingPackages): quita el primer
/// tramo repetido de «package:x/package:x/…».
String _nombreDePaquete(String nombre) {
  final tramos = nombre.split('/');
  if (!nombre.startsWith('package') || tramos.length < 2) return nombre;
  return tramos.skip(1).join('/');
}

List<Parte> _mayores(List<Parte> partes, int cuantas) =>
    (partes.toList()..sort((a, b) => b.bytes.compareTo(a.bytes)))
        .take(cuantas)
        .toList();

String _tabla(String columna, List<Parte> partes) {
  final tabla = StringBuffer()
    ..writeln('| $columna | Peso |')
    ..writeln('|---|--:|');
  for (final parte in partes) {
    tabla.writeln('| `${parte.nombre}` | ${tamano(parte.bytes)} |');
  }
  return (tabla..writeln()).toString();
}
