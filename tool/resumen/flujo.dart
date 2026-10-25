// tool/resumen/flujo.dart — resumen del flujo principal en el emulador
// (integration_test/aceptacion/flujo_principal_test.dart): lee el reporte que
// deja test_driver/aceptacion_driver.dart en
// build/resultados/aceptacion_emulador.json.
import 'markdown.dart';

class PasoDelFlujo {
  const PasoDelFlujo({required this.nombre, required this.segundos});

  /// Nombre del paso, que es también el de su captura (01_inicio_de_sesion).
  final String nombre;

  /// Segundos desde que empezó la prueba hasta que terminó el paso.
  final double segundos;
}

class ReporteDelFlujo {
  const ReporteDelFlujo({
    required this.escenario,
    required this.aprobado,
    required this.pasos,
    required this.capturas,
    required this.fallas,
  });

  final String escenario;
  final bool aprobado;
  final List<PasoDelFlujo> pasos;

  /// Cuántas capturas de pantalla se guardaron.
  final int capturas;

  /// Detalle de cada prueba que falló.
  final List<String> fallas;

  /// Segundos del último paso: lo que tardó el flujo completo.
  double get segundos => pasos.isEmpty ? 0 : pasos.last.segundos;
}

/// Tolera campos faltantes: un reporte a medias no debe tumbar el resumen.
ReporteDelFlujo leerReporteDelFlujo(Map<String, dynamic> datos) {
  final pasos = [
    for (final paso in _lista(datos['pasos']))
      if (paso is Map<String, dynamic>)
        PasoDelFlujo(
          nombre: paso['paso']?.toString() ?? '',
          segundos: paso['segundos'] is num
              ? (paso['segundos'] as num).toDouble()
              : 0,
        ),
  ];
  final fallas = [
    for (final falla in _lista(datos['fallas']))
      if (falla is Map<String, dynamic>)
        '${falla['prueba'] ?? ''}\n${falla['detalle'] ?? ''}'.trim(),
  ];
  return ReporteDelFlujo(
    escenario: datos['escenario']?.toString() ?? '',
    aprobado: datos['aprobado'] == true,
    pasos: pasos,
    capturas: _lista(datos['capturas']).length,
    fallas: fallas,
  );
}

/// [valor] si es una lista; si falta o es otra cosa, una lista vacía.
List<dynamic> _lista(Object? valor) =>
    valor is List<dynamic> ? valor : const <dynamic>[];

String resumenFlujo(ReporteDelFlujo reporte) {
  final texto = StringBuffer()
    ..writeln('### 📱 Flujo principal en el emulador')
    ..writeln();
  if (reporte.escenario.isNotEmpty) {
    texto
      ..writeln(reporte.escenario)
      ..writeln();
  }
  texto
    ..writeln('| Resultado | Pasos | Capturas | Tiempo |')
    ..writeln('|:-:|--:|--:|--:|')
    ..writeln(
      '| ${reporte.aprobado ? '✅ Aprobado' : '❌ Falló'} '
      '| ${reporte.pasos.length} | ${reporte.capturas} '
      '| ${_segundos(reporte.segundos)} |',
    )
    ..writeln();
  if (reporte.pasos.isNotEmpty) {
    texto
      ..writeln('| Paso | Segundos desde el inicio |')
      ..writeln('|---|--:|');
    for (final paso in reporte.pasos) {
      texto.writeln('| ${celda(paso.nombre)} | ${_segundos(paso.segundos)} |');
    }
    texto.writeln();
  }
  if (reporte.capturas > 0) {
    texto
      ..writeln('Las capturas de cada paso están en Artifacts.')
      ..writeln();
  }
  if (reporte.fallas.isNotEmpty) {
    texto
      ..writeln('#### ❌ Lo que falló')
      ..writeln();
    for (final falla in reporte.fallas) {
      texto.write(bloque(falla));
    }
  }
  return texto.toString();
}

/// Una línea para la tabla de evidencias del pipeline.
String lineaFlujo(ReporteDelFlujo reporte) {
  final pasos = '${reporte.pasos.length} '
      '${reporte.pasos.length == 1 ? 'paso' : 'pasos'}';
  if (!reporte.aprobado) return '❌ Falló después de $pasos';
  return '✅ $pasos · ${reporte.capturas} capturas en '
      '${_segundos(reporte.segundos)}';
}

String _segundos(double segundos) => '${segundos.toStringAsFixed(1)} s';
