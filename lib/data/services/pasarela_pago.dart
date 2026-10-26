// lib/data/services/pasarela_pago.dart
//
// Cobro con tarjeta (MVVM, Fase 4). El ViewModel del checkout depende de este
// contrato; la app usa PasarelaStripe y las pruebas un doble sin Stripe.
import 'package:pier_reposteria/data/services/pasarela_stripe.dart';

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
//
// Patrón Factory: el código que cobra depende solo de este contrato, y la
// fábrica `PasarelaPago()` decide la implementación concreta (hoy
// PasarelaStripe). dependencies.dart registra `PasarelaPago()`, así que
// cambiar de pasarela es cambiar esta línea; los dobles de prueba siguen
// usando `implements PasarelaPago`.
// ignore: one_member_abstracts
abstract class PasarelaPago {
  /// La pasarela que usa la app.
  factory PasarelaPago() => PasarelaStripe();

  /// Muestra la hoja de pago del intent y espera a que el cliente pague.
  /// Lanza [PagoCanceladoException] si la cierra y [PagoRechazadoException]
  /// si el cobro falla.
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  });
}
