// tool/resumen/cobertura.dart — lee coverage/lcov.info (flutter test
// --coverage) y arma la cobertura total y por carpeta (#157).
import 'dart:convert';

import 'markdown.dart';

class CoberturaArchivo {
  const CoberturaArchivo({
    required this.archivo,
    required this.lineas,
    required this.cubiertas,
  });

  /// Ruta desde lib/: lib/ui/cart/cart_screen.dart.
  final String archivo;
  final int lineas;
  final int cubiertas;

  double get porcentaje => lineas == 0 ? 100 : cubiertas * 100 / lineas;

  /// Carpeta de primer nivel: lib/ui/cart/x.dart → lib/ui; lib/main.dart → lib.
  String get carpeta {
    final partes = archivo.split('/');
    return partes.length > 2 ? '${partes[0]}/${partes[1]}' : partes.first;
  }
}

const _maximoDeArchivos = 10;

List<CoberturaArchivo> leerLcov(String contenido) {
  final archivos = <CoberturaArchivo>[];
  String? ruta;
  int? lineas;
  int? cubiertas;
  var lineasDa = 0;
  var cubiertasDa = 0;

  for (final renglon in const LineSplitter().convert(contenido)) {
    final dato = renglon.trim();
    if (dato.startsWith('SF:')) {
      ruta = dato.substring(3);
      lineas = null;
      cubiertas = null;
      lineasDa = 0;
      cubiertasDa = 0;
    } else if (dato.startsWith('DA:')) {
      // DA:<línea>,<veces que se ejecutó>
      lineasDa++;
      final veces = int.tryParse(dato.split(',').elementAtOrNull(1) ?? '');
      if ((veces ?? 0) > 0) cubiertasDa++;
    } else if (dato.startsWith('LF:')) {
      lineas = int.tryParse(dato.substring(3));
    } else if (dato.startsWith('LH:')) {
      cubiertas = int.tryParse(dato.substring(3));
    } else if (dato == 'end_of_record' && ruta != null) {
      archivos.add(
        CoberturaArchivo(
          archivo: _desdeLib(ruta),
          lineas: lineas ?? lineasDa,
          cubiertas: cubiertas ?? cubiertasDa,
        ),
      );
      ruta = null;
    }
  }
  return archivos;
}

/// Total en negritas, tabla por carpeta y, plegados, los archivos con menos
/// cobertura (lo que antes se descargaba como artifact para revisarlo).
String resumenCobertura(List<CoberturaArchivo> archivos) {
  if (archivos.isEmpty) {
    return '> ⚠️ No se generó el reporte de cobertura (coverage/lcov.info).\n';
  }
  final total = _sumar(archivos);
  final texto = StringBuffer()
    ..writeln(
      '**Cobertura de líneas: ${porcentaje(total.porcentaje)}** '
      '(${miles(total.cubiertas)} de ${miles(total.lineas)} líneas)',
    )
    ..writeln()
    ..writeln(_encabezado('Carpeta'));

  final porCarpeta = <String, List<CoberturaArchivo>>{};
  for (final archivo in archivos) {
    porCarpeta.putIfAbsent(archivo.carpeta, () => []).add(archivo);
  }
  for (final carpeta in porCarpeta.keys.toList()..sort()) {
    texto.writeln(_fila(carpeta, _sumar(porCarpeta[carpeta]!)));
  }
  texto.writeln();

  final menores = archivos.where((a) => a.lineas > 0).toList()
    ..sort((a, b) {
      final orden = a.porcentaje.compareTo(b.porcentaje);
      return orden != 0
          ? orden
          : (b.lineas - b.cubiertas).compareTo(a.lineas - a.cubiertas);
    });
  final tabla = StringBuffer()..writeln(_encabezado('Archivo'));
  for (final archivo in menores.take(_maximoDeArchivos)) {
    tabla.writeln(_fila(archivo.archivo, archivo));
  }
  final cuantos = menores.length < _maximoDeArchivos
      ? menores.length
      : _maximoDeArchivos;
  texto.write(
    plegable('Los $cuantos archivos con menos cobertura', tabla.toString()),
  );
  return texto.toString();
}

/// «cobertura 84.3 %», para la tabla de etapas de la regresión.
String lineaCobertura(List<CoberturaArchivo> archivos) => archivos.isEmpty
    ? 'sin cobertura'
    : 'cobertura ${porcentaje(_sumar(archivos).porcentaje)}';

CoberturaArchivo _sumar(List<CoberturaArchivo> archivos) => CoberturaArchivo(
      archivo: '',
      lineas: archivos.fold(0, (suma, a) => suma + a.lineas),
      cubiertas: archivos.fold(0, (suma, a) => suma + a.cubiertas),
    );

String _encabezado(String columna) =>
    '| $columna | Líneas | Cubiertas | Cobertura |\n|---|--:|--:|--:|';

String _fila(String nombre, CoberturaArchivo cobertura) =>
    '| `$nombre` | ${miles(cobertura.lineas)} | ${miles(cobertura.cubiertas)} '
    '| ${porcentaje(cobertura.porcentaje)} |';

String _desdeLib(String ruta) {
  final normal = ruta.replaceAll(r'\', '/');
  return RegExp(r'(?:^|/)(lib/.*)$').firstMatch(normal)?.group(1) ?? normal;
}
