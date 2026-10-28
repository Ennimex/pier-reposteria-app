// lib/domain/models/pedido_del_dia.dart
//
// Pedidos de la sucursal para el personal (#137), con el mismo contrato que
// la web (src/Empleado/paginas/GestionPedidos.tsx):
// GET /pedidos?vista=abiertos&completo=1 -> pedidos[{id, numero, estado,
// tipo_entrega, por_confirmar, total, cliente_nombre, cliente_apellido,
// cliente_telefono, compromiso, entrega_id, repartidor_nombre,
// repartidor_apellido, direccion_entrega{…}, notas, items[{nombre,
// cantidad, tamano}]}] y GET /entregas/repartidores -> repartidores[{id,
// nombre, apellido, telefono, disponible, entregas_activas}].
// `compromiso` es la hora de recogida o de entrega (o la de creación) en
// UTC; la app la muestra y la compara en la hora de México (UTC−6 todo el
// año desde 2022, como la sucursal).

/// Hora de México de un instante en UTC.
DateTime horaDeMexico(DateTime instante) =>
    instante.toUtc().subtract(const Duration(hours: 6));

/// La sección de la pantalla donde va un pedido, en orden.
enum GrupoPedido {
  porConfirmar('Por confirmar'),
  pendientes('Por preparar'),
  listosRecoger('Listos para recoger'),
  listosEnvio('Listos para enviar'),
  enReparto('En reparto'),
  fallidos('Entrega fallida');

  const GrupoPedido(this.titulo);

  final String titulo;
}

class PedidoDelDia {
  const PedidoDelDia({
    required this.id,
    required this.numero,
    required this.estado,
    required this.esDomicilio,
    required this.total,
    required this.cliente,
    this.porConfirmar = false,
    this.telefono,
    this.compromiso,
    this.entregaId,
    this.repartidor,
    this.direccion,
    this.notas,
    this.productos = const [],
  });

  /// null si falta el id.
  static PedidoDelDia? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    String? texto(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    String nombre(Object? n, Object? a) =>
        [texto(n), texto(a)].whereType<String>().join(' ');
    final direccion = json['direccion_entrega'];
    return PedidoDelDia(
      id: id,
      numero: texto(json['numero']) ?? id,
      estado: texto(json['estado']) ?? 'pendiente',
      esDomicilio: json['tipo_entrega'] == 'domicilio',
      porConfirmar: json['por_confirmar'] == true ||
          json['por_confirmar']?.toString() == 'true',
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0,
      cliente: nombre(json['cliente_nombre'], json['cliente_apellido']),
      telefono: texto(json['cliente_telefono']),
      compromiso: DateTime.tryParse(json['compromiso']?.toString() ?? ''),
      entregaId: texto(json['entrega_id']),
      repartidor: texto(
          nombre(json['repartidor_nombre'], json['repartidor_apellido'])),
      direccion: direccion is Map
          ? texto([direccion['calle_numero'], direccion['colonia']]
              .map(texto)
              .whereType<String>()
              .join(', '))
          : null,
      notas: texto(json['notas']),
      productos: [
        if (json['items'] case final List items)
          for (final i in items)
            if (i is Map && texto(i['nombre']) != null)
              [
                '${i['cantidad'] ?? 1} × ${texto(i['nombre'])}',
                if (texto(i['tamano']) case final t?) '($t)',
              ].join(' '),
      ],
    );
  }

  final String id;
  final String numero;

  /// Estado del backend: pendiente, en_preparacion, listo, asignado,
  /// en_camino o entrega_fallida (los abiertos).
  final String estado;
  final bool esDomicilio;
  final bool porConfirmar;
  final double total;
  final String cliente;
  final String? telefono;

  /// Hora comprometida, en UTC.
  final DateTime? compromiso;

  /// La entrega activa (asignada o en camino); null si no tiene.
  final String? entregaId;
  final String? repartidor;
  final String? direccion;
  final String? notas;

  /// «2 × Pastel de chocolate (grande)».
  final List<String> productos;

  GrupoPedido get grupo {
    if (porConfirmar) return GrupoPedido.porConfirmar;
    return switch (estado) {
      'listo' when esDomicilio && entregaId == null => GrupoPedido.listosEnvio,
      'listo' when !esDomicilio => GrupoPedido.listosRecoger,
      'listo' || 'asignado' || 'en_camino' => GrupoPedido.enReparto,
      'entrega_fallida' => GrupoPedido.fallidos,
      _ => GrupoPedido.pendientes,
    };
  }

  /// Día de calendario comprometido en México; null sin hora.
  DateTime? get diaComprometido {
    final c = compromiso;
    if (c == null) return null;
    final m = horaDeMexico(c);
    return DateTime.utc(m.year, m.month, m.day);
  }
}

/// Un repartidor para asignarle la entrega.
class RepartidorDisponible {
  const RepartidorDisponible({
    required this.id,
    required this.nombre,
    this.disponible = false,
    this.entregasActivas = 0,
  });

  static RepartidorDisponible? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = (json['id'] as num?)?.toInt() ??
        int.tryParse(json['id']?.toString() ?? '');
    if (id == null) return null;
    return RepartidorDisponible(
      id: id,
      nombre: [json['nombre'], json['apellido']]
          .map((x) => x?.toString().trim() ?? '')
          .where((x) => x.isNotEmpty)
          .join(' '),
      disponible: json['disponible'] == true,
      entregasActivas:
          int.tryParse(json['entregas_activas']?.toString() ?? '') ?? 0,
    );
  }

  final int id;
  final String nombre;
  final bool disponible;
  final int entregasActivas;
}
