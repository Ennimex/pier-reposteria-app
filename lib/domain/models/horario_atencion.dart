// lib/domain/models/horario_atencion.dart
//
// Horario de atención de una sucursal para recoger o entregar un pedido
// (#320). Dirección lo captura en el panel como texto libre por sucursal
// («Lun - Dom: 8:00 AM - 9:00 PM»); SucursalAtencion lee la lista del panel
// y aquí se interpreta cada texto. Las horas que se ofrecen salen de este
// horario: franjas de una hora que caben completas en lo que abre el día.
import 'dart:math' as math;

/// Un tramo abierto del día, en minutos desde la medianoche: de `inicio`
/// (incluido) a `fin` (excluido).
typedef TramoHorario = ({int inicio, int fin});

class HorarioAtencion {
  /// [porDia]: día de la semana (DateTime.weekday, 1 = lunes) → sus tramos
  /// abiertos. Un día que no está, o sin tramos, está cerrado.
  const HorarioAtencion(this.porDia);

  /// Los mismos tramos, de [abre] a [cierra] (horas), cada día de [dias].
  factory HorarioAtencion.semanal({
    required List<int> dias,
    required int abre,
    required int cierra,
  }) =>
      HorarioAtencion({
        for (final dia in dias) dia: [(inicio: abre * 60, fin: cierra * 60)],
      });

  final Map<int, List<TramoHorario>> porDia;

  static const int _minutosDelDia = 24 * 60;

  static const Map<String, int> _dias = {
    'lunes': DateTime.monday,
    'lun': DateTime.monday,
    'martes': DateTime.tuesday,
    'mar': DateTime.tuesday,
    'miercoles': DateTime.wednesday,
    'mier': DateTime.wednesday,
    'mie': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'jue': DateTime.thursday,
    'viernes': DateTime.friday,
    'vie': DateTime.friday,
    'sabado': DateTime.saturday,
    'sab': DateTime.saturday,
    'domingo': DateTime.sunday,
    'dom': DateTime.sunday,
  };

  static const String _dia = '(?:lunes|lun|martes|mar|miercoles|mier|mie|'
      r'jueves|jue|viernes|vie|sabado|sab|domingo|dom)\.?';
  static const String _hasta = r'\s*(?:-|al|a|hasta)\s*';

  /// Las piezas del texto, en orden: un rango de días («lun - dom»), un
  /// rango de horas («8:00 am - 9:00 pm», «9 a 21»), un día suelto, «cerrado»
  /// o «diario». Lo demás («:», «de», «hrs», viñetas) se ignora.
  static final RegExp _piezas = RegExp(
    '(?<rango>\\b(?<desde>$_dia)$_hasta(?<hastaDia>$_dia)(?![a-z]))'
    r'|(?<horas>(?<h1>\d{1,2})(?::(?<m1>\d{2}))?\s*(?<s1>am|pm)?'
    '$_hasta'
    r'(?<h2>\d{1,2})(?::(?<m2>\d{2}))?\s*(?<s2>am|pm)?)'
    '|(?<dia>\\b$_dia(?![a-z]))'
    r'|(?<cerrado>\bcerrad[oa]\b)'
    r'|(?<diario>\b(?:diario|todos los dias|toda la semana)\b)',
  );

  /// Interpreta un horario escrito: «Lun - Dom: 8:00 AM - 9:00 PM»,
  /// «Lun–Sáb • 9:00 – 21:00 hrs», «Lunes a sábado de 9 a 8» o
  /// «Lun - Vie 9 a 20, Sáb 9 a 15, Dom cerrado». Las horas van a los días
  /// que se nombraron antes; los días que no se nombran quedan cerrados.
  /// null si no se entiende: sin días, horas antes de los días, una hora
  /// imposible o un tramo que cruza la medianoche.
  static HorarioAtencion? desdeTexto(String texto) {
    final porDia = <int, List<TramoHorario>>{};
    var pendientes = <int>{};
    var ultimos = <int>{};
    for (final pieza in _piezas.allMatches(_normalizar(texto))) {
      if (pieza.namedGroup('rango') != null) {
        pendientes.addAll(_rango(
          _diaDe(pieza.namedGroup('desde')!),
          _diaDe(pieza.namedGroup('hastaDia')!),
        ));
      } else if (pieza.namedGroup('dia') != null) {
        pendientes.add(_diaDe(pieza.namedGroup('dia')!));
      } else if (pieza.namedGroup('diario') != null) {
        pendientes.addAll(_rango(DateTime.monday, DateTime.sunday));
      } else {
        // Horas o «cerrado»: para los días recién nombrados o, si no hay,
        // para los de antes («Lun - Vie 9 a 14, 16 a 20»).
        final dias = pendientes.isNotEmpty ? pendientes : ultimos;
        if (dias.isEmpty) return null;
        if (pieza.namedGroup('cerrado') != null) {
          for (final dia in dias) {
            porDia[dia] = [];
          }
        } else {
          final tramo = _tramo(pieza);
          if (tramo == null) return null;
          for (final dia in dias) {
            (porDia[dia] ??= []).add(tramo);
          }
        }
        ultimos = dias;
        pendientes = {};
      }
    }
    final horario = HorarioAtencion({
      for (final MapEntry(key: dia, value: tramos) in porDia.entries)
        dia: _ordenados(tramos),
    });
    return horario.abreAlgunDia ? horario : null;
  }

  static String _normalizar(String texto) {
    var t = texto.toLowerCase();
    const sinAcento = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    sinAcento.forEach((con, sin) => t = t.replaceAll(con, sin));
    return t
        .replaceAll(RegExp('[–—]'), '-')
        .replaceAll(RegExp(r'\ba\.\s*m\.?'), 'am')
        .replaceAll(RegExp(r'\bp\.\s*m\.?'), 'pm');
  }

  static int _diaDe(String palabra) => _dias[palabra.replaceAll('.', '')]!;

  /// Del día [desde] al [hasta], dando la vuelta si hace falta (vie a lun).
  static List<int> _rango(int desde, int hasta) {
    final dias = [desde];
    for (var dia = desde; dia != hasta;) {
      dia = dia % 7 + 1;
      dias.add(dia);
    }
    return dias;
  }

  /// El tramo de un rango de horas, o null si no tiene sentido.
  static TramoHorario? _tramo(RegExpMatch pieza) {
    final h1 = pieza.namedGroup('h1')!;
    final m1 = pieza.namedGroup('m1');
    final s1 = pieza.namedGroup('s1');
    final s2 = pieza.namedGroup('s2');
    var inicio = _minutos(h1, m1, s1);
    var fin = _minutos(pieza.namedGroup('h2')!, pieza.namedGroup('m2'), s2);
    if (inicio == null || fin == null) return null;
    if (s1 == null && s2 != null) {
      // «1 - 5 pm»: la primera toma el am/pm de la segunda si así abre antes.
      final conSufijo = _minutos(h1, m1, s2);
      if (conSufijo != null && conSufijo < fin) inicio = conSufijo;
    }
    if (s1 == null && s2 == null && fin <= inicio && fin < 12 * 60) {
      // «9 a 8» sin am/pm: cierra en la tarde.
      fin += 12 * 60;
    }
    if (inicio >= fin || fin > _minutosDelDia) return null;
    return (inicio: inicio, fin: fin);
  }

  static int? _minutos(String hora, String? minutos, String? sufijo) {
    var h = int.parse(hora);
    final m = minutos == null ? 0 : int.parse(minutos);
    if (m > 59) return null;
    if (sufijo != null) {
      if (h < 1 || h > 12) return null;
      h = h % 12 + (sufijo == 'pm' ? 12 : 0);
    } else if (h > 24 || (h == 24 && m > 0)) {
      return null;
    }
    return h * 60 + m;
  }

  static List<TramoHorario> _ordenados(List<TramoHorario> tramos) =>
      [...tramos]..sort((a, b) => a.inicio.compareTo(b.inicio));

  /// ¿Abre al menos un día?
  bool get abreAlgunDia => porDia.values.any((tramos) => tramos.isNotEmpty);

  /// Las horas en que abren este horario y [otro] a la vez.
  HorarioAtencion interseccion(HorarioAtencion otro) => HorarioAtencion({
        for (final MapEntry(key: dia, value: tramos) in porDia.entries)
          if (otro.porDia[dia] case final otros?)
            dia: _ordenados([
              for (final a in tramos)
                for (final b in otros)
                  if (math.max(a.inicio, b.inicio) < math.min(a.fin, b.fin))
                    (
                      inicio: math.max(a.inicio, b.inicio),
                      fin: math.min(a.fin, b.fin),
                    ),
            ]),
      });

  List<TramoHorario> _tramosDel(DateTime dia) => porDia[dia.weekday] ?? const [];

  /// ¿Abre el día de [dia]?
  bool abreEl(DateTime dia) => _tramosDel(dia).isNotEmpty;

  /// ¿Está abierto en [momento]?
  bool abiertoEn(DateTime momento) {
    final minuto = momento.hour * 60 + momento.minute;
    return _tramosDel(momento)
        .any((t) => t.inicio <= minuto && minuto < t.fin);
  }

  /// Las franjas de una hora («09:00 - 10:00») que caben completas en el
  /// horario del día de [dia]: cada tramo, desde su primera hora en punto.
  List<String> franjasDelDia(DateTime dia) => [
        for (final t in _tramosDel(dia))
          for (var inicio = (t.inicio + 59) ~/ 60 * 60;
              inicio + 60 <= t.fin;
              inicio += 60)
            '${_hora(inicio)} - ${_hora(inicio + 60)}',
      ];

  /// «09:00» de [minutos] desde la medianoche.
  static String _hora(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';

  /// Cuándo abre después de [momento]: más tarde ese mismo día o el
  /// siguiente día que abra. null si no abre ningún día.
  DateTime? siguienteApertura(DateTime momento) {
    final minuto = momento.hour * 60 + momento.minute;
    for (var i = 0; i <= 7; i++) {
      final dia = DateTime(momento.year, momento.month, momento.day + i);
      final aperturas = [
        for (final t in _tramosDel(dia))
          if (i > 0 || t.inicio > minuto) t.inicio,
      ];
      if (aperturas.isEmpty) continue;
      final abre = aperturas.reduce(math.min);
      return DateTime(dia.year, dia.month, dia.day, abre ~/ 60, abre % 60);
    }
    return null;
  }
}
