// test/fakes/pedidos_del_dia_json.dart — respuestas del backend para
// «Pedidos del día» (#137). El reloj de las pruebas es el 12 de octubre de
// 2026 a las 12:00 de México (18:00 UTC).
import 'package:pier_reposteria/config/api_constants.dart';

/// 12-oct-2026, 12:00 en México.
DateTime ahoraPedidos() => DateTime.utc(2026, 10, 12, 18);

Map<String, dynamic> pedidoJson({
  required int id,
  String estado = 'pendiente',
  bool domicilio = false,
  bool porConfirmar = false,
  String? compromiso = '2026-10-12T20:00:00.000Z',
  int? entregaId,
  String? repartidor,
}) =>
    {
      'id': id,
      'numero': 'PIER-$id',
      'estado': estado,
      'tipo_entrega': domicilio ? 'domicilio' : 'pickup',
      'por_confirmar': porConfirmar,
      'total': '350.00',
      'cliente_nombre': 'Ana',
      'cliente_apellido': 'Ruiz',
      'cliente_telefono': '7711234567',
      'compromiso': compromiso,
      'entrega_id': entregaId,
      'repartidor_nombre': repartidor,
      'repartidor_apellido': repartidor == null ? null : 'P.',
      'direccion_entrega': domicilio
          ? {'calle_numero': 'Juárez 10', 'colonia': 'Centro'}
          : null,
      'notas': null,
      'items': [
        {'nombre': 'Pastel de chocolate', 'cantidad': 1, 'tamano': 'grande'},
      ],
    };

/// Uno de cada sección, más uno de pasado mañana y uno sin hora.
Map<String, dynamic> get abiertosJson => {
      'success': true,
      'pedidos': [
        pedidoJson(id: 2, porConfirmar: true,
            compromiso: '2026-10-12T16:00:00.000Z'),
        pedidoJson(id: 3, estado: 'listo',
            compromiso: '2026-10-11T22:00:00.000Z'),
        pedidoJson(id: 1),
        pedidoJson(id: 4, estado: 'listo', domicilio: true,
            compromiso: '2026-10-12T19:00:00.000Z'),
        pedidoJson(id: 5, estado: 'asignado', domicilio: true, entregaId: 9,
            repartidor: 'Luis'),
        pedidoJson(id: 6, estado: 'entrega_fallida', domicilio: true),
        pedidoJson(id: 7, compromiso: '2026-10-14T18:00:00.000Z'),
        pedidoJson(id: 8, estado: 'en_preparacion', compromiso: null),
      ],
    };

Map<String, dynamic> get repartidoresJson => {
      'success': true,
      'repartidores': [
        {
          'id': 21,
          'nombre': 'Luis',
          'apellido': 'Pérez',
          'disponible': true,
          'entregas_activas': '2',
        },
        {'id': 22, 'nombre': 'Rosa', 'apellido': null, 'disponible': false},
        'basura',
      ],
    };

String get pedidosAbiertos => ApiConstants.pedidosAbiertos;
