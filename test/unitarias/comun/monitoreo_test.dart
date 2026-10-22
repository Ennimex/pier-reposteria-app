// test/unitarias/comun/monitoreo_test.dart — errores y rendimiento en Sentry (#23).
// Sentry solo se inicia si el build trae --dart-define=SENTRY_DSN=...; sin DSN
// (builds locales y pruebas) la app arranca igual y no se envía nada.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/app_version.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _dsn = 'https://clave@o1.ingest.sentry.io/2';

/// Toma el lugar de SentryFlutter.init: guarda lo que recibió y no toca la
/// red ni el SDK nativo.
class _SentryFalso {
  int llamadas = 0;
  final opciones = SentryFlutterOptions();
  AppRunner? appRunner;

  Future<void> init(
    FlutterOptionsConfiguration configurar, {
    AppRunner? appRunner,
  }) async {
    llamadas++;
    await configurar(opciones);
    this.appRunner = appRunner;
  }
}

void main() {
  group('Monitoreo.arrancar', () {
    test('sin DSN arranca la app y no inicia Sentry', () async {
      final sentry = _SentryFalso();
      var arranques = 0;

      await Monitoreo.arrancar(
        () => arranques++,
        // Explícito: la prueba no debe depender de que el build no traiga
        // --dart-define=SENTRY_DSN.
        // ignore: avoid_redundant_argument_values
        dsn: '',
        iniciarSentry: sentry.init,
      );

      expect(arranques, 1);
      expect(sentry.llamadas, 0);
    });

    test('con DSN la app arranca dentro de Sentry', () async {
      final sentry = _SentryFalso();
      var arranques = 0;

      await Monitoreo.arrancar(
        () => arranques++,
        dsn: _dsn,
        iniciarSentry: sentry.init,
      );

      // La app no arranca por fuera: Sentry la corre con su appRunner para
      // capturar los errores desde el primer cuadro.
      expect(sentry.llamadas, 1);
      expect(arranques, 0);
      await sentry.appRunner!();
      expect(arranques, 1);
      expect(sentry.opciones.dsn, _dsn);
    });

    test('sin ambiente explícito usa el del build (prod por omisión)', () async {
      final sentry = _SentryFalso();

      await Monitoreo.arrancar(() {}, dsn: _dsn, iniciarSentry: sentry.init);

      expect(sentry.opciones.environment, 'prod');
    });
  });

  group('Monitoreo.configurar', () {
    SentryFlutterOptions configurada(Ambiente ambiente) {
      final opciones = SentryFlutterOptions();
      Monitoreo.configurar(opciones, dsn: _dsn, ambiente: ambiente);
      return opciones;
    }

    test('prod muestrea el 20 % de las trazas', () {
      final opciones = configurada(Ambiente.prod);

      expect(opciones.environment, 'prod');
      expect(opciones.tracesSampleRate, 0.2);
    });

    test('dev y staging muestrean todas las trazas', () {
      expect(configurada(Ambiente.dev).environment, 'dev');
      expect(configurada(Ambiente.dev).tracesSampleRate, 1.0);
      expect(configurada(Ambiente.staging).environment, 'staging');
      expect(configurada(Ambiente.staging).tracesSampleRate, 1.0);
    });

    test('la versión es la del applicationId y el pubspec', () {
      expect(
        configurada(Ambiente.prod).release,
        'mx.com.pierreposteria@${AppVersion.full}',
      );
    });

    test('decide el muestreo de cada traza con tasaDeMuestreo (#24)', () {
      expect(configurada(Ambiente.prod).tracesSampler, isNotNull);
    });
  });

  // #24: el objetivo de errores del pago (docs/SLO.md) necesita todos los
  // intentos; con el 20 % casi no habría datos.
  group('Monitoreo.tasaDeMuestreo', () {
    test('cada intento de pago se mide siempre, también en prod', () {
      expect(
        Monitoreo.tasaDeMuestreo(MonitorDePagosSentry.operacion, Ambiente.prod),
        1.0,
      );
    });

    test('las demás trazas se muestrean según el ambiente', () {
      expect(Monitoreo.tasaDeMuestreo('ui.load', Ambiente.prod), 0.2);
      expect(Monitoreo.tasaDeMuestreo('ui.load', Ambiente.staging), 1.0);
      expect(Monitoreo.tasaDeMuestreo('ui.load', Ambiente.dev), 1.0);
    });
  });

  // Sin Sentry iniciado (como en las pruebas) la transacción no manda nada:
  // el intento corre igual y su resultado o su error pasan tal cual.
  group('MonitorDePagosSentry', () {
    test(
      'devuelve lo que devolvió el intento y lo clasifica una vez',
      () async {
        final clasificados = <int>[];

        final resultado = await const MonitorDePagosSentry().medir(
          () async => 7,
          (valor) {
            clasificados.add(valor);
            return (resultado: 'pagado', fallo: false);
          },
        );

        expect(resultado, 7);
        expect(clasificados, [7]);
      },
    );

    test('si el intento lanza, el error sigue su camino', () {
      expect(
        const MonitorDePagosSentry().medir<int>(
          () async => throw StateError('sin red'),
          (_) => (resultado: 'pagado', fallo: false),
        ),
        throwsStateError,
      );
    });
  });
}
