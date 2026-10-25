// lib/config/monitoreo.dart
//
// Errores no controlados y trazas de rendimiento en Sentry (#23). El DSN
// llega al compilar, nunca en el código:
//   flutter build apk --release --flavor prod --dart-define=SENTRY_DSN=https://...
// Sin SENTRY_DSN (builds locales, pruebas y CI) Sentry no se inicia y la app
// arranca igual, sin tráfico hacia sentry.io.
import 'package:flutter/widgets.dart';
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

  /// environment = ambiente del build (flavor o AMBIENTE); las trazas se
  /// muestrean con [tasaDeMuestreo].
  static void configurar(
    SentryFlutterOptions opciones, {
    required String dsn,
    required Ambiente ambiente,
  }) {
    opciones
      ..dsn = dsn
      ..environment = ambiente.name
      ..release = 'mx.com.pierreposteria@${AppVersion.full}'
      ..tracesSampleRate = tasaDeMuestreo('', ambiente)
      ..tracesSampler = (contexto) =>
          tasaDeMuestreo(contexto.transactionContext.operation, ambiente);
  }

  /// Le dice a Sentry en qué pantalla está el usuario (#60): cada error lleva
  /// el nombre de la ruta de go_router (contexto App → View Names) y el rastro
  /// de pantallas previas. Sin transacciones por pantalla: gastarían cuota y
  /// docs/SLO.md no las usa.
  static NavigatorObserver observadorDeNavegacion({Hub? hub}) =>
      SentryNavigatorObserver(hub: hub, enableAutoTransactions: false);

  /// Cada intento de pago se mide siempre: el objetivo de errores del pago
  /// (docs/SLO.md, #24) necesita todos. Lo demás, en prod solo el 20 % para
  /// no agotar la cuota.
  static double tasaDeMuestreo(String operacion, Ambiente ambiente) {
    if (operacion == MonitorDePagosSentry.operacion) return 1;
    return ambiente == Ambiente.prod ? 0.2 : 1.0;
  }
}

/// Cómo terminó un intento de pago para Sentry: `resultado` va en la
/// etiqueta del mismo nombre y `fallo` lo cuenta contra el objetivo de
/// errores.
typedef DesenlacePago = ({String resultado, bool fallo});

/// Mide cada intento de pago (#24). El ViewModel del checkout decide el
/// desenlace; las pruebas usan uno falso.
// Clase (no función) para poder inyectarla y sustituirla en pruebas.
// ignore: one_member_abstracts
abstract interface class MonitorDePagos {
  /// Corre [intento] y devuelve lo mismo que él, midiéndolo con [desenlace].
  Future<T> medir<T>(
    Future<T> Function() intento,
    DesenlacePago Function(T) desenlace,
  );
}

/// Cada intento es una transacción «pago» (op checkout.pagar) con las
/// etiquetas flow=checkout y resultado; si el desenlace es un fallo, su
/// estado es internal_error. Sin SENTRY_DSN Sentry no está iniciado y no se
/// manda nada.
class MonitorDePagosSentry implements MonitorDePagos {
  const MonitorDePagosSentry();

  static const String operacion = 'checkout.pagar';

  @override
  Future<T> medir<T>(
    Future<T> Function() intento,
    DesenlacePago Function(T) desenlace,
  ) async {
    final transaccion = Sentry.startTransaction(
      'pago',
      operacion,
      bindToScope: true,
    )..setTag('flow', 'checkout');
    try {
      final valor = await intento();
      final (:resultado, :fallo) = desenlace(valor);
      transaccion
        ..setTag('resultado', resultado)
        ..status = fallo
            ? const SpanStatus.internalError()
            : const SpanStatus.ok();
      return valor;
    } catch (error) {
      transaccion
        ..setTag('resultado', 'error')
        ..throwable = error
        ..status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await transaccion.finish();
    }
  }
}
