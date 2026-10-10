// lib/data/services/pasarela_stripe.dart
//
// Implementación de PasarelaPago con la Payment Sheet de Stripe.
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

/// Cobra con la Payment Sheet de Stripe.
class PasarelaStripe implements PasarelaPago {
  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {
    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Pier Repostería',
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.pierVerde,
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw const PagoCanceladoException();
      }
      throw PagoRechazadoException(
          e.error.localizedMessage ?? 'Pago cancelado');
    }
  }
}
