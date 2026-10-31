// test/fakes/entregas_json.dart — el panel del repartidor en un backend
// falso en memoria, para las pruebas de aceptación de las historias #45 y
// #46 (#68).
//
// Guarda la disponibilidad, el pool de pedidos listos y las entregas del
// repartidor sobre un FakeApiClient y responde como
// routes/entregasRoutes.js: el pool no depende de la disponibilidad (se
// revisa al aceptar), aceptar convierte el pedido en una entrega asignada,
// el estado solo avanza de asignada a en camino y a entregada (o fallida) y
// «Llegué» solo se avisa en camino. Los rechazos llevan los mismos mensajes
// que el backend.
//
//   final backend = BackendEntregas(pool: [pedidoListoJson(41)]);
//   await abrirPanelRepartidor(tester, backend); // helpers/montar_repartidor
//   ...
//   expect(backend.entregas.single['estado'], 'asignada');
import 'package:pier_reposteria/config/api_constants.dart';

import 'fake_api_client.dart';

/// Respuesta del backend al iniciar sesión como repartidor.
const Map<String, dynamic> _sesion = {
  'success': true,
  'token': 'jwt',
  'user': {
    'id': 9,
    'nombre': 'Luis',
    'apellido': 'Hernández',
    'email': 'luis@pier.mx',
    'telefono': '7711234567',
    'rol': 'repartidor',
  },
};

/// Cuándo se cierran las entregas que se finalizan en la prueba. Va sin
/// zona horaria: se lee como hora local y lo que se ve no depende del huso
/// de la máquina (CI corre en UTC).
const String horaDeCierre = '2026-10-20T13:45:00';

/// Un pedido a domicilio listo y sin repartidor, como lo lista
/// GET /entregas/disponibles.
Map<String, dynamic> pedidoListoJson(int id) => {
  'pedido_id': id,
  'numero': 'PIER-$id',
  'total': 300,
  'cliente_nombre': 'Ana',
  'cliente_apellido': 'López',
  'horario_entrega': '2026-10-20T18:00:00.000Z',
  'direccion_entrega': {'calle_numero': 'Juárez 12', 'colonia': 'Aviación'},
};

/// Una entrega del repartidor, como la lista GET /entregas/mis-entregas.
Map<String, dynamic> entregaJson(
  int id,
  int pedidoId, {
  String estado = 'asignada',
  num total = 330,
}) => {
  'id': id,
  'pedido_id': pedidoId,
  'estado': estado,
  'numero': 'PIER-$pedidoId',
  'total': total,
  'costo_envio': 30,
  'metodo_pago': 'tarjeta',
  'cliente_nombre': 'Ana',
  'cliente_apellido': 'López',
  'cliente_telefono': '7719998888',
  'horario_entrega': '2026-10-20T18:00:00.000Z',
  'direccion_entrega': {'calle_numero': 'Juárez 12', 'colonia': 'Centro'},
};

/// Backend del repartidor en memoria; [api] es el cliente que recibe la app.
class BackendEntregas {
  BackendEntregas({
    this.disponible = true,
    List<Map<String, dynamic>> pool = const [],
    List<Map<String, dynamic>> entregas = const [],
  }) : pool = [for (final p in pool) {...p}],
       entregas = [for (final e in entregas) {...e}] {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.login: _sesion,
        ApiConstants.disponibilidad: _disponibilidad,
        ApiConstants.entregasDisponibles: _listarPool,
        ApiConstants.entregasAceptar: _aceptar,
        ApiConstants.misEntregas: _listarEntregas,
        ApiConstants.uploadImagen: _subirFoto,
        // Cada entrega (las que ya tiene y las que el backend asigna al
        // aceptar) con su cambio de estado y su «Llegué».
        for (final id in [
          for (final e in this.entregas) '${e['id']}',
          for (var n = _primerId; n < _primerId + 5; n++) '$n',
        ]) ...{
          ApiConstants.entregaEstado(id): _cambiarEstado,
          ApiConstants.entregaLlegue(id): _avisarLlegada,
        },
      },
    );
  }

  /// Id que el backend le da a la primera entrega nueva.
  static const int _primerId = 100;

  /// PUT /entregas/:id/estado: a qué estado se puede pasar y desde cuáles.
  static const Map<String, List<String>> _desde = {
    'en_camino': ['asignada'],
    'entregada': ['asignada', 'en_camino'],
    'fallida': ['asignada', 'en_camino'],
  };

  late final FakeApiClient api;

  /// Si el repartidor recibe entregas (tblusuarios.disponible).
  bool disponible;

  /// Pedidos listos para tomar, en orden.
  final List<Map<String, dynamic>> pool;

  /// Las entregas del repartidor, en orden.
  final List<Map<String, dynamic>> entregas;

  /// Ids de las entregas cuyo cliente ya recibió el aviso de «Llegué».
  final List<String> avisos = [];

  int _siguienteId = _primerId;

  /// La entrega [id] ya se confirmó por fuera de esta pantalla (desde la
  /// web del repartidor o en un envío cuya respuesta no llegó): el backend
  /// ya la tiene como entregada.
  void confirmadaPorFuera(String id, {required String recibio}) {
    _entrega(id)!.addAll({
      'estado': 'entregada',
      'recibio_nombre': recibio,
      'finalizado_at': horaDeCierre,
    });
  }

  /// GET consulta la disponibilidad; PUT la cambia.
  Map<String, dynamic> _disponibilidad(LlamadaApi llamada) {
    if (llamada.metodo == 'PUT-Auth') {
      disponible = llamada.body!['disponible'] as bool;
      return {
        'success': true,
        'disponible': disponible,
        'message': disponible
            ? 'Ahora estás disponible'
            : 'Marcado como no disponible',
      };
    }
    return {'success': true, 'disponible': disponible};
  }

  Map<String, dynamic> _listarPool(LlamadaApi _) => {
    'success': true,
    'pedidos': [for (final p in pool) {...p}],
  };

  Map<String, dynamic> _listarEntregas(LlamadaApi _) => {
    'success': true,
    'entregas': [for (final e in entregas) {...e}],
  };

  /// POST /entregas/aceptar: el primero que lo acepta se lo lleva, siempre
  /// que esté disponible.
  Map<String, dynamic> _aceptar(LlamadaApi llamada) {
    if (!disponible) {
      return _rechazo(
        'Activa tu disponibilidad en Perfil para aceptar entregas',
      );
    }
    final pedidoId = '${llamada.body!['pedido_id']}';
    final pedido = pool
        .where((p) => '${p['pedido_id']}' == pedidoId)
        .firstOrNull;
    if (pedido == null) return _rechazo('Este pedido ya no está disponible');
    pool.remove(pedido);
    entregas.add({
      'id': _siguienteId++,
      'pedido_id': pedido['pedido_id'],
      'estado': 'asignada',
      'numero': pedido['numero'],
      'total': pedido['total'],
      'metodo_pago': 'tarjeta',
      'cliente_nombre': pedido['cliente_nombre'],
      'cliente_apellido': pedido['cliente_apellido'],
      'horario_entrega': pedido['horario_entrega'],
      'direccion_entrega': pedido['direccion_entrega'],
    });
    return {
      'success': true,
      'message': 'Tomaste el pedido #${pedido['numero']}',
    };
  }

  /// PUT /entregas/:id/estado, con las transiciones y los datos que exige
  /// el backend.
  Map<String, dynamic> _cambiarEstado(LlamadaApi llamada) {
    final body = llamada.body!;
    final nuevo = body['estado'] as String?;
    final desde = _desde[nuevo];
    if (desde == null) {
      return _rechazo('Estado inválido. Valores: en_camino, entregada, fallida');
    }
    if (nuevo == 'entregada' && body['recibio_nombre'] == null) {
      return _rechazo('Indica quién recibió el pedido');
    }
    if (nuevo == 'fallida' && body['motivo_fallo'] == null) {
      return _rechazo('Indica el motivo del fallo');
    }
    final entrega = _entregaDe(llamada);
    if (entrega == null) return _rechazo('Entrega no encontrada');
    final actual = entrega['estado'] as String;
    if (!desde.contains(actual)) {
      return _rechazo('No se puede pasar de "$actual" a "$nuevo"');
    }
    entrega.addAll({
      'estado': nuevo,
      'recibio_nombre': ?body['recibio_nombre'],
      'evidencia_url': ?body['evidencia_url'],
      'motivo_fallo': ?body['motivo_fallo'],
      if (nuevo != 'en_camino') 'finalizado_at': horaDeCierre,
    });
    return {'success': true, 'message': 'Entrega actualizada'};
  }

  /// POST /entregas/:id/llegue: avisa al cliente sin cambiar el estado.
  Map<String, dynamic> _avisarLlegada(LlamadaApi llamada) {
    final entrega = _entregaDe(llamada);
    if (entrega == null) return _rechazo('Entrega no encontrada');
    if (entrega['estado'] != 'en_camino') {
      return _rechazo('Solo puedes avisar llegada cuando vas en camino');
    }
    avisos.add('${entrega['id']}');
    return {'success': true, 'message': 'Cliente avisado de tu llegada'};
  }

  /// POST /upload/imagen: la foto queda en Cloudinary y regresa su URL.
  Map<String, dynamic> _subirFoto(LlamadaApi llamada) {
    final campos = llamada.body!;
    final archivo = '${campos['filePath']}'.split('/').last;
    return {
      'success': true,
      'imagen': {
        'url': 'https://res.cloudinary.com/pier/${campos['tipo']}/$archivo',
      },
    };
  }

  /// La entrega de la ruta /entregas/:id/... que se llamó.
  Map<String, dynamic>? _entregaDe(LlamadaApi llamada) =>
      _entrega(llamada.endpoint.split('/')[2]);

  Map<String, dynamic>? _entrega(String id) =>
      entregas.where((e) => '${e['id']}' == id).firstOrNull;

  static Map<String, dynamic> _rechazo(String mensaje) => {
    'success': false,
    'message': mensaje,
  };
}
