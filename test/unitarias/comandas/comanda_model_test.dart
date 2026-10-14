// test/unitarias/comandas/comanda_model_test.dart — modelo del resumen de la
// agenda de comandas (#127) y textos de fechas de la agenda.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/comandas_formato.dart';

import '../../fakes/comandas_json.dart';

void main() {
  group('ResumenComanda.fromJson', () {
    test('lee la cabecera, el semáforo y las firmas', () {
      final c = ResumenComanda.fromJson(
        comandaJson(
          id: 7,
          folio: 5003,
          hora: '16:30',
          dias: 0,
          semaforo: 'rojo',
          version: 2,
          imagenes: 3,
          hornos: firmaJson(
            vigente: true,
            version: 2,
            usuario: 'Rosa Pérez',
            fecha: 'x',
          ),
          decoracion: firmaJson(version: 1, usuario: 'Leo Díaz'),
        ),
      );

      expect(c.id, 7);
      expect(c.folio, 5003);
      expect(c.estado, EstadoComanda.activa);
      expect(c.clienteNombre, 'María López');
      expect(c.fechaEntrega, '2026-10-14');
      expect(c.horaEntrega, '16:30');
      expect(c.diasRestantes, 0);
      expect(c.semaforo, Semaforo.rojo);
      expect(c.version, 2);
      expect(c.resumen, 'Pastel Chocolate · 20 personas');
      expect(c.numImagenes, 3);
      expect(c.tomadoPorNombre, 'Laura Cruz');
      expect(c.firma(AreaProduccion.hornos).estado, EstadoFirma.vigente);
      expect(c.firma(AreaProduccion.hornos).usuarioNombre, 'Rosa Pérez');
      expect(c.firma(AreaProduccion.decoracion).estado, EstadoFirma.refirmar);
    });

    test('sin montos para producción: quedan en null, nunca en cero', () {
      final c = ResumenComanda.fromJson(comandaJson());

      expect(c.total, isNull);
      expect(c.anticipo, isNull);
      expect(c.saldo, isNull);
    });

    test('los montos de NUMERIC llegan como texto', () {
      final c = ResumenComanda.fromJson(
        comandaJson(total: '850.00', anticipo: '200.00', saldo: '650.00'),
      );

      expect(c.total, 850);
      expect(c.anticipo, 200);
      expect(c.saldo, 650);
    });

    test('firma ausente o rara cuenta como pendiente', () {
      final json = comandaJson()..['firmas'] = {'hornos': 'x'};
      final c = ResumenComanda.fromJson(json);

      expect(c.firma(AreaProduccion.hornos).estado, EstadoFirma.pendiente);
      expect(c.firma(AreaProduccion.decoracion).estado, EstadoFirma.pendiente);
    });

    test('pendientePara: activa y sin la firma vigente del área', () {
      final c = ResumenComanda.fromJson(
        comandaJson(
          hornos: firmaJson(vigente: true, version: 1, usuario: 'Rosa'),
        ),
      );

      expect(c.pendientePara(AreaProduccion.hornos), isFalse);
      expect(c.pendientePara(AreaProduccion.decoracion), isTrue);
      final entregada = ResumenComanda.fromJson(
        comandaJson(estado: 'entregada'),
      );
      expect(entregada.pendientePara(AreaProduccion.decoracion), isFalse);
    });

    test('estado y semáforo desconocidos no truenan', () {
      final c = ResumenComanda.fromJson(
        comandaJson(estado: 'otro', semaforo: 'morado'),
      );

      expect(c.estado, EstadoComanda.activa);
      expect(c.semaforo, isNull);
    });
  });

  group('AgendaComandas.fromJson', () {
    test('trae hoy y las comandas', () {
      final a = AgendaComandas.fromJson(
        agendaJson([comandaJson(), comandaJson(id: 2)], hoy: '2026-10-13'),
      );

      expect(a.hoy, '2026-10-13');
      expect(a.comandas.map((c) => c.id), [1, 2]);
    });

    test('sin lista de comandas devuelve una agenda vacía', () {
      final a = AgendaComandas.fromJson({'success': true, 'hoy': '2026-10-12'});

      expect(a.comandas, isEmpty);
    });
  });

  group('Enumeraciones', () {
    test('semáforo con sus etiquetas de la web', () {
      expect(Semaforo.values.map((s) => s.etiqueta), [
        'Vencida',
        'Urgente',
        'Muy pronto',
        'Esta semana',
        'Con tiempo',
      ]);
    });

    test('área de producción a partir del rol', () {
      expect(AreaProduccion.deRol('hornos'), AreaProduccion.hornos);
      expect(AreaProduccion.deRol('decoracion'), AreaProduccion.decoracion);
      expect(AreaProduccion.deRol('empleado'), isNull);
      expect(AreaProduccion.deRol(null), isNull);
      expect(AreaProduccion.decoracion.etiqueta, 'Decoración');
    });

    test('vistas de la agenda con su valor para el backend', () {
      expect(VistaAgenda.values.map((v) => v.name), [
        'proximas',
        'activas',
        'entregadas',
        'canceladas',
      ]);
      expect(VistaAgenda.proximas.etiqueta, 'Próximos 15 días');
      expect(VistaAgenda.entregadas.esHistorica, isTrue);
      expect(VistaAgenda.activas.esHistorica, isFalse);
    });
  });

  group('Textos de fechas', () {
    test('hora en formato de 12 horas', () {
      expect(horaLegible('09:05'), '9:05 a. m.');
      expect(horaLegible('12:00'), '12:00 p. m.');
      expect(horaLegible('00:30'), '12:30 a. m.');
      expect(horaLegible('18:45'), '6:45 p. m.');
      expect(horaLegible('raro'), 'raro');
    });

    test('encabezado del día', () {
      expect(
        etiquetaDia('2026-10-12', 0, anioActual: 2026),
        'Hoy · lunes 12 de octubre',
      );
      expect(
        etiquetaDia('2026-10-13', 1, anioActual: 2026),
        'Mañana · martes 13 de octubre',
      );
      expect(
        etiquetaDia('2026-10-11', -1, anioActual: 2026),
        'Ayer · domingo 11 de octubre',
      );
      expect(
        etiquetaDia('2026-10-17', 5, anioActual: 2026),
        'Sábado 17 de octubre',
      );
      expect(
        etiquetaDia('2027-01-02', 82, anioActual: 2026),
        'Sábado 2 de enero de 2027',
      );
      expect(etiquetaDia('raro', 3), 'raro');
    });

    test('días que faltan', () {
      expect(textoDiasRestantes(0), 'Es hoy');
      expect(textoDiasRestantes(1), 'Es mañana');
      expect(textoDiasRestantes(4), 'Faltan 4 días');
      expect(textoDiasRestantes(-1), 'Venció ayer');
      expect(textoDiasRestantes(-3), 'Venció hace 3 días');
    });

    test('día de un evento en hora de Huejutla (UTC-6)', () {
      expect(diaDeEvento('2026-10-12T03:00:00.000Z'), '2026-10-11');
      expect(diaDeEvento('2026-10-12T18:00:00.000Z'), '2026-10-12');
      expect(diaDeEvento('raro'), isNull);
    });

    test('días entre dos fechas', () {
      expect(diasEntre('2026-10-12', '2026-10-15'), 3);
      expect(diasEntre('2026-10-12', '2026-10-10'), -2);
      expect(diasEntre('2026-10-31', '2026-11-01'), 1);
    });
  });
}
