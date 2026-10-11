// lib/utils/formatters.dart
//
// Fechas como las muestra la app: «10 Oct 2026» y «10 Oct 2026 · 09:05 hrs».

const List<String> _meses = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// «10 Oct 2026».
String fechaCorta(DateTime fecha) =>
    '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

/// «10 Oct 2026 · 09:05 hrs».
String fechaConHora(DateTime fecha) =>
    '${fechaCorta(fecha)} · '
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')} hrs';
