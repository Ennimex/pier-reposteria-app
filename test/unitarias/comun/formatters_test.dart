// test/unitarias/comun/formatters_test.dart — #216: las fechas del backend
// llegan en UTC y se muestran en la hora de México (UTC−6), sin depender de
// la zona del teléfono; el checkout manda el horario en UTC, como la web.
@Tags(['regresion'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/utils/formatters.dart';

void main() {
  group('Fechas en la hora de México', () {
    test('restan 6 horas a UTC', () {
      final mexico = enHoraDeMexico(DateTime.utc(2026, 10, 27, 11, 3));

      expect((mexico.year, mexico.month, mexico.day), (2026, 10, 27));
      expect((mexico.hour, mexico.minute), (5, 3));
    });

    test('fechaConHora: el pedido de las 05:03 ya no sale a las 11:03', () {
      expect(fechaConHora(DateTime.utc(2026, 10, 27, 11, 3)),
          '27 Oct 2026 · 05:03 hrs');
    });

    test('fechaCorta: de noche en México todavía es el día anterior', () {
      // 03:00 UTC del 28 son las 21:00 del 27 en México.
      expect(fechaCorta(DateTime.utc(2026, 10, 28, 3)), '27 Oct 2026');
    });

    test('no depende de la zona del teléfono', () {
      final instante = DateTime.utc(2026, 10, 27, 11, 3);

      expect(fechaConHora(instante.toLocal()), fechaConHora(instante));
    });
  });

  group('horarioDelPedido', () {
    test('un horario ISO en UTC sale en la hora de México', () {
      expect(horarioDelPedido('2026-10-28T15:00:00.000Z'),
          '28 Oct 2026 · 09:00 hrs');
    });

    test('si no es una fecha se muestra tal cual', () {
      expect(horarioDelPedido('10:00 - 11:00'), '10:00 - 11:00');
    });
  });

  group('horarioEnUtc', () {
    test('las 09:00 de México son las 15:00 UTC, como lo manda la web', () {
      expect(horarioEnUtc(DateTime(2026, 10, 28), '09:00'),
          '2026-10-28T15:00:00.000Z');
    });

    test('las 20:00 de México ya son el día siguiente en UTC', () {
      expect(horarioEnUtc(DateTime(2026, 10, 28), '20:00'),
          '2026-10-29T02:00:00.000Z');
    });

    test('ida y vuelta: lo que se manda se muestra con la hora elegida', () {
      expect(horarioDelPedido(horarioEnUtc(DateTime(2026, 11, 3), '13:00')),
          '3 Nov 2026 · 13:00 hrs');
    });
  });
}
