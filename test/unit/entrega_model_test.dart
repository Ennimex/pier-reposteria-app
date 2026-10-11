// test/unit/entrega_model_test.dart — modelos del repartidor (MVVM, Fase 5):
// la dirección que llega como Map o como texto JSON (una o dos veces
// serializado), la entrega con su snapshot del pedido y el pool de pedidos.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

void main() {
  group('DireccionEntrega.parse', () {
    const mapa = {
      'alias': 'Casa',
      'calle_numero': 'Juárez 12',
      'colonia': 'Centro',
      'referencias': ' Portón azul ',
      'telefono_contacto': '771 123 4567',
      'lat': '21.14',
      'lng': -98.42,
    };

    test('lee un Map con coordenadas', () {
      final d = DireccionEntrega.parse(mapa);
      expect(d.alias, 'Casa');
      expect(d.calleNumero, 'Juárez 12');
      expect(d.referencias, 'Portón azul');
      expect(d.telefonoContacto, '771 123 4567');
      expect(d.tieneCoordenadas, isTrue);
      expect(d.destinoMaps, '21.14,-98.42');
      expect(d.isEmpty, isFalse);
    });

    test('acepta texto JSON, incluso doblemente serializado', () {
      final una = DireccionEntrega.parse(jsonEncode(mapa));
      final dos = DireccionEntrega.parse(jsonEncode(jsonEncode(mapa)));
      expect(una.colonia, 'Centro');
      expect(dos.colonia, 'Centro');
    });

    test('acepta las llaves en camelCase', () {
      final d = DireccionEntrega.parse(
          {'calleNumero': 'Hidalgo 3', 'telefonoContacto': '7710000000'});
      expect(d.calleNumero, 'Hidalgo 3');
      expect(d.telefonoContacto, '7710000000');
      expect(d.tieneCoordenadas, isFalse);
      expect(d.destinoMaps, 'Hidalgo 3, Huejutla de Reyes');
    });

    test('lo que no es dirección queda vacío', () {
      for (final raw in [null, '', '  ', 'Calle sin JSON', '{roto', 42]) {
        final d = DireccionEntrega.parse(raw);
        expect(d.isEmpty, isTrue, reason: '$raw');
        expect(d.destinoMaps, 'Huejutla de Reyes', reason: '$raw');
      }
    });
  });

  group('EntregaRepartidor.fromJson', () {
    test('lee el snapshot del pedido, del cliente y las fechas', () {
      final e = EntregaRepartidor.fromJson({
        'id': 9,
        'pedido_id': 41,
        'estado': 'EN_CAMINO',
        'numero': 'PIER-0041',
        'total': '450.50',
        'costo_envio': 30,
        'metodo_pago': 'Efectivo',
        'notas': ' ',
        'cliente_nombre': 'ana',
        'cliente_apellido': 'López',
        'cliente_telefono': '7711234567',
        'finalizado_at': '2026-10-10T15:30:00Z',
        'direccion_entrega': {'colonia': 'Centro'},
      });
      expect(e.id, '9');
      expect(e.pedidoId, '41');
      expect(e.estado, EstadoEntrega.enCamino);
      expect(e.total, 450.5);
      expect(e.costoEnvio, 30);
      expect(e.notas, isNull);
      expect(e.esEfectivo, isTrue);
      expect(e.isActiva, isTrue);
      expect(e.clienteNombreCompleto, 'ana López');
      expect(e.iniciales, 'AL');
      expect(e.finalizadoAt, DateTime.utc(2026, 10, 10, 15, 30).toLocal());
      expect(e.salioAt, isNull);
      expect(e.direccion.colonia, 'Centro');
    });

    test('sin datos usa valores vacíos', () {
      final e = EntregaRepartidor.fromJson(const {});
      expect(e.estado, EstadoEntrega.desconocido);
      expect(e.total, 0);
      expect(e.iniciales, '?');
      expect(e.esEfectivo, isFalse);
      expect(e.isActiva, isFalse);
    });

    test('reconoce cada estado del backend', () {
      expect(EntregaRepartidor.parseEstado('asignada'), EstadoEntrega.asignada);
      expect(EntregaRepartidor.parseEstado('entregada'),
          EstadoEntrega.entregada);
      expect(EntregaRepartidor.parseEstado('fallida'), EstadoEntrega.fallida);
      expect(EntregaRepartidor.parseEstado(null), EstadoEntrega.desconocido);
    });
  });

  test('PedidoDisponible.fromJson lee el pool', () {
    final p = PedidoDisponible.fromJson({
      'pedido_id': 41,
      'numero': 'PIER-0041',
      'total': 300,
      'costo_envio': '25',
      'horario_entrega': '2026-10-10T09:00:00',
      'notas': 'Sin nuez',
      'cliente_nombre': 'Luis',
      'cliente_apellido': '',
      'direccion_entrega': '{"colonia":"Aviación"}',
    });
    expect(p.pedidoId, '41');
    expect(p.total, 300);
    expect(p.costoEnvio, 25);
    expect(p.notas, 'Sin nuez');
    expect(p.horarioEntrega, '2026-10-10T09:00:00');
    expect(p.clienteNombreCompleto, 'Luis');
    expect(p.direccion.colonia, 'Aviación');
  });

  test('EstadoEntregaX: etiqueta, color y valor para el backend', () {
    expect(EstadoEntrega.values.map((e) => e.label), [
      'Asignada', 'En camino', 'Entregada', 'Fallida', 'Sin estado', //
    ]);
    expect(EstadoEntrega.values.map((e) => e.apiValue),
        ['', 'en_camino', 'entregada', 'fallida', '']);
    expect(EstadoEntrega.asignada.color, AppColors.estadoAsignada);
    expect(EstadoEntrega.enCamino.color, AppColors.estadoEnCamino);
    expect(EstadoEntrega.entregada.color, AppColors.estadoEntregada);
    expect(EstadoEntrega.fallida.color, AppColors.estadoFallida);
    expect(EstadoEntrega.desconocido.color, AppColors.textSecondary);
  });

  test('inicialesDe toma la primera letra de nombre y apellido', () {
    expect(inicialesDe(' maría ', 'pérez'), 'MP');
    expect(inicialesDe('Luis', ''), 'L');
    expect(inicialesDe('', ''), '?');
  });
}
