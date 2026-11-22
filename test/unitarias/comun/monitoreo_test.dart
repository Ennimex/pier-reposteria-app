// test/unitarias/comun/monitoreo_test.dart — errores y rendimiento en Sentry (#23).
// Sentry solo se inicia si el build trae --dart-define=SENTRY_DSN=...; sin DSN
// (builds locales y pruebas) la app arranca igual y no se envía nada.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/app_version.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/services/preferencias_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dsn = 'https://clave@o1.ingest.sentry.io/2';

/// Una traza cualquiera: SentryTracer, que la construye, no se exporta.
class _TrazaFalsa extends Fake implements SentryTransaction {}

/// Toma el lugar de la red: guarda lo que Sentry mandaría a sentry.io.
class _TransporteFalso implements Transport {
  final sobres = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    sobres.add(envelope);
    return envelope.header.eventId;
  }
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Monitoreo.diagnosticosPermitidos = true);

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

    test('#223: si el cliente se opuso, la app arranca sin Sentry', () async {
      await PreferenciasService().guardarEnviaDiagnosticos(envia: false);
      final sentry = _SentryFalso();
      var arranques = 0;

      await Monitoreo.arrancar(
        () => arranques++,
        dsn: _dsn,
        iniciarSentry: sentry.init,
      );

      expect(arranques, 1);
      expect(sentry.llamadas, 0);
      expect(Monitoreo.diagnosticosPermitidos, isFalse);
    });

    // #353: la preferencia se lee antes de iniciar Sentry y el SDK de
    // Android manda sesiones y cierres por su cuenta, sin pasar por
    // beforeSend: mientras no se sepa la decisión del cliente, no se inicia.
    test('#353: aunque la preferencia tarde en leerse, con el interruptor '
        'apagado Sentry nunca se inicia', () async {
      final sentry = _SentryFalso();
      final preferencia = Completer<bool>();
      var arranques = 0;

      final arranque = Monitoreo.arrancar(
        () => arranques++,
        dsn: _dsn,
        iniciarSentry: sentry.init,
        permitido: () => preferencia.future,
      );
      await pumpEventQueue();
      expect(sentry.llamadas, 0, reason: 'todavía no se sabe la decisión');

      preferencia.complete(false);
      await arranque;

      expect(sentry.llamadas, 0);
      expect(arranques, 1);
      expect(Monitoreo.diagnosticosPermitidos, isFalse);
    });

    test('#223: la decisión puede venir de fuera', () async {
      final sentry = _SentryFalso();

      await Monitoreo.arrancar(
        () {},
        dsn: _dsn,
        iniciarSentry: sentry.init,
        permitido: () async => true,
      );

      expect(sentry.llamadas, 1);
      expect(Monitoreo.diagnosticosPermitidos, isTrue);
    });
  });

  group('Monitoreo: oposición en caliente (#223)', () {
    SentryFlutterOptions configurada() {
      final opciones = SentryFlutterOptions();
      Monitoreo.configurar(opciones, dsn: _dsn, ambiente: Ambiente.prod);
      return opciones;
    }

    test('con diagnósticos permitidos los eventos y trazas pasan', () async {
      final opciones = configurada();
      final evento = SentryEvent();
      final traza = _TrazaFalsa();

      expect(await opciones.beforeSend!(evento, Hint()), same(evento));
      expect(await opciones.beforeSendTransaction!(traza, Hint()), same(traza));
    });

    test('al oponerse se descartan desde ese momento', () async {
      final opciones = configurada();
      Monitoreo.diagnosticosPermitidos = false;
      final traza = _TrazaFalsa();

      expect(await opciones.beforeSend!(SentryEvent(), Hint()), isNull);
      expect(await opciones.beforeSendTransaction!(traza, Hint()), isNull);
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

    // #353: con el 20 %, la 2.5.0 juntó 3 arranques en un mes y su p90 no
    // decía nada.
    test('cada arranque se mide siempre, también en prod', () {
      expect(Monitoreo.operacionArranque, 'ui.load');
      for (final ambiente in Ambiente.values) {
        expect(
          Monitoreo.tasaDeMuestreo(Monitoreo.operacionArranque, ambiente),
          1.0,
        );
      }
    });

    test('la transacción de arranque que abre Sentry se muestrea al 100 %',
        () {
      final opciones = SentryFlutterOptions();
      Monitoreo.configurar(opciones, dsn: _dsn, ambiente: Ambiente.prod);
      final arranque = SentrySamplingContext.forTransaction(
        SentryTransactionContext('root /', Monitoreo.operacionArranque),
      );

      expect(opciones.tracesSampler!(arranque), 1.0);
    });

    test('las demás trazas se muestrean según el ambiente', () {
      expect(Monitoreo.tasaDeMuestreo('http.client', Ambiente.prod), 0.2);
      expect(Monitoreo.tasaDeMuestreo('http.client', Ambiente.staging), 1.0);
      expect(Monitoreo.tasaDeMuestreo('http.client', Ambiente.dev), 1.0);
    });
  });

  // #353: el arranque no termina en el primer cuadro (el splash); Sentry
  // espera a que el destino del splash avise que ya se pintó.
  group('Monitoreo: arranque hasta el Inicio (#353)', () {
    test('Sentry espera el aviso de que el Inicio ya se ve', () {
      final opciones = SentryFlutterOptions();
      expect(opciones.enableTimeToFullDisplayTracing, isFalse);

      Monitoreo.configurar(opciones, dsn: _dsn, ambiente: Ambiente.prod);

      expect(opciones.enableTimeToFullDisplayTracing, isTrue);
    });

    test('sin Sentry iniciado, avisar no hace nada', () async {
      await expectLater(Monitoreo.inicioVisible(), completes);
    });

    // Con «Enviar diagnósticos» apagado no sale nada, tampoco la transacción
    // de arranque, que ahora se manda siempre.
    Future<List<SentryEnvelope>> loQueSaleAlArrancar({
      required bool diagnosticosPermitidos,
    }) async {
      final transporte = _TransporteFalso();
      final opciones = SentryFlutterOptions()..transport = transporte;
      Monitoreo.configurar(opciones, dsn: _dsn, ambiente: Ambiente.prod);
      Monitoreo.diagnosticosPermitidos = diagnosticosPermitidos;

      final arranque =
          Hub(opciones).startTransaction('root /', Monitoreo.operacionArranque);
      await arranque.finish();
      return transporte.sobres;
    }

    test('la transacción de arranque sale del teléfono en prod', () async {
      final sobres = await loQueSaleAlArrancar(diagnosticosPermitidos: true);

      expect(sobres, hasLength(1));
      expect(
        [for (final parte in sobres.single.items) parte.header.type],
        contains('transaction'),
      );
    });

    test('si el cliente se opuso, la transacción de arranque no sale',
        () async {
      final sobres = await loQueSaleAlArrancar(diagnosticosPermitidos: false);

      expect(sobres, isEmpty);
    });
  });

  // #60: cada error llega a Sentry con la pantalla en la que estaba el
  // usuario (contexto App → View Names) y el rastro de pantallas previas.
  group('Monitoreo.observadorDeNavegacion', () {
    Route<void> ruta(String nombre) => MaterialPageRoute<void>(
          builder: (_) => const SizedBox(),
          settings: RouteSettings(name: nombre),
        );

    // Hub propio con todas las trazas activas: si el observador abriera una
    // transacción por pantalla, quedaría en el scope.
    Hub hubConTrazas() =>
        Hub(SentryFlutterOptions(dsn: _dsn)..tracesSampleRate = 1);

    Future<List<Map<String, dynamic>?>> navegaciones(Hub hub) async {
      await pumpEventQueue();
      var migas = <Breadcrumb>[];
      await hub.configureScope((scope) => migas = scope.breadcrumbs);
      return [
        for (final miga in migas)
          if (miga.category == 'navigation') miga.data,
      ];
    }

    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('deja en el rastro cada pantalla a la que se entra', () async {
      final hub = hubConTrazas();

      Monitoreo.observadorDeNavegacion(hub: hub)
          .didPush(ruta('/producto/:id'), ruta('/main'));

      expect(await navegaciones(hub), [
        {'state': 'didPush', 'from': '/main', 'to': '/producto/:id'},
      ]);
    });

    test('y la pantalla a la que se vuelve', () async {
      final hub = hubConTrazas();

      Monitoreo.observadorDeNavegacion(hub: hub)
          .didPop(ruta('/cliente/checkout'), ruta('/main'));

      expect(await navegaciones(hub), [
        {'state': 'didPop', 'from': '/cliente/checkout', 'to': '/main'},
      ]);
    });

    // Una transacción por pantalla gastaría cuota y no la pide docs/SLO.md;
    // tampoco debe tocar la transacción «pago» que vive en el scope.
    test('navegar no abre transacciones', () {
      final hub = hubConTrazas();

      Monitoreo.observadorDeNavegacion(hub: hub)
          .didPush(ruta('/cliente/checkout'), ruta('/main'));

      expect(hub.getSpan(), isNull);
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
