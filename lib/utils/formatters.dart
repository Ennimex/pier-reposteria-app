// lib/utils/formatters.dart
//
// Fechas como las muestra la app: «10 Oct 2026» y «10 Oct 2026 · 09:05 hrs».
// Las fechas del backend llegan en UTC; la app las muestra en la hora de la
// sucursal (Huejutla: UTC−6 todo el año desde 2022), igual que la web, sin
// depender de la zona del teléfono (#216).

const List<String> _meses = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Diferencia de la hora de México con UTC.
const Duration _desfaseMexico = Duration(hours: -6);

/// [instante] en la hora de México, como fecha y hora de reloj.
DateTime enHoraDeMexico(DateTime instante) =>
    instante.toUtc().add(_desfaseMexico);

String _dos(int n) => n.toString().padLeft(2, '0');

/// «10 Oct 2026», en la hora de México.
String fechaCorta(DateTime fecha) {
  final f = enHoraDeMexico(fecha);
  return '${f.day} ${_meses[f.month - 1]} ${f.year}';
}

/// «10 Oct 2026 · 09:05 hrs», en la hora de México.
String fechaConHora(DateTime fecha) {
  final f = enHoraDeMexico(fecha);
  return '${fechaCorta(fecha)} · ${_dos(f.hour)}:${_dos(f.minute)} hrs';
}

/// Un horario de recogida o de entrega como lo manda el backend (ISO en UTC)
/// en la hora de México: «28 Oct 2026 · 09:00 hrs». Si no es una fecha, se
/// muestra tal cual.
String horarioDelPedido(String horario) {
  final instante = DateTime.tryParse(horario.trim());
  return instante == null ? horario : fechaConHora(instante);
}

/// El horario que se elige en el checkout ([fecha] y [hora] «HH:mm», en la
/// hora de México) como instante en UTC, igual que lo manda la web (#216):
/// así el backend lo guarda en la hora correcta.
String horarioEnUtc(DateTime fecha, String hora) {
  final dia = '${fecha.year}-${_dos(fecha.month)}-${_dos(fecha.day)}';
  return DateTime.parse('${dia}T$hora:00-06:00').toUtc().toIso8601String();
}
