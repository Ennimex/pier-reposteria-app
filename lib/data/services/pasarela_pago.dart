// lib/data/services/pasarela_pago.dart
//
// Cobro con tarjeta (MVVM, Fase 4). El ViewModel del checkout depende de este
// contrato; la app usa PasarelaStripe y las pruebas un doble sin Stripe.

/// El cliente cerró la hoja de pago sin pagar.
class PagoCanceladoException implements Exception {
  const PagoCanceladoException();
}

/// La pasarela rechazó o no pudo completar el cobro.
class PagoRechazadoException implements Exception {
  const PagoRechazadoException(this.message);

  final String message;

  @override
  String toString() => 'PagoRechazadoException: $message';
}

// Clase (no función) para poder inyectarla y sustituirla en pruebas.
// ignore: one_member_abstracts
abstract class PasarelaPago {
  /// Muestra la hoja de pago del intent y espera a que el cliente pague.
  /// Lanza [PagoCanceladoException] si la cierra y [PagoRechazadoException]
  /// si el cobro falla.
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  });
}
