// test/fakes/actividad_json.dart — respuestas del backend para «Actividad
// del equipo» (#139): la actividad vista a las 12:00 del 31-oct-2026 en
// México (el reloj fijo de las pruebas) y dos páginas de la bitácora, con
// los textos escapados como los guarda el sanitizador del backend.
import 'package:pier_reposteria/config/api_constants.dart';

import 'fake_api_client.dart';

/// 31-oct-2026, 12:00 en México: el «ahora» de las pruebas.
DateTime ahoraActividad() => DateTime.utc(2026, 10, 31, 18);

/// La consulta de la bitácora (páginas de 50) con [filtros], p. ej.
/// '&entidad=pedido'.
String consultaBitacora([String filtros = '']) =>
    '${ApiConstants.auditoria}?limite=50$filtros';

/// Cuántas veces se pidió exactamente [endpoint] con la sesión.
int consultasDe(FakeApiClient api, String endpoint) => api.llamadas
    .where((l) => l.endpoint == endpoint && l.metodo == 'GET-Auth')
    .length;

// ── Actividad del equipo ───────────────────────────────────────────────

Map<String, dynamic> miembroJson({
  required int id,
  required String nombre,
  String apellido = 'Ruiz',
  String rol = 'empleado',
  bool activo = true,
  String? ultimoAcceso,
  int acciones = 0,
  int entregadas = 0,
  int enCurso = 0,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'rol': rol,
      'activo': activo,
      'ultimo_acceso': ultimoAcceso,
      'acciones': acciones,
      'ultima_accion': null,
      'entregadas': entregadas,
      'entregas_activas': enCurso,
    };

/// Un movimiento reciente: por defecto, Ana (gerencia) aprobó un reembolso
/// hace 30 minutos.
Map<String, dynamic> movimientoJson({
  String accion = 'Aprobó reembolso',
  String? entidad = 'reembolso',
  int? entidadId = 7,
  Object? detalles = 'Pedido PIER-41 &amp; cliente avisado',
  String creado = '2026-10-31T17:30:00.000Z',
  String? nombre = 'Ana',
  String? apellido = 'Ruiz',
  String? rol = 'gerencia',
}) =>
    {
      'accion': accion,
      'entidad': entidad,
      'entidad_id': entidadId,
      'detalles': detalles,
      'created_at': creado,
      'nombre': nombre,
      'apellido': apellido,
      'rol': rol,
    };

/// Ana (gerencia) entró hace 5 min y registró 12 movimientos; Luis
/// (repartidor), hace 3 h, con 8 entregas y 2 en curso; Rosa (decoración),
/// hace 2 días, con 1; Pedro (mostrador) nunca ha entrado y su cuenta está
/// inactiva. Más un renglón inválido en cada lista.
Map<String, dynamic> get actividadJson => {
      'success': true,
      'equipo': [
        miembroJson(
          id: 2,
          nombre: 'Ana',
          rol: 'gerencia',
          ultimoAcceso: '2026-10-31T17:55:00.000Z',
          acciones: 12,
        ),
        miembroJson(
          id: 3,
          nombre: 'Luis',
          apellido: 'Pérez',
          rol: 'repartidor',
          ultimoAcceso: '2026-10-31T15:00:00.000Z',
          entregadas: 8,
          enCurso: 2,
        ),
        miembroJson(
          id: 4,
          nombre: 'Rosa',
          apellido: 'Díaz',
          rol: 'decoracion',
          ultimoAcceso: '2026-10-29T18:00:00.000Z',
          acciones: 1,
        ),
        miembroJson(id: 5, nombre: 'Pedro', apellido: 'Sol', activo: false),
        'basura',
      ],
      'movimientos': [
        movimientoJson(),
        movimientoJson(
          accion: 'Canceló pedido sin pago',
          entidad: 'pedido',
          entidadId: 88,
          detalles: null,
          creado: '2026-10-30T17:00:00.000Z',
          nombre: null,
          apellido: null,
          rol: null,
        ),
        7,
      ],
      'zonas': [
        {'zona': 'Centro', 'colonia': 'Centro', 'pedidos': 12},
        {'zona': 'Norte', 'colonia': 'San Juan &amp; Anexas', 'pedidos': 6},
        {'zona': null, 'colonia': null, 'pedidos': 3},
        null,
      ],
      'kpis': {
        'avisos_demora': 4,
        'clientes_atendidos_30d': 1234,
        'pedidos_cerrados_30d': 56,
        'productos_movidos_30d': 9,
        'promos_creadas_30d': 2,
      },
    };

// ── Bitácora ───────────────────────────────────────────────────────────

/// Un renglón de la bitácora: por defecto, Ana (gerencia) cambió el estado
/// del pedido 42 hoy a las 11:05 de México.
Map<String, dynamic> registroJson({
  required int id,
  String accion = 'Cambió el estado del pedido',
  String? entidad = 'pedido',
  int? entidadId = 42,
  Object? detalles = 'De &quot;listo&quot; a &quot;entregado&quot;',
  String? ip = '10.0.0.7',
  String creado = '2026-10-31T17:05:00.000Z',
  int? usuarioId = 2,
  String? nombre = 'Ana',
  String? apellido = 'Ruiz',
  String? rol = 'gerencia',
}) =>
    {
      'id': id,
      'usuario_id': usuarioId,
      'accion': accion,
      'entidad': entidad,
      'entidad_id': entidadId,
      'detalles': detalles,
      'ip': ip,
      'created_at': creado,
      'usuario_nombre': nombre,
      'usuario_apellido': apellido,
      'usuario_rol': rol,
    };

/// Detalles de más de 160 caracteres: se recortan hasta «Ver completo».
final String detallesLargos =
    'Colonias con envío: ${List.filled(20, 'San Juan').join(', ')}';

/// El sistema (sin persona) desactivó el producto 5 ayer a las 17:40.
Map<String, dynamic> get productoDelSistemaJson => registroJson(
      id: 31,
      accion: 'Desactivó producto',
      entidad: 'producto',
      entidadId: 5,
      detalles: null,
      ip: null,
      creado: '2026-10-30T23:40:00.000Z',
      usuarioId: null,
      nombre: null,
      apellido: null,
      rol: null,
    );

/// Luis (repartidor) actualizó una zona de envío, con detalles largos.
Map<String, dynamic> get zonaDeLuisJson => registroJson(
      id: 30,
      accion: 'Actualizó zona de envío',
      entidad: 'zona_envio',
      entidadId: null,
      detalles: detallesLargos,
      ip: '10.0.0.9',
      creado: '2026-10-29T15:00:00.000Z',
      usuarioId: 3,
      nombre: 'Luis',
      apellido: 'Pérez',
      rol: 'repartidor',
    );

/// Una página de la bitácora; con [siguiente] hay más antiguos.
Map<String, dynamic> paginaJson(
  List<Map<String, dynamic>> registros, {
  int? siguiente,
}) =>
    {
      'success': true,
      'auditoria': registros,
      'hay_mas': siguiente != null,
      'siguiente_antes_de_id': siguiente,
      'entidades': ['comanda', 'pedido', 'producto', 'zona_envio', 'otra_cosa'],
      'personas': [
        {'id': 2, 'nombre': 'Ana', 'apellido': 'Ruiz', 'rol': 'gerencia'},
        {'id': 3, 'nombre': 'Luis', 'apellido': 'Pérez', 'rol': 'repartidor'},
      ],
    };

/// La primera página: el pedido de Ana (32), el producto del sistema (31) y
/// la zona de Luis (30); hay más antes del 30.
Map<String, dynamic> get primeraPaginaJson => paginaJson(
      [registroJson(id: 32), productoDelSistemaJson, zonaDeLuisJson],
      siguiente: 30,
    );

/// La segunda y última: Ana creó la promoción 3.
Map<String, dynamic> get segundaPaginaJson => paginaJson(
      [
        registroJson(
          id: 29,
          accion: 'Creó promoción',
          entidad: 'promocion',
          entidadId: 3,
        ),
      ],
    );

/// Backend falso con la actividad del equipo y las dos páginas de la
/// bitácora (la primera responde a cualquier filtro).
FakeApiClient backendActividad() => FakeApiClient()
  ..responder(ApiConstants.actividadEquipo, actividadJson)
  ..responder(ApiConstants.auditoria, primeraPaginaJson)
  ..responder(consultaBitacora('&antes_de_id=30'), segundaPaginaJson);
