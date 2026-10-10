// lib/domain/models/pago.dart
//
// Piezas del pago del checkout: el intent que crea el backend (con el total
// autoritativo) y el pedido que confirma después del cobro.

/// Respuesta de POST /pagos/crear-intent.
class IntentDePago {
  const IntentDePago({
    required this.clientSecret,
    required this.publishableKey,
    this.total,
    this.porConfirmar = false,
    this.productosPorConfirmar = const [],
  });

  factory IntentDePago.fromJson(Map<String, dynamic> json) => IntentDePago(
        clientSecret: json['clientSecret']?.toString() ?? '',
        publishableKey: json['publishableKey']?.toString() ?? '',
        total: double.tryParse(json['total']?.toString() ?? ''),
        porConfirmar: json['por_confirmar'] == true,
        productosPorConfirmar: json['productos_por_confirmar'] is List
            ? (json['productos_por_confirmar'] as List)
                .map((e) => e.toString())
                .toList()
            : const [],
      );

  final String clientSecret;
  final String publishableKey;

  /// Total con envío calculado por el backend (null si no lo mandó).
  final double? total;

  /// Pedido programado con productos sin existencias hoy: el personal debe
  /// aprobar la fecha.
  final bool porConfirmar;
  final List<String> productosPorConfirmar;

  /// Id del PaymentIntent de Stripe (lo que va antes de `_secret_`).
  String get paymentIntentId => clientSecret.split('_secret_').first;
}

/// Pedido creado por POST /pagos/confirmar.
class PedidoConfirmado {
  const PedidoConfirmado({required this.numero, this.porConfirmar = false});

  factory PedidoConfirmado.fromJson(Map<String, dynamic> pedido) =>
      PedidoConfirmado(
        numero: pedido['numero']?.toString() ?? pedido['id']?.toString() ?? '',
        porConfirmar: pedido['por_confirmar'] == true,
      );

  final String numero;
  final bool porConfirmar;
}

/// La confirmación del pedido falló. [statusPago] es el estado del cobro que
/// reporta el backend: si no es `succeeded`, el cobro NO ocurrió.
class ConfirmacionFallidaException implements Exception {
  const ConfirmacionFallidaException(this.message, {this.statusPago});

  final String? message;
  final String? statusPago;

  /// El backend confirma que el cobro no se completó.
  bool get cobroNoOcurrio => statusPago != null && statusPago != 'succeeded';

  @override
  String toString() => 'ConfirmacionFallidaException: $message';
}
