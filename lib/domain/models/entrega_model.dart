// lib/domain/models/entrega_model.dart
//
// Modelo de una entrega a domicilio desde la óptica del REPARTIDOR.
// Fuente: GET /api/entregas/mis-entregas (routes/entregasRoutes.js). Ese
// endpoint devuelve datos de la entrega + un snapshot del pedido y del cliente.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Estados que maneja el backend para una entrega.
enum EstadoEntrega { asignada, enCamino, entregada, fallida, desconocido }

extension EstadoEntregaX on EstadoEntrega {
  String get label {
    switch (this) {
      case EstadoEntrega.asignada:  return 'Asignada';
      case EstadoEntrega.enCamino:  return 'En camino';
      case EstadoEntrega.entregada: return 'Entregada';
      case EstadoEntrega.fallida:   return 'Fallida';
      case EstadoEntrega.desconocido: return 'Sin estado';
    }
  }

  Color get color {
    switch (this) {
      case EstadoEntrega.asignada:  return AppColors.estadoAsignada;
      case EstadoEntrega.enCamino:  return AppColors.estadoEnCamino;
      case EstadoEntrega.entregada: return AppColors.estadoEntregada;
      case EstadoEntrega.fallida:   return AppColors.estadoFallida;
      case EstadoEntrega.desconocido: return AppColors.textSecondary;
    }
  }

  /// Valor que espera el backend en PUT /entregas/:id/estado.
  String get apiValue {
    switch (this) {
      case EstadoEntrega.enCamino:  return 'en_camino';
      case EstadoEntrega.entregada: return 'entregada';
      case EstadoEntrega.fallida:   return 'fallida';
      case EstadoEntrega.asignada:
      case EstadoEntrega.desconocido:
        return '';
    }
  }
}

/// Iniciales en mayúsculas de un nombre y apellido («AL»); «?» si no hay.
String inicialesDe(String nombre, String apellido) {
  final n = nombre.trim();
  final a = apellido.trim();
  final ini = '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'
      .toUpperCase();
  return ini.isEmpty ? '?' : ini;
}

/// Snapshot de la dirección de entrega guardado en el pedido.
/// El backend la guarda como JSON (JSON.stringify) del row de tbldirecciones.
class DireccionEntrega {
  const DireccionEntrega({
    this.alias,
    this.calleNumero,
    this.colonia,
    this.referencias,
    this.telefonoContacto,
    this.lat,
    this.lng,
  });

  /// Acepta un Map, un String JSON (posiblemente doble-serializado) o null.
  factory DireccionEntrega.parse(dynamic raw) {
    var value = raw;
    // Puede venir como texto JSON (una o dos veces serializado; la segunda
    // vez llega entre comillas).
    for (var i = 0; i < 2 && value is String; i++) {
      final t = value.trim();
      if (t.isEmpty) return const DireccionEntrega();
      if (!(t.startsWith('{') || t.startsWith('[') || t.startsWith('"'))) {
        break;
      }
      try {
        value = jsonDecode(t);
      } on FormatException {
        break;
      }
    }
    if (value is! Map) return const DireccionEntrega();
    final mapa = value;

    String? s(String k) {
      final str = mapa[k]?.toString().trim();
      return (str == null || str.isEmpty) ? null : str;
    }

    double? numOrNull(String k) => double.tryParse(mapa[k]?.toString() ?? '');

    return DireccionEntrega(
      alias: s('alias'),
      calleNumero: s('calle_numero') ?? s('calleNumero'),
      colonia: s('colonia'),
      referencias: s('referencias'),
      telefonoContacto: s('telefono_contacto') ?? s('telefonoContacto'),
      lat: numOrNull('lat'),
      lng: numOrNull('lng'),
    );
  }

  final String? alias;
  final String? calleNumero;
  final String? colonia;
  final String? referencias;
  final String? telefonoContacto;
  // Coordenadas GPS (migración 004; null si la dirección no las tiene)
  final double? lat;
  final double? lng;

  bool get isEmpty =>
      (calleNumero == null || calleNumero!.isEmpty) &&
      (colonia == null || colonia!.isEmpty);

  bool get tieneCoordenadas => lat != null && lng != null;

  /// Destino para Google Maps: coordenadas exactas si existen; si no, la
  /// dirección en texto como búsqueda.
  String get destinoMaps => tieneCoordenadas
      ? '$lat,$lng'
      : [calleNumero, colonia, 'Huejutla de Reyes']
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
}

double _numero(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

String? _texto(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Pedido a domicilio listo y sin repartidor, del pool que el repartidor puede
/// tomar. Fuente: GET /api/entregas/disponibles (routes/entregasRoutes.js).
class PedidoDisponible {
  const PedidoDisponible({
    required this.pedidoId,
    required this.numero,
    required this.total,
    required this.costoEnvio,
    required this.direccion,
    required this.clienteNombre,
    required this.clienteApellido,
    this.notas,
    this.horarioEntrega,
  });

  factory PedidoDisponible.fromJson(Map<String, dynamic> json) {
    return PedidoDisponible(
      pedidoId: json['pedido_id']?.toString() ?? '',
      numero: json['numero']?.toString() ?? '',
      total: _numero(json['total']),
      costoEnvio: _numero(json['costo_envio']),
      notas: _texto(json['notas']),
      horarioEntrega: _texto(json['horario_entrega']),
      direccion: DireccionEntrega.parse(json['direccion_entrega']),
      clienteNombre: json['cliente_nombre']?.toString() ?? '',
      clienteApellido: json['cliente_apellido']?.toString() ?? '',
    );
  }

  final String pedidoId;
  final String numero;
  final double total;
  final double costoEnvio;
  final String? notas;
  final String? horarioEntrega;
  final DireccionEntrega direccion;
  final String clienteNombre;
  final String clienteApellido;

  String get clienteNombreCompleto =>
      '$clienteNombre $clienteApellido'.trim();
}

class EntregaRepartidor {
  const EntregaRepartidor({
    required this.id,
    required this.pedidoId,
    required this.estado,
    required this.numero,
    required this.total,
    required this.costoEnvio,
    required this.direccion,
    required this.clienteNombre,
    required this.clienteApellido,
    this.metodoPago,
    this.notas,
    this.horarioEntrega,
    this.clienteTelefono,
    this.recibioNombre,
    this.motivoFallo,
    this.evidenciaUrl,
    this.asignadoAt,
    this.salioAt,
    this.finalizadoAt,
  });

  factory EntregaRepartidor.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    return EntregaRepartidor(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedido_id']?.toString() ?? '',
      estado: parseEstado(json['estado']),
      numero: json['numero']?.toString() ?? '',
      total: _numero(json['total']),
      costoEnvio: _numero(json['costo_envio']),
      metodoPago: _texto(json['metodo_pago']),
      notas: _texto(json['notas']),
      horarioEntrega: _texto(json['horario_entrega']),
      direccion: DireccionEntrega.parse(json['direccion_entrega']),
      clienteNombre: json['cliente_nombre']?.toString() ?? '',
      clienteApellido: json['cliente_apellido']?.toString() ?? '',
      clienteTelefono: _texto(json['cliente_telefono']),
      recibioNombre: _texto(json['recibio_nombre']),
      motivoFallo: _texto(json['motivo_fallo']),
      evidenciaUrl: _texto(json['evidencia_url']),
      asignadoAt: dt(json['asignado_at']),
      salioAt: dt(json['salio_at']),
      finalizadoAt: dt(json['finalizado_at']),
    );
  }

  final String id;
  final String pedidoId;
  final EstadoEntrega estado;

  // Snapshot del pedido
  final String numero;
  final double total;
  final double costoEnvio;
  final String? metodoPago;
  final String? notas;
  final String? horarioEntrega;
  final DireccionEntrega direccion;

  // Cliente
  final String clienteNombre;
  final String clienteApellido;
  final String? clienteTelefono;

  // Estado de la entrega
  final String? recibioNombre;
  final String? motivoFallo;
  final String? evidenciaUrl;
  final DateTime? asignadoAt;
  final DateTime? salioAt;
  final DateTime? finalizadoAt;

  static EstadoEntrega parseEstado(dynamic raw) {
    switch (raw?.toString().toLowerCase()) {
      case 'asignada':  return EstadoEntrega.asignada;
      case 'en_camino': return EstadoEntrega.enCamino;
      case 'entregada': return EstadoEntrega.entregada;
      case 'fallida':   return EstadoEntrega.fallida;
      default:          return EstadoEntrega.desconocido;
    }
  }

  String get clienteNombreCompleto =>
      '$clienteNombre $clienteApellido'.trim();

  String get iniciales => inicialesDe(clienteNombre, clienteApellido);

  bool get esEfectivo => (metodoPago ?? '').toLowerCase() == 'efectivo';

  bool get isActiva =>
      estado == EstadoEntrega.asignada || estado == EstadoEntrega.enCamino;
}
