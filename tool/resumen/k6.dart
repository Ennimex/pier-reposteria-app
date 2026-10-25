// tool/resumen/k6.dart — lee el resumen que deja `k6 run --summary-export
// <archivo>.json` (pruebas/k6/) y arma su resumen en Markdown, su línea para la
// tabla de evidencias del pipeline y la comparación con la línea base de
// rendimiento (tool/linea_base_rendimiento.json).
import 'markdown.dart';

class ReporteK6 {
  const ReporteK6({
    required this.peticiones,
    required this.porSegundo,
    required this.tasaDeFallas,
    required this.p95Ms,
    required this.promedioMs,
    required this.maximoMs,
    required this.respuestas429,
    this.p95RecuperacionMs,
    this.tasaDeFallasRecuperacion,
  });

  /// Peticiones HTTP en toda la prueba (http_reqs).
  final int peticiones;
  final double porSegundo;

  /// Fracción de peticiones fallidas, de 0 a 1 (http_req_failed).
  final double tasaDeFallas;

  /// Tiempos de respuesta (http_req_duration), en milisegundos.
  final double p95Ms;
  final double promedioMs;
  final double maximoMs;

  /// Respuestas 429 (límite de peticiones del backend).
  final int respuestas429;

  /// Solo en la prueba de esfuerzo: el escenario de recuperación
  /// (fase:recuperacion).
  final double? p95RecuperacionMs;
  final double? tasaDeFallasRecuperacion;
}

/// Tolera métricas faltantes (cuentan como 0) y los dos formatos de k6: el
/// valor directo en la métrica o dentro de «values».
ReporteK6 leerK6(Map<String, dynamic> datos) {
  final metricas = datos['metrics'] is Map<String, dynamic>
      ? datos['metrics'] as Map<String, dynamic>
      : const <String, dynamic>{};

  double? valor(String metrica, String campo) {
    final datosDeLaMetrica = metricas[metrica];
    if (datosDeLaMetrica is! Map<String, dynamic>) return null;
    final directo = datosDeLaMetrica[campo];
    if (directo is num) return directo.toDouble();
    final valores = datosDeLaMetrica['values'];
    if (valores is Map<String, dynamic> && valores[campo] is num) {
      return (valores[campo] as num).toDouble();
    }
    return null;
  }

  return ReporteK6(
    peticiones: (valor('http_reqs', 'count') ?? 0).round(),
    porSegundo: valor('http_reqs', 'rate') ?? 0,
    tasaDeFallas: valor('http_req_failed', 'value') ??
        valor('http_req_failed', 'rate') ??
        0,
    p95Ms: valor('http_req_duration', 'p(95)') ?? 0,
    promedioMs: valor('http_req_duration', 'avg') ?? 0,
    maximoMs: valor('http_req_duration', 'max') ?? 0,
    respuestas429: (valor('respuestas_429', 'count') ?? 0).round(),
    p95RecuperacionMs: valor('http_req_duration{fase:recuperacion}', 'p(95)'),
    tasaDeFallasRecuperacion:
        valor('http_req_failed{fase:recuperacion}', 'value') ??
            valor('http_req_failed{fase:recuperacion}', 'rate'),
  );
}

/// La línea base de un escenario de k6 (`api_<clave>` en
/// tool/linea_base_rendimiento.json).
class LineaBaseK6 {
  const LineaBaseK6({required this.p95Ms, this.corrida = ''});

  final double p95Ms;

  /// Corrida de GitHub Actions que fijó la línea base.
  final String corrida;
}

/// La línea base de [clave] o null si el archivo no la trae.
LineaBaseK6? leerLineaBaseK6(Map<String, dynamic> datos, String clave) {
  final escenario = datos[clave];
  if (escenario is! Map<String, dynamic>) return null;
  final p95 = escenario['p95_ms'];
  if (p95 is! num || p95 <= 0) return null;
  return LineaBaseK6(
    p95Ms: p95.toDouble(),
    corrida: escenario['corrida']?.toString() ?? '',
  );
}

/// Cuánto puede subir el p95 contra la línea base antes de fallar (20 %).
const toleranciaDelP95 = 0.20;

/// El p95 permitido: la línea base más la tolerancia.
double p95Permitido(LineaBaseK6 base) => base.p95Ms * (1 + toleranciaDelP95);

bool rebasaLaLineaBase(ReporteK6 reporte, LineaBaseK6 base) =>
    reporte.p95Ms > p95Permitido(base);

String resumenK6(ReporteK6 reporte, {required String titulo, LineaBaseK6? base}) {
  final texto = StringBuffer()
    ..writeln('### 📈 $titulo')
    ..writeln()
    ..writeln(
      '| Peticiones | Por segundo | Errores | p95 | Promedio | Máximo | 429 |',
    )
    ..writeln('|--:|--:|--:|--:|--:|--:|--:|')
    ..writeln(
      '| ${miles(reporte.peticiones)} '
      '| ${reporte.porSegundo.toStringAsFixed(1)} '
      '| ${porcentaje(reporte.tasaDeFallas * 100)} '
      '| ${_ms(reporte.p95Ms)} | ${_ms(reporte.promedioMs)} '
      '| ${_ms(reporte.maximoMs)} | ${miles(reporte.respuestas429)} |',
    )
    ..writeln();
  final p95Recuperacion = reporte.p95RecuperacionMs;
  if (p95Recuperacion != null) {
    texto
      ..writeln(
        'Recuperación después del pico: p95 ${_ms(p95Recuperacion)} · '
        'errores ${porcentaje((reporte.tasaDeFallasRecuperacion ?? 0) * 100)}.',
      )
      ..writeln();
  }
  if (base != null) {
    final veredicto = rebasaLaLineaBase(reporte, base) ? '❌' : '✅';
    texto
      ..writeln(
        '$veredicto p95 ${_ms(reporte.p95Ms)} contra la línea base de '
        '${_ms(base.p95Ms)} (máximo permitido ${_ms(p95Permitido(base))}, '
        '+${(toleranciaDelP95 * 100).round()} %).',
      )
      ..writeln();
  }
  return texto.toString();
}

/// Una línea para la tabla de evidencias del pipeline.
String lineaK6(ReporteK6 reporte) {
  final linea = 'k6: ${miles(reporte.peticiones)} peticiones · p95 '
      '${_ms(reporte.p95Ms)} · ${porcentaje(reporte.tasaDeFallas * 100)} '
      'errores';
  final p95Recuperacion = reporte.p95RecuperacionMs;
  if (p95Recuperacion == null) return linea;
  return '$linea · recuperación p95 ${_ms(p95Recuperacion)}';
}

String _ms(double milisegundos) => '${milisegundos.toStringAsFixed(0)} ms';
