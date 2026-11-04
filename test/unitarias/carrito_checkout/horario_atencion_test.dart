// test/unitarias/carrito_checkout/horario_atencion_test.dart — el horario de
// atención de las sucursales (#320): cómo se lee el texto libre del panel
// («Lun - Dom: 8:00 AM - 9:00 PM»), las horas en que abren todas las
// sucursales y las consultas del checkout (abierto, horas que caben,
// siguiente apertura).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/horario_atencion.dart';

/// Minutos desde la medianoche de «h:mm».
int _min(int h, [int m = 0]) => h * 60 + m;

/// Los tramos de cada día de [horario], como mapa simple para comparar.
Map<int, List<(int, int)>> _tramos(HorarioAtencion? horario) => {
      for (final MapEntry(key: dia, value: tramos) in horario!.porDia.entries)
        dia: [for (final t in tramos) (t.inicio, t.fin)],
    };

/// Lunes a domingo con el mismo tramo.
Map<int, List<(int, int)>> _todaLaSemana(int inicio, int fin) => {
      for (var dia = DateTime.monday; dia <= DateTime.sunday; dia++)
        dia: [(inicio, fin)],
    };

// Noviembre de 2026: el 7 es sábado, el 8 domingo y el 9 lunes.
final DateTime _sabado = DateTime(2026, 11, 7);
final DateTime _domingo = DateTime(2026, 11, 8);
final DateTime _lunes = DateTime(2026, 11, 9);

void main() {
  group('HorarioAtencion.desdeTexto', () {
    test('el formato del panel: «Lun - Dom: 8:00 AM - 9:00 PM»', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto('Lun - Dom: 8:00 AM - 9:00 PM')),
        _todaLaSemana(_min(8), _min(21)),
      );
    });

    test('el de BusinessInfo: «Lun–Sáb • 9:00 – 21:00 hrs» (el domingo cierra)',
        () {
      final horario =
          HorarioAtencion.desdeTexto('Lun–Sáb • 9:00 – 21:00 hrs');
      expect(_tramos(horario), {
        for (var dia = DateTime.monday; dia <= DateTime.saturday; dia++)
          dia: [(_min(9), _min(21))],
      });
      expect(horario!.abreEl(_domingo), isFalse);
    });

    test('varios grupos de días y uno cerrado', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto(
            'Lun - Vie 9 a 20, Sáb 9 a 15, Dom cerrado')),
        {
          for (var dia = DateTime.monday; dia <= DateTime.friday; dia++)
            dia: [(_min(9), _min(20))],
          DateTime.saturday: [(_min(9), _min(15))],
          DateTime.sunday: <(int, int)>[],
        },
      );
    });

    test('nombres completos y horas sin am/pm: «Lunes a sábado de 9 a 8»', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto('Lunes a sábado de 9 a 8')),
        {
          for (var dia = DateTime.monday; dia <= DateTime.saturday; dia++)
            dia: [(_min(9), _min(20))],
        },
      );
    });

    test('días sueltos y turno partido', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto(
            'Lun, Mié y Vie: 16:00 - 20:00, 9:00 - 14:00')),
        {
          for (final dia in [
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          ])
            dia: [(_min(9), _min(14)), (_min(16), _min(20))],
        },
      );
    });

    test('un rango que da la vuelta a la semana: «Vie a lun»', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto('Vie a lun 10 am a 6 pm')).keys,
        [DateTime.friday, DateTime.saturday, DateTime.sunday, DateTime.monday],
      );
    });

    test('«Diario» con a.m./p.m. y minutos', () {
      expect(
        _tramos(HorarioAtencion.desdeTexto('Diario 7:30 a.m. - 1 p.m.')),
        _todaLaSemana(_min(7, 30), _min(13)),
      );
    });

    test('la primera hora toma el am/pm de la segunda si abre antes', () {
      expect(_tramos(HorarioAtencion.desdeTexto('Sáb. 1 - 5 pm')), {
        DateTime.saturday: [(_min(13), _min(17))],
      });
      expect(_tramos(HorarioAtencion.desdeTexto('Sáb 9 - 5 pm')), {
        DateTime.saturday: [(_min(9), _min(17))],
      });
    });

    test('12 del día y medianoche como cierre', () {
      expect(_tramos(HorarioAtencion.desdeTexto('Dom 12 pm - 24:00')), {
        DateTime.sunday: [(_min(12), _min(24))],
      });
    });

    for (final (texto, motivo) in [
      ('9-8', 'horas sin días'),
      ('Cerrado', 'sin días'),
      ('Lun - Dom', 'días sin horas'),
      ('Lun - Dom cerrado', 'ningún día abre'),
      ('Lun 25:00 - 26:00', 'hora imposible'),
      ('Lun 9:75 - 10:00', 'minutos imposibles'),
      ('Lun 13 pm - 2 pm', 'am/pm con hora de 24'),
      ('Lun 10 pm - 2 am', 'cruza la medianoche'),
      ('Lun 24:30 - 25:00', 'después de la medianoche'),
      ('cuando se pueda', 'texto sin horario'),
    ]) {
      test('no se entiende: «$texto» ($motivo)', () {
        expect(HorarioAtencion.desdeTexto(texto), isNull);
      });
    }
  });

  group('HorarioAtencion.desdeConfig', () {
    final sucursales = [
      {'sucursal': 'Sucursal Aviacion', 'horario': 'Lun - Dom: 8:00 AM - 9:00 PM'},
      {'sucursal': 'Sucursal Tahuizan', 'horario': 'Lun - Dom: 9:00 AM - 10:00 PM'},
    ];

    test('la lista del panel: las horas en que abren todas', () {
      expect(_tramos(HorarioAtencion.desdeConfig(sucursales)),
          _todaLaSemana(_min(9), _min(21)));
    });

    test('la misma lista en JSON, un mapa o un texto suelto', () {
      expect(_tramos(HorarioAtencion.desdeConfig(jsonEncode(sucursales))),
          _todaLaSemana(_min(9), _min(21)));
      expect(
        _tramos(HorarioAtencion.desdeConfig(
            {'sucursal': 'Única', 'horario': 'Diario 9 a 21'})),
        _todaLaSemana(_min(9), _min(21)),
      );
      expect(
        _tramos(HorarioAtencion.desdeConfig(['Lun - Dom 9 a 21'])),
        _todaLaSemana(_min(9), _min(21)),
      );
      expect(
        _tramos(HorarioAtencion.desdeConfig('  Lun a Sáb 9 a 8 ')).keys,
        hasLength(6),
      );
    });

    test('si una sucursal no abre el domingo, el domingo no abre', () {
      final horario = HorarioAtencion.desdeConfig([
        {'horario': 'Lun - Dom 9 a 21'},
        {'horario': 'Lun - Sáb 10 a 22'},
      ]);
      expect(horario!.abreEl(_domingo), isFalse);
      expect(_tramos(horario)[DateTime.monday], [(_min(10), _min(21))]);
    });

    for (final (horarios, motivo) in <(Object?, String)>[
      (null, 'sin horario'),
      ('', 'texto vacío'),
      ('[roto', 'JSON roto'),
      (<Object?>[], 'lista vacía'),
      ([
        {'sucursal': 'Única'},
      ], 'una sucursal sin horario'),
      ([
        {'horario': 'Lun - Dom 9 a 21'},
        {'horario': 'cuando se pueda'},
      ], 'una sucursal que no se entiende'),
      ([
        {'horario': 'Lun 9 a 14'},
        {'horario': 'Mar 9 a 14'},
      ], 'sin un día en común'),
      ([
        {'horario': 'Lun 9 a 12'},
        {'horario': 'Lun 13 a 20'},
      ], 'sin una hora en común'),
      (42, 'otro tipo'),
    ]) {
      test('null: $motivo', () {
        expect(HorarioAtencion.desdeConfig(horarios), isNull);
      });
    }
  });

  group('HorarioAtencion: consultas', () {
    final respaldo = HorarioAtencion.semanal(
      dias: [1, 2, 3, 4, 5, 6],
      abre: 9,
      cierra: 21,
    );

    test('abre el lunes y no el domingo', () {
      expect(respaldo.abreEl(_lunes), isTrue);
      expect(respaldo.abreEl(_domingo), isFalse);
      expect(respaldo.abreAlgunDia, isTrue);
      expect(const HorarioAtencion({}).abreAlgunDia, isFalse);
    });

    test('abierto de 9:00 a 20:59', () {
      DateTime lunesA(int h, [int m = 0]) => DateTime(2026, 11, 9, h, m);
      expect(respaldo.abiertoEn(lunesA(8, 59)), isFalse);
      expect(respaldo.abiertoEn(lunesA(9)), isTrue);
      expect(respaldo.abiertoEn(lunesA(20, 59)), isTrue);
      expect(respaldo.abiertoEn(lunesA(21)), isFalse);
      expect(respaldo.abiertoEn(DateTime(2026, 11, 8, 12)), isFalse);
    });

    test('solo las franjas que caben completas en el horario del día', () {
      const franjas = [
        '08:00 - 09:00',
        '09:00 - 10:00',
        '20:00 - 21:00',
        '20:30 - 21:30',
        'a la hora que sea',
        '10 - 11',
      ];
      expect(respaldo.franjasDel(_lunes, franjas),
          ['09:00 - 10:00', '20:00 - 21:00']);
      expect(respaldo.franjasDel(_domingo, franjas), isEmpty);
    });

    test('la siguiente apertura: hoy, mañana o el siguiente día que abre', () {
      expect(respaldo.siguienteApertura(DateTime(2026, 11, 9, 7, 15)),
          DateTime(2026, 11, 9, 9));
      expect(respaldo.siguienteApertura(DateTime(2026, 11, 9, 22)),
          DateTime(2026, 11, 10, 9));
      // Sábado en la noche: el domingo no abre, sigue el lunes.
      expect(respaldo.siguienteApertura(_sabado.add(const Duration(hours: 22))),
          DateTime(2026, 11, 9, 9));
      expect(const HorarioAtencion({}).siguienteApertura(_lunes), isNull);
    });

    test('la intersección deja sin tramos el día en que no coinciden', () {
      final manana = HorarioAtencion.semanal(dias: [1], abre: 9, cierra: 12);
      final tarde = HorarioAtencion.semanal(dias: [1], abre: 13, cierra: 20);
      expect(_tramos(manana.interseccion(tarde)), {
        DateTime.monday: <(int, int)>[],
      });
    });
  });
}
