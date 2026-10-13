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

  factory ResumenComanda.fromJson(Map<String, dynamic> json) {
    final firmas = json['firmas'] is Map ? json['firmas'] as Map : const {};
    final tomadoPor = json['tomado_por'];
    return ResumenComanda(
      id: (json['id'] as num).toInt(),
      folio: (json['folio'] as num).toInt(),
      estado: EstadoComanda.values
              .where((e) => e.name == json['estado'])
              .firstOrNull ??
          EstadoComanda.activa,
      clienteNombre: json['cliente_nombre']?.toString() ?? '',
      clienteTelefono: json['cliente_telefono']?.toString() ?? '',
      fechaEntrega: json['fecha_entrega']?.toString() ?? '',
      horaEntrega: json['hora_entrega']?.toString() ?? '',
      diasRestantes: (json['dias_restantes'] as num?)?.toInt() ?? 0,
      semaforo:
          Semaforo.values.where((s) => s.name == json['semaforo']).firstOrNull,
      version: (json['version'] as num?)?.toInt() ?? 1,
      resumen: json['resumen']?.toString() ?? '',
      numImagenes: (json['num_imagenes'] as num?)?.toInt() ?? 0,
      total: _monto(json['total']),
      anticipo: _monto(json['anticipo']),
      saldo: _monto(json['saldo']),
      tomadoPorNombre:
          tomadoPor is Map ? tomadoPor['nombre']?.toString() ?? '' : '',
      firmas: {
        for (final area in AreaProduccion.values)
          area: FirmaArea.fromJson(firmas[area.name]),
      },
      entregadaAt: json['entregada_at']?.toString(),
      canceladaAt: json['cancelada_at']?.toString(),
    );
  }

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

  static double? _monto(Object? valor) =>
      valor == null ? null : double.tryParse(valor.toString());
}

/// Respuesta de la agenda: el día de hoy en Huejutla y las comandas.
class AgendaComandas {
  const AgendaComandas({required this.hoy, required this.comandas});

  factory AgendaComandas.fromJson(Map<String, dynamic> json) {
    final lista = json['comandas'];
    return AgendaComandas(
      hoy: json['hoy']?.toString() ?? '',
      comandas: lista is List
          ? lista
              .whereType<Map<dynamic, dynamic>>()
              .map((j) => ResumenComanda.fromJson(Map<String, dynamic>.from(j)))
              .toList()
          : const [],
    );
  }

  /// 'YYYY-MM-DD' en hora de Huejutla.
  final String hoy;
  final List<ResumenComanda> comandas;
}
