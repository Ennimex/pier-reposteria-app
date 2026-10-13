// lib/ui/comandas/widgets/comandas_formato.dart
//
// Textos de fechas y horas de la agenda de comandas, iguales a los de la web
// (src/comandas/utilidades.ts). Las fechas llegan como 'YYYY-MM-DD' ya en
// hora de Huejutla, así que se calculan sin depender de la zona del teléfono.

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Huejutla no tiene horario de verano desde 2022: siempre UTC-6.
const _desfaseHuejutla = Duration(hours: -6);

DateTime? _fecha(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return null;
  return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// '11:00 a. m.' a partir de 'HH:MM'.
String horaLegible(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return hhmm;
  final h = int.parse(m[1]!);
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m[2]} ${h < 12 ? 'a. m.' : 'p. m.'}';
}

/// Encabezado de un día de la agenda: 'Hoy · lunes 12 de octubre',
/// 'Sábado 17 de octubre' (con el año si no es [anioActual]).
String etiquetaDia(String iso, int diasRestantes, {int? anioActual}) {
  final d = _fecha(iso);
  if (d == null) return iso;
  var fecha = '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';
  if (anioActual != null && anioActual != d.year) fecha += ' de ${d.year}';
  return switch (diasRestantes) {
    0 => 'Hoy · $fecha',
    1 => 'Mañana · $fecha',
    -1 => 'Ayer · $fecha',
    _ => fecha[0].toUpperCase() + fecha.substring(1),
  };
}

/// 'Es hoy', 'Faltan 3 días', 'Venció hace 2 días'.
String textoDiasRestantes(int dias) => switch (dias) {
  0 => 'Es hoy',
  1 => 'Es mañana',
  -1 => 'Venció ayer',
  > 1 => 'Faltan $dias días',
  _ => 'Venció hace ${-dias} días',
};

/// Día ('YYYY-MM-DD') de un timestamp ISO en hora de Huejutla.
String? diaDeEvento(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return null;
  final local = t.toUtc().add(_desfaseHuejutla);
  return '${local.year}-${_dos(local.month)}-${_dos(local.day)}';
}

/// Días de [desde] a [hasta] (ambas 'YYYY-MM-DD').
int diasEntre(String desde, String hasta) {
  final a = _fecha(desde);
  final b = _fecha(hasta);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays;
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// '$1,250.50': montos de la comanda (solo para quien cobra).
String moneda(double valor) {
  final centavos = (valor * 100).round();
  final entero = (centavos.abs() ~/ 100).toString();
  final miles = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) miles.write(',');
    miles.write(entero[i]);
  }
  final signo = centavos < 0 ? '-' : '';
  return '$signo\$$miles.${_dos(centavos.abs() % 100)}';
}
