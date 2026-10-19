// lib/config/monitoreo.dart
//
// Errores no controlados y trazas de rendimiento en Sentry (#23). El DSN
// llega al compilar, nunca en el código:
//   flutter build apk --release --flavor prod --dart-define=SENTRY_DSN=https://...
// Sin SENTRY_DSN (builds locales, pruebas y CI) Sentry no se inicia y la app
// arranca igual, sin tráfico hacia sentry.io.
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/app_version.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Firma de SentryFlutter.init; las pruebas pasan una falsa.
typedef IniciarSentry = Future<void> Function(
  FlutterOptionsConfiguration configurar, {
  AppRunner? appRunner,
});

class Monitoreo {
  Monitoreo._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Corre [app] dentro de Sentry si hay DSN, para capturar los errores
  /// desde el primer cuadro; si no, la corre directo.
  static Future<void> arrancar(
    AppRunner app, {
    String dsn = _dsn,
    Ambiente? ambiente,
    IniciarSentry iniciarSentry = SentryFlutter.init,
  }) async {
    if (dsn.isEmpty) {
      await app();
      return;
    }
    final elegido = ambiente ?? ApiConstants.ambiente;
    await iniciarSentry(
      (opciones) => configurar(opciones, dsn: dsn, ambiente: elegido),
      appRunner: app,
    );
  }

  /// environment = ambiente del build (flavor o AMBIENTE); en prod solo se
  /// muestrea el 20 % de las trazas para no agotar la cuota.
  static void configurar(
    SentryFlutterOptions opciones, {
    required String dsn,
    required Ambiente ambiente,
  }) {
    opciones
      ..dsn = dsn
      ..environment = ambiente.name
      ..release = 'mx.com.pierreposteria@${AppVersion.full}'
      ..tracesSampleRate = ambiente == Ambiente.prod ? 0.2 : 1.0;
  }
}
