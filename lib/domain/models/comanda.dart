// lib/domain/models/comanda.dart
//
// Comandas de pedidos personalizados (módulo del backend del 11-oct,
// migración 010). Fuente: GET /api/comandas (routes/comandasRoutes.js,
// resumenDeFila). Hornos y decoración reciben los montos en null: aquí se
// quedan en null, nunca se convierten en cero.
import 'package:flutter/material.dart';

/// Vistas de la agenda; [name] es el valor de `?vista=` del backend.
enum VistaAgenda {
  proximas('Próximos 15 días'),
  activas('Todas las activas'),
  entregadas('Entregadas'),
  canceladas('Canceladas');

  const VistaAgenda(this.etiqueta);

  final String etiqueta;

  /// Entregadas y canceladas se agrupan por el día en que se cerraron.
  bool get esHistorica => this == entregadas || this == canceladas;
}

enum EstadoComanda {
  activa('Activa'),
  entregada('Entregada'),
  cancelada('Cancelada');

  const EstadoComanda(this.etiqueta);

  final String etiqueta;
}

/// Urgencia de una comanda activa según los días que faltan para entregarla.
/// Colores fijos, como en la web: no cambian con el tema de temporada.
enum Semaforo {
  vencida('Vencida', Color(0xFF111827)),
  rojo('Urgente', Color(0xFFEF4444)),
  naranja('Muy pronto', Color(0xFFF97316)),
  amarillo('Esta semana', Color(0xFFF59E0B)),
  verde('Con tiempo', Color(0xFF22C55E));

  const Semaforo(this.etiqueta, this.color);

  final String etiqueta;
  final Color color;
}

/// Áreas de producción que confirman «Enterado»; [name] es el rol del
/// backend y la clave de `firmas`.
enum AreaProduccion {
  hornos('Hornos', Color(0xFFEA580C)),
  decoracion('Decoración', Color(0xFFDB2777));

  const AreaProduccion(this.etiqueta, this.color);

  final String etiqueta;
  final Color color;

  /// El área de un rol, o null si el rol no es de producción.
  static AreaProduccion? deRol(String? rol) =>
      values.where((a) => a.name == rol).firstOrNull;
}

/// vigente: confirmó la versión actual · refirmar: confirmó una anterior ·
/// pendiente: nunca ha confirmado.
enum EstadoFirma { vigente, refirmar, pendiente }

/// Última confirmación de un área respecto a la versión vigente.
class FirmaArea {
  const FirmaArea({
    required this.vigente,
    this.version,
    this.usuarioNombre,
    this.fecha,
  });

  factory FirmaArea.fromJson(Object? json) {
    if (json is! Map) return const FirmaArea(vigente: false);
    return FirmaArea(
      vigente: json['vigente'] == true,
      version: (json['version'] as num?)?.toInt(),
      usuarioNombre: json['usuario_nombre']?.toString(),
      fecha: json['fecha']?.toString(),
    );
  }

  final bool vigente;
  final int? version;
  final String? usuarioNombre;
  final String? fecha;

  EstadoFirma get estado => vigente
      ? EstadoFirma.vigente
      : version != null
      ? EstadoFirma.refirmar
      : EstadoFirma.pendiente;
}

/// Una comanda en la agenda (resumen, sin renglones completos).
class ResumenComanda {
  const ResumenComanda({
    required this.id,
    required this.folio,
    required this.estado,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.fechaEntrega,
    required this.horaEntrega,
    required this.diasRestantes,
    required this.semaforo,
    required this.version,
    required this.resumen,
    required this.numImagenes,
    required this.total,
    required this.anticipo,
    required this.saldo,
    required this.tomadoPorNombre,
    required this.firmas,
    required this.entregadaAt,
    required this.canceladaAt,
  });

  factory ResumenComanda.fromJson(Map<String, dynamic> json) => ResumenComanda(
    id: (json['id'] as num).toInt(),
    folio: (json['folio'] as num).toInt(),
    estado: _estadoDe(json),
    clienteNombre: _texto(json['cliente_nombre']),
    clienteTelefono: _texto(json['cliente_telefono']),
    fechaEntrega: _texto(json['fecha_entrega']),
    horaEntrega: _texto(json['hora_entrega']),
    diasRestantes: _entero(json['dias_restantes'], 0),
    semaforo: _semaforoDe(json),
    version: _entero(json['version'], 1),
    resumen: _texto(json['resumen']),
    numImagenes: _entero(json['num_imagenes'], 0),
    total: _monto(json['total']),
    anticipo: _monto(json['anticipo']),
    saldo: _monto(json['saldo']),
    tomadoPorNombre: _tomadoPor(json),
    firmas: _firmasDe(json),
    entregadaAt: json['entregada_at']?.toString(),
    canceladaAt: json['cancelada_at']?.toString(),
  );

  final int id;
  final int folio;
  final EstadoComanda estado;
  final String clienteNombre;
  final String clienteTelefono;

  /// 'YYYY-MM-DD'
  final String fechaEntrega;

  /// 'HH:MM'
  final String horaEntrega;

  /// Días que faltan para la entrega (negativo: ya pasó).
  final int diasRestantes;

  /// null si la comanda ya no está activa.
  final Semaforo? semaforo;
  final int version;

  /// 'Pastel Chocolate · 20 personas + 2 × Tart Bites'
  final String resumen;
  final int numImagenes;

  /// null para hornos y decoración (el backend no les manda montos).
  final double? total;
  final double? anticipo;
  final double? saldo;
  final String tomadoPorNombre;
  final Map<AreaProduccion, FirmaArea> firmas;
  final String? entregadaAt;
  final String? canceladaAt;

  FirmaArea firma(AreaProduccion area) =>
      firmas[area] ?? const FirmaArea(vigente: false);

  /// Activa y sin la confirmación vigente de [area].
  bool pendientePara(AreaProduccion area) =>
      estado == EstadoComanda.activa && !firma(area).vigente;
}

// ── Lectura común del resumen y del detalle ──

String _texto(Object? valor) => valor?.toString() ?? '';

/// Texto con contenido, o null (vacío cuenta como «sin especificar»).
String? _opcional(Object? valor) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

int _entero(Object? valor, int porDefecto) =>
    (valor as num?)?.toInt() ?? porDefecto;

double? _monto(Object? valor) =>
    valor == null ? null : double.tryParse(valor.toString());

EstadoComanda _estadoDe(Map<String, dynamic> json) =>
    EstadoComanda.values.where((e) => e.name == json['estado']).firstOrNull ??
    EstadoComanda.activa;

Semaforo? _semaforoDe(Map<String, dynamic> json) =>
    Semaforo.values.where((s) => s.name == json['semaforo']).firstOrNull;

String _tomadoPor(Map<String, dynamic> json) {
  final t = json['tomado_por'];
  return t is Map ? _texto(t['nombre']) : '';
}

Map<AreaProduccion, FirmaArea> _firmasDe(Map<String, dynamic> json) {
  final firmas = json['firmas'] is Map ? json['firmas'] as Map : const {};
  return {
    for (final area in AreaProduccion.values)
      area: FirmaArea.fromJson(firmas[area.name]),
  };
}

List<Map<String, dynamic>> _mapas(Object? lista) => lista is List
    ? lista
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList()
    : const [];

/// Respuesta de la agenda: el día de hoy en Huejutla y las comandas.
class AgendaComandas {
  const AgendaComandas({required this.hoy, required this.comandas});

  factory AgendaComandas.fromJson(Map<String, dynamic> json) {
    final lista = json['comandas'];
    return AgendaComandas(
      hoy: json['hoy']?.toString() ?? '',
      comandas: _mapas(lista).map(ResumenComanda.fromJson).toList(),
    );
  }

  /// 'YYYY-MM-DD' en hora de Huejutla.
  final String hoy;
  final List<ResumenComanda> comandas;
}

/// Un campo que cambió para producción: «Pastel 1 · Sabor: Vainilla →
/// Chocolate». [campo] ya llega legible del backend.
class CambioCampo {
  const CambioCampo(this.campo, this.antes, this.despues);

  factory CambioCampo.fromJson(Map<String, dynamic> json) => CambioCampo(
    _texto(json['campo']),
    json['antes']?.toString(),
    json['despues']?.toString(),
  );

  final String campo;
  final String? antes;
  final String? despues;

  /// Mismo texto que textoCambio del backend.
  String get texto {
    if (campo == 'Se agregó' && antes == null) return 'Se agregó: $despues';
    if (campo == 'Se quitó' && despues == null) return 'Se quitó: $antes';
    return '$campo: ${antes ?? '—'} → ${despues ?? '—'}';
  }
}

/// Un renglón de la comanda: pastel (sabor, tamaño, forma…) o producto del
/// catálogo (tamaño chico o grande e indicaciones). Sin precios.
class RenglonComanda {
  const RenglonComanda({
    required this.esPastel,
    required this.nombre,
    required this.cantidad,
    this.sabor,
    this.tamano,
    this.forma,
    this.numPisos,
    this.decoracion,
    this.colorFondo,
    this.leyenda,
    this.descripcion,
    this.insumos,
    this.tamanoCatalogo,
    this.indicaciones,
  });

  factory RenglonComanda.fromJson(Map<String, dynamic> json) => RenglonComanda(
    esPastel: json['tipo'] == 'pastel',
    nombre: _texto(json['nombre']),
    cantidad: _entero(json['cantidad'], 1),
    sabor: _opcional(json['sabor']),
    tamano: _opcional(json['tamano']),
    forma: _opcional(json['forma']),
    numPisos: (json['num_pisos'] as num?)?.toInt(),
    decoracion: _opcional(json['decoracion']),
    colorFondo: _opcional(json['color_fondo']),
    leyenda: _opcional(json['leyenda']),
    descripcion: _opcional(json['descripcion']),
    insumos: _opcional(json['insumos']),
    tamanoCatalogo: _opcional(json['tamano_catalogo']),
    indicaciones: _opcional(json['indicaciones']),
  );

  final bool esPastel;
  final String nombre;
  final int cantidad;
  final String? sabor;
  final String? tamano;
  final String? forma;
  final int? numPisos;
  final String? decoracion;
  final String? colorFondo;

  /// Texto que va escrito en el pastel, tal cual.
  final String? leyenda;
  final String? descripcion;
  final String? insumos;

  /// 'chico' o 'grande' (productos del catálogo).
  final String? tamanoCatalogo;
  final String? indicaciones;
}

/// Un evento del historial (creada, modificada, cancelada, entregada).
class EventoHistorial {
  EventoHistorial.fromJson(Map<String, dynamic> json)
    : modificada = json['evento'] == 'modificada',
      version = _entero(json['version'], 1),
      cambios = _mapas(json['cambios']).map(CambioCampo.fromJson).toList();

  final bool modificada;
  final int version;
  final List<CambioCampo> cambios;
}

/// La comanda completa (GET /comandas/:id) como la ve producción: lo que
/// necesita para trabajar, sin montos.
class DetalleComanda {
  factory DetalleComanda.fromJson(Map<String, dynamic> respuesta) {
    final c = respuesta['comanda'] is Map
        ? Map<String, dynamic>.from(respuesta['comanda'] as Map)
        : <String, dynamic>{};
    final permisos = respuesta['permisos'] is Map
        ? respuesta['permisos'] as Map
        : const {};
    return DetalleComanda._(
      id: _entero(c['id'], 0),
      folio: _entero(c['folio'], 0),
      estado: _estadoDe(c),
      semaforo: _semaforoDe(c),
      version: _entero(c['version'], 1),
      clienteNombre: _texto(c['cliente_nombre']),
      clienteTelefono: _texto(c['cliente_telefono']),
      fechaEntrega: _texto(c['fecha_entrega']),
      horaEntrega: _texto(c['hora_entrega']),
      diasRestantes: _entero(c['dias_restantes'], 0),
      notas: _opcional(c['notas']),
      coloresMesa: {
        for (final (etiqueta, clave) in const [
          ('Capacillos', 'mesa_color_capacillos'),
          ('Betún', 'mesa_color_betun'),
          ('Grageas', 'mesa_color_grageas'),
        ])
          etiqueta: ?_opcional(c[clave]),
      },
      tomadoPorNombre: _tomadoPor(c),
      motivoCancelacion: _opcional(c['motivo_cancelacion']),
      renglones: _mapas(c['items']).map(RenglonComanda.fromJson).toList(),
      imagenes: [
        for (final im in _mapas(c['imagenes'])) ?_opcional(im['url']),
      ],
      firmas: _firmasDe(c),
      cambiosPendientes: c['cambios_pendientes'] is List
          ? _mapas(c['cambios_pendientes']).map(CambioCampo.fromJson).toList()
          : null,
      historial: _mapas(c['historial']).map(EventoHistorial.fromJson).toList(),
      confirmar: AreaProduccion.deRol(permisos['confirmar']?.toString()),
      subtotal: _monto(c['subtotal']),
      descuento: _monto(c['descuento']),
      total: _monto(c['total']),
      anticipo: _monto(c['anticipo']),
      saldo: _monto(c['saldo']),
      saldoCobrado: _monto(c['saldo_cobrado']),
      entregadaPorNombre: _opcional(c['entregada_por_nombre']),
      puedeEntregar: permisos['entregar'] == true,
      puedeCancelar: permisos['cancelar'] == true,
      puedeImprimir: permisos['imprimir'] == true,
    );
  }

  const DetalleComanda._({
    required this.id,
    required this.folio,
    required this.estado,
    required this.semaforo,
    required this.version,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.fechaEntrega,
    required this.horaEntrega,
    required this.diasRestantes,
    required this.notas,
    required this.coloresMesa,
    required this.tomadoPorNombre,
    required this.motivoCancelacion,
    required this.renglones,
    required this.imagenes,
    required this.firmas,
    required this.cambiosPendientes,
    required this.historial,
    required this.confirmar,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.anticipo,
    required this.saldo,
    required this.saldoCobrado,
    required this.entregadaPorNombre,
    required this.puedeEntregar,
    required this.puedeCancelar,
    required this.puedeImprimir,
  });

  final int id;
  final int folio;
  final EstadoComanda estado;
  final Semaforo? semaforo;
  final int version;
  final String clienteNombre;
  final String clienteTelefono;
  final String fechaEntrega;
  final String horaEntrega;
  final int diasRestantes;
  final String? notas;

  /// Colores de la mesa de postres que sí se indicaron ('Capacillos' → …).
  final Map<String, String> coloresMesa;
  final String tomadoPorNombre;
  final String? motivoCancelacion;
  final List<RenglonComanda> renglones;

  /// URLs de las imágenes de referencia, en orden.
  final List<String> imagenes;
  final Map<AreaProduccion, FirmaArea> firmas;

  /// Qué cambió desde la versión que confirmó mi área (null si no aplica).
  final List<CambioCampo>? cambiosPendientes;

  /// Del evento más reciente al más viejo.
  final List<EventoHistorial> historial;

  /// Mi área, si me toca confirmar «Enterado» (activa y sin mi firma
  /// vigente); null si no.
  final AreaProduccion? confirmar;

  /// Montos: null para hornos y decoración (el backend no se los manda).
  final double? subtotal;
  final double? descuento;
  final double? total;
  final double? anticipo;
  final double? saldo;

  /// Lo que se cobró al entregarla.
  final double? saldoCobrado;
  final String? entregadaPorNombre;

  /// Permisos de quien cobra (empleado, gerencia y dirección): entregar
  /// cualquier activa; cancelar solo quien la tomó, gerencia o dirección.
  final bool puedeEntregar;
  final bool puedeCancelar;
  final bool puedeImprimir;

  /// Áreas que no han confirmado la versión actual.
  List<AreaProduccion> get areasSinConfirmar =>
      AreaProduccion.values.where((a) => !firma(a).vigente).toList();

  List<RenglonComanda> get pasteles =>
      renglones.where((r) => r.esPastel).toList();
  List<RenglonComanda> get productos =>
      renglones.where((r) => !r.esPastel).toList();

  FirmaArea firma(AreaProduccion area) =>
      firmas[area] ?? const FirmaArea(vigente: false);

  /// Cambios de las ediciones posteriores a [version], del más viejo al más
  /// nuevo (lo que cambió mientras se leía la comanda).
  List<CambioCampo> cambiosDesde(int version) => historial.reversed
      .where((e) => e.modificada && e.version > version)
      .expand((e) => e.cambios)
      .toList();
}
