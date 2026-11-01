// lib/domain/models/atencion_clientes.dart
//
// Quejas, solicitudes de reembolso y reseñas como las atiende el personal en
// «Atención a clientes» (#138), con el contrato de la web
// (src/Empleado/paginas/GestionQuejas.tsx, GestionReembolsos.tsx y
// GestionResenas.tsx):
//   GET /quejas -> quejas[{id, ticket, tipo, categoria, asunto, descripcion,
//     prioridad, estado, respuesta, created_at, cliente_nombre,
//     cliente_apellido, cliente_email, cliente_telefono, pedido_numero}]
//   GET /reembolsos -> reembolsos[{id, pedido_id, pedido_numero, monto,
//     motivo, descripcion, estado, fotos_evidencia, respuesta_admin,
//     justificacion_rechazo, created_at, cliente_nombre, cliente_apellido,
//     cliente_telefono, automatico}]
//   GET /resenas -> resenas[{id, producto_id, producto_nombre, rating,
//     titulo, comentario, respuesta_negocio, motivo_rechazo, auto_aprobada,
//     verificada, estado, created_at, autor_nombre, autor_apellido}]
// El backend guarda escapados los textos (validator.escape): aquí quedan
// como se escribieron. Los estados son los mismos enums del cliente.
import 'package:pier_reposteria/domain/models/mi_resena.dart';
import 'package:pier_reposteria/domain/models/queja.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/utils/texto_sanitizado.dart';

/// Texto sin espacios en las orillas; null si viene vacío.
String? _texto(Object? valor) {
  final t = valor?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

/// Como [_texto], pero como lo escribió la persona (sin el escapado).
String? _legible(Object? valor) {
  final t = _texto(valor);
  return t == null ? null : decodificarSanitizado(t);
}

/// «Ana Ruiz»; 'Cliente' si no trae nombre (como la web).
String _nombre(Object? nombre, Object? apellido) {
  final completo =
      [_legible(nombre), _legible(apellido)].whereType<String>().join(' ');
  return completo.isEmpty ? 'Cliente' : completo;
}

/// Prioridad de una queja (backend: alta, media o baja).
enum PrioridadQueja {
  alta('Prioridad alta'),
  media('Prioridad media'),
  baja('Prioridad baja');

  const PrioridadQueja(this.etiqueta);

  final String etiqueta;
}

/// Una queja, sugerencia o comentario de un cliente.
class QuejaPersonal {
  const QuejaPersonal({
    required this.id,
    required this.ticket,
    required this.tipo,
    required this.categoria,
    required this.asunto,
    required this.descripcion,
    required this.prioridad,
    required this.estado,
    required this.cliente,
    this.respuesta,
    this.email,
    this.telefono,
    this.pedidoNumero,
  });

  /// null si no es un objeto o le falta el id. Un estado o una prioridad
  /// desconocidos se toman como pendiente y media.
  static QuejaPersonal? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _texto(json['id']);
    if (id == null) return null;
    return QuejaPersonal(
      id: id,
      ticket: _texto(json['ticket']) ?? '#$id',
      tipo: _texto(json['tipo']) ?? '',
      categoria: _texto(json['categoria']) ?? '',
      asunto: _legible(json['asunto']) ?? '',
      descripcion: _legible(json['descripcion']) ?? '',
      prioridad: switch (json['prioridad']?.toString()) {
        'alta' => PrioridadQueja.alta,
        'baja' => PrioridadQueja.baja,
        _ => PrioridadQueja.media,
      },
      estado: switch (json['estado']?.toString()) {
        'en_proceso' => EstadoQueja.enProceso,
        'resuelto' => EstadoQueja.resuelto,
        _ => EstadoQueja.pendiente,
      },
      cliente: _nombre(json['cliente_nombre'], json['cliente_apellido']),
      respuesta: _legible(json['respuesta']),
      email: _texto(json['cliente_email']),
      telefono: _texto(json['cliente_telefono']),
      pedidoNumero: _texto(json['pedido_numero']),
    );
  }

  final String id;

  /// Con él lo identifica el cliente («TKT-001»).
  final String ticket;

  /// queja, sugerencia o comentario, como lo guarda el backend.
  final String tipo;
  final String categoria;
  final String asunto;
  final String descripcion;
  final PrioridadQueja prioridad;
  final EstadoQueja estado;
  final String cliente;

  /// null si nadie ha respondido.
  final String? respuesta;
  final String? email;
  final String? telefono;

  /// null si no es de un pedido.
  final String? pedidoNumero;

  /// Etiqueta del tipo («Sugerencia») o el valor crudo si no se conoce.
  String get tipoTexto =>
      TipoQueja.values.asNameMap()[tipo]?.etiqueta ?? tipo;

  /// Etiqueta de la categoría («Producto») o el valor crudo si no se conoce.
  String get categoriaTexto =>
      CategoriaQueja.values.asNameMap()[categoria]?.etiqueta ?? categoria;

  bool get resuelta => estado == EstadoQueja.resuelto;
}

/// Una solicitud de reembolso de un cliente.
class ReembolsoPersonal {
  const ReembolsoPersonal({
    required this.id,
    required this.pedidoNumero,
    required this.monto,
    required this.estado,
    required this.cliente,
    this.motivo,
    this.descripcion,
    this.fotos = const [],
    this.respuestaAdmin,
    this.justificacionRechazo,
    this.telefono,
    this.automatico = false,
  });

  /// null si no es un objeto o le falta el id. El monto llega como texto
  /// («150.00»); un estado desconocido se toma como pendiente.
  static ReembolsoPersonal? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _texto(json['id']);
    if (id == null) return null;
    final fotos = json['fotos_evidencia'];
    return ReembolsoPersonal(
      id: id,
      pedidoNumero:
          _texto(json['pedido_numero']) ?? _texto(json['pedido_id']) ?? id,
      monto: double.tryParse(json['monto']?.toString() ?? '') ?? 0,
      estado: switch (json['estado']?.toString()) {
        'en_revision' => EstadoReembolso.enRevision,
        'aprobado' => EstadoReembolso.aprobado,
        'rechazado' => EstadoReembolso.rechazado,
        'procesado' => EstadoReembolso.procesado,
        _ => EstadoReembolso.pendiente,
      },
      cliente: _nombre(json['cliente_nombre'], json['cliente_apellido']),
      motivo: _texto(json['motivo']),
      descripcion: _legible(json['descripcion']),
      fotos: [
        if (fotos is List)
          for (final f in fotos)
            if (f is String && f.trim().isNotEmpty) f.trim(),
      ],
      respuestaAdmin: _legible(json['respuesta_admin']),
      justificacionRechazo: _legible(json['justificacion_rechazo']),
      telefono: _texto(json['cliente_telefono']),
      automatico: json['automatico'] == true,
    );
  }

  final String id;
  final String pedidoNumero;
  final double monto;
  final EstadoReembolso estado;
  final String cliente;

  /// Código del motivo (ver Reembolso.motivos).
  final String? motivo;
  final String? descripcion;

  /// URLs de la evidencia fotográfica; vacía si no adjuntó.
  final List<String> fotos;

  /// Lo que lee el cliente en su solicitud.
  final String? respuestaAdmin;

  /// Por qué se rechazó (solo si está rechazada).
  final String? justificacionRechazo;
  final String? telefono;

  /// La generó el sistema al cancelar o rechazar un pedido pagado.
  final bool automatico;

  /// «Producto dañado»; un código que no está en la lista, legible
  /// («Otra cosa»).
  String get motivoTexto {
    final m = motivo;
    if (m == null) return 'Sin motivo';
    final conocido = Reembolso.motivos[m];
    if (conocido != null) return conocido;
    final t = m.replaceAll('_', ' ');
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }

  /// Como la web: «procesado» es «Devuelto».
  String get estadoTexto => switch (estado) {
        EstadoReembolso.pendiente => 'Pendiente',
        EstadoReembolso.enRevision => 'En revisión',
        EstadoReembolso.aprobado => 'Aprobado',
        EstadoReembolso.rechazado => 'Rechazado',
        EstadoReembolso.procesado => 'Devuelto',
      };
}

/// Una reseña de un producto.
class ResenaPersonal {
  const ResenaPersonal({
    required this.id,
    required this.productoNombre,
    required this.autor,
    required this.estrellas,
    required this.comentario,
    required this.estado,
    this.titulo,
    this.respuestaNegocio,
    this.motivoRechazo,
    this.autoAprobada = false,
    this.verificada = false,
  });

  /// null si no es un objeto o le falta el id. Un estado desconocido se toma
  /// como en revisión (pendiente en el backend).
  static ResenaPersonal? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _texto(json['id']);
    if (id == null) return null;
    final rating = double.tryParse(json['rating']?.toString() ?? '') ?? 0;
    return ResenaPersonal(
      id: id,
      productoNombre: _legible(json['producto_nombre']) ?? 'Producto',
      autor: _nombre(json['autor_nombre'], json['autor_apellido']),
      estrellas: rating.round().clamp(0, 5),
      comentario: _legible(json['comentario']) ?? '',
      estado: switch (json['estado']?.toString()) {
        'aprobada' => EstadoResena.aprobada,
        'rechazada' => EstadoResena.rechazada,
        _ => EstadoResena.enRevision,
      },
      titulo: _legible(json['titulo']),
      respuestaNegocio: _legible(json['respuesta_negocio']),
      motivoRechazo: _legible(json['motivo_rechazo']),
      autoAprobada: json['auto_aprobada'] == true,
      verificada: json['verificada'] == true,
    );
  }

  final String id;
  final String productoNombre;
  final String autor;

  /// De 0 a 5.
  final int estrellas;
  final String comentario;
  final EstadoResena estado;
  final String? titulo;

  /// La respuesta pública de Pier Repostería; null si no hay.
  final String? respuestaNegocio;
  final String? motivoRechazo;

  /// Se publicó sola (4 o 5 estrellas sin groserías).
  final bool autoAprobada;

  /// Quien la escribió compró el producto.
  final bool verificada;

  /// Como la web: «pendiente» es «En revisión».
  String get estadoTexto => switch (estado) {
        EstadoResena.enRevision => 'En revisión',
        EstadoResena.aprobada => 'Aprobada',
        EstadoResena.rechazada => 'Rechazada',
      };

  /// Por qué no se publicó sola: la misma regla del backend.
  String get motivoRetencion => estrellas < 4
      ? 'Calificación baja (menos de 4 estrellas)'
      : 'Posible lenguaje inapropiado';
}
