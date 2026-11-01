// test/fakes/mis_pedidos_json.dart — «Mis Pedidos» del cliente en un backend
// falso en memoria, para las pruebas de aceptación de los pedidos (#64;
// historias #39 y #40).
//
// Responde como routes/pedidosRoutes.js del backend: GET
// /pedidos/mis-pedidos trae cada pedido con sus productos; GET /pedidos/:id,
// el pedido y sus productos aparte; PUT /pedidos/:id/cancelar solo acepta un
// pedido «pendiente» o «listo» y, si se pagó en línea, genera la solicitud
// de reembolso. Los montos llegan como texto (NUMERIC de Postgres) y las
// fechas en UTC, igual que en el backend.
import 'package:pier_reposteria/config/api_constants.dart';

import 'fake_api_client.dart';

/// Respuesta del backend al iniciar sesión como cliente.
const Map<String, dynamic> _sesion = {
  'success': true,
  'token': 'jwt',
  'user': {
    'id': 1,
    'nombre': 'Ana',
    'apellido': 'López',
    'email': 'ana@pier.mx',
    'rol': 'cliente',
  },
};

/// Un producto de un pedido: [cantidad] piezas de [nombre] a [precio] cada
/// una.
Map<String, dynamic> productoDelPedidoJson(
  String nombre, {
  required num precio,
  int cantidad = 1,
  String? tamano,
}) => {
  'nombre': nombre,
  'cantidad': cantidad,
  'tamano': tamano,
  'precio_unitario': precio.toStringAsFixed(2),
  'subtotal': (precio * cantidad).toStringAsFixed(2),
};

/// Un pedido del cliente, número PIER-261031-000N, hecho el 31 de octubre de
/// 2026 a las 09:05 de México (15:05 UTC). Sin [productos], dos Chocoflan
/// grandes de $150. [porConfirmar]: programado, la sucursal aún lo confirma
/// (así nace hoy un pedido «pendiente»); [pagadoEnLinea]: se cobró con
/// tarjeta.
Map<String, dynamic> miPedidoJson({
  required int id,
  required String estado,
  bool domicilio = false,
  bool porConfirmar = false,
  bool pagadoEnLinea = true,
  List<Map<String, dynamic>>? productos,
}) {
  final items =
      productos ??
      [
        productoDelPedidoJson(
          'Chocoflan',
          precio: 150,
          cantidad: 2,
          tamano: 'grande',
        ),
      ];
  final total = items.fold<num>(
    0,
    (suma, item) => suma + num.parse('${item['subtotal']}'),
  );
  return {
    'id': id,
    'numero': 'PIER-261031-${id.toString().padLeft(4, '0')}',
    'estado': estado,
    'tipo_entrega': domicilio ? 'domicilio' : 'pickup',
    'por_confirmar': porConfirmar,
    'total': total.toStringAsFixed(2),
    'estado_pago': pagadoEnLinea ? 'pagado' : null,
    'created_at': '2026-10-31T15:05:00.000Z',
    'items': items,
    'reembolso': null,
  };
}

/// Los pedidos del cliente como los tiene el backend. Las pruebas pueden
/// cambiarlos con la app abierta, como lo haría otra persona: un repartidor
/// toma un pedido con [asignarRepartidor].
class BackendMisPedidos {
  BackendMisPedidos(List<Map<String, dynamic>> iniciales)
    : pedidos = [for (final p in iniciales) {...p}] {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.login: _sesion,
        ApiConstants.misPedidos: _misPedidos,
        for (final p in pedidos) ...{
          ApiConstants.pedidoById('${p['id']}'): _detalle,
          ApiConstants.pedidoCancelar('${p['id']}'): _cancelar,
        },
      },
    );
  }

  /// Lo que responde el backend si un repartidor ya tomó el pedido.
  static const String yaTomado =
      'Un repartidor ya tomó tu pedido; ya no es posible cancelarlo';

  /// Los pedidos, del más nuevo al más viejo.
  final List<Map<String, dynamic>> pedidos;
  late final FakeApiClient api;

  /// El pedido [id] tal como lo tiene el backend.
  Map<String, dynamic> pedido(int id) =>
      pedidos.firstWhere((p) => p['id'] == id);

  /// Un repartidor toma el pedido [id] desde su app.
  void asignarRepartidor(int id) {
    pedido(id)['estado'] = 'asignado';
  }

  /// GET /pedidos/mis-pedidos.
  Map<String, dynamic> _misPedidos(LlamadaApi _) => {
    'success': true,
    'pedidos': [for (final p in pedidos) {...p}],
  };

  /// GET /pedidos/:id: el pedido y, aparte, sus productos.
  Map<String, dynamic> _detalle(LlamadaApi llamada) {
    final p = _delEndpoint(llamada);
    final datos = {...p}..remove('items');
    return {'success': true, 'pedido': datos, 'items': p['items']};
  }

  /// PUT /pedidos/:id/cancelar, con la regla y los mensajes del backend.
  Map<String, dynamic> _cancelar(LlamadaApi llamada) {
    final p = _delEndpoint(llamada);
    final estado = p['estado'];
    if (estado != 'pendiente' && estado != 'listo') {
      return {
        'success': false,
        'message': estado == 'asignado' || estado == 'en_camino'
            ? yaTomado
            : 'Este pedido ya no puede cancelarse',
      };
    }
    p
      ..['estado'] = 'cancelado'
      ..['por_confirmar'] = false;
    if (p['estado_pago'] != 'pagado') {
      return {
        'success': true,
        'message': 'Pedido cancelado',
        'reembolso_generado': false,
      };
    }
    p['reembolso'] = {'id': 1, 'estado': 'pendiente', 'monto': p['total']};
    return {
      'success': true,
      'message':
          'Pedido cancelado; generamos tu solicitud de reembolso por '
          '\$${p['total']}',
      'reembolso_generado': true,
    };
  }

  /// El pedido de /pedidos/:id o de /pedidos/:id/cancelar.
  Map<String, dynamic> _delEndpoint(LlamadaApi llamada) =>
      pedido(int.parse(llamada.endpoint.split('/')[2]));
}
