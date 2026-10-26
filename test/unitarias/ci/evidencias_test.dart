// test/unitarias/ci/evidencias_test.dart — la tabla final del pipeline
// (job «Evidencias y decisión» de pipeline.yml): una fila por etapa con su
// resultado y sus métricas clave, y la decisión, que nombra la rama real
// (la de destino de un Pull Request o la rama donde corrió).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/evidencias.dart';
import '../../../tool/resumen/pruebas.dart';

void main() {
  group('resumenEvidencias', () {
    test('pone una fila por etapa con su resultado y sus métricas', () {
      final texto = resumenEvidencias(
        const [
          EtapaDelPipeline(
            nombre: 'Unitarias y de widget',
            resultado: 'success',
            metricas: ['✅ 3 pruebas pasaron', 'cobertura 90.0 %'],
          ),
          EtapaDelPipeline(nombre: 'Rendimiento', resultado: 'success'),
        ],
        version: 'Rama `main` · commit `abc1234`',
      );

      expect(texto, startsWith('### 🧾 Evidencias del pipeline\n'));
      expect(texto, contains('Rama `main` · commit `abc1234`'));
      expect(
        texto,
        contains(
          '| Etapa | Resultado | Métricas clave |\n'
          '|---|---|---|\n'
          '| Unitarias y de widget | ✅ Pasó | ✅ 3 pruebas pasaron · '
          'cobertura 90.0 % |\n'
          '| Rendimiento | ✅ Pasó | — |\n',
        ),
      );
      expect(texto, contains('**Decisión:** ✅ pasaron las 2 etapas.\n'));
    });

    test('la decisión nombra las etapas que fallaron o no corrieron', () {
      final texto = resumenEvidencias(const [
        EtapaDelPipeline(nombre: 'Unitarias y de widget', resultado: 'success'),
        EtapaDelPipeline(nombre: 'Aceptación', resultado: 'failure'),
        EtapaDelPipeline(nombre: 'Integración', resultado: 'skipped'),
        EtapaDelPipeline(nombre: 'Esfuerzo', resultado: 'cancelled'),
      ]);

      expect(texto, contains('| Aceptación | ❌ Falló | — |'));
      expect(
        texto,
        contains(
          '| Integración | ⏭️ No corrió: falló una etapa anterior | — |',
        ),
      );
      expect(texto, contains('| Esfuerzo | ⏹️ Se canceló | — |'));
      expect(
        texto,
        contains('**Decisión:** ❌ no pasaron: Aceptación, Integración, '
            'Esfuerzo. El pipeline falla.\n'),
      );
    });

    test('lista debajo las pruebas que fallaron', () {
      final texto = resumenEvidencias(
        const [EtapaDelPipeline(nombre: 'Regresión', resultado: 'failure')],
        corridas: const [
          Corrida(
            pruebas: [
              Prueba(
                nombre: 'confirma «agregado» solo si el backend acepta',
                grupo: 'ProductsScreen',
                archivo: 'test/widget/products/products_screen_test.dart',
                estado: EstadoPrueba.fallo,
                linea: 305,
                detalle: 'Expected: no matching nodes',
              ),
            ],
            termino: true,
            exito: false,
          ),
        ],
      );

      expect(texto, contains('#### ❌ Pruebas que fallaron (1)'));
      expect(
        texto,
        contains('`test/widget/products/products_screen_test.dart:305`'),
      );
      expect(texto, contains('Expected: no matching nodes'));
    });

    test('una métrica con barras no parte la tabla', () {
      final texto = resumenEvidencias(const [
        EtapaDelPipeline(
          nombre: 'Análisis estático',
          resultado: 'success',
          metricas: ['a | b'],
        ),
      ]);

      expect(texto, contains(r'| Análisis estático | ✅ Pasó | a \| b |'));
    });
  });

  group('la decisión nombra la rama', () {
    const pasaron = [
      EtapaDelPipeline(nombre: 'Unitarias', resultado: 'success'),
      EtapaDelPipeline(nombre: 'Regresión', resultado: 'success'),
    ];
    const fallaron = [EtapaDelPipeline(nombre: 'Regresión', resultado: 'failure')];

    test('un Pull Request hacia develop puede unirse a develop', () {
      final texto = resumenEvidencias(
        pasaron,
        destino: const DestinoDelCambio.pullRequest('develop'),
      );

      expect(
        texto,
        contains('**Decisión:** ✅ pasaron las 2 etapas; el Pull Request '
            'puede unirse a develop.'),
      );
    });

    test('un Pull Request hacia main que falla no llega a main', () {
      final texto = resumenEvidencias(
        fallaron,
        destino: const DestinoDelCambio.pullRequest('main'),
      );

      expect(
        texto,
        contains('**Decisión:** ❌ no pasaron: Regresión. El pipeline falla y '
            'main no recibe el cambio.'),
      );
    });

    test('un push o una corrida a mano nombra la rama donde corrió', () {
      expect(
        resumenEvidencias(pasaron, destino: const DestinoDelCambio.rama('develop')),
        contains('**Decisión:** ✅ pasaron las 2 etapas en develop.'),
      );
      expect(
        resumenEvidencias(fallaron, destino: const DestinoDelCambio.rama('main')),
        contains('**Decisión:** ❌ no pasaron: Regresión. El pipeline falla '
            'en main.'),
      );
    });
  });

  group('destinoDelCambio', () {
    test('en un Pull Request es la rama de destino (GITHUB_BASE_REF)', () {
      final destino = destinoDelCambio(const {
        'GITHUB_BASE_REF': 'develop',
        'GITHUB_REF_NAME': '207/merge',
      });

      expect(destino?.rama, 'develop');
      expect(destino?.esPullRequest, isTrue);
    });

    test('en un push o a mano GITHUB_BASE_REF viene vacía: la rama donde '
        'corrió', () {
      final destino = destinoDelCambio(const {
        'GITHUB_BASE_REF': '',
        'GITHUB_REF_NAME': 'main',
      });

      expect(destino?.rama, 'main');
      expect(destino?.esPullRequest, isFalse);
    });

    test('fuera de GitHub Actions no hay destino', () {
      expect(destinoDelCambio(const {}), isNull);
      expect(destinoDelCambio(const {'GITHUB_REF_NAME': ''}), isNull);
    });
  });

  // SonarCloud no da el quality gate de develop: en su push, el análisis se
  // sube sin esperarlo y la tabla dice que se verificó en el Pull Request.
  group('lineaSonarCloud', () {
    test('en un push a develop dice que el quality gate se verificó en el '
        'Pull Request', () {
      expect(
        lineaSonarCloud(const DestinoDelCambio.rama('develop')),
        'SonarCloud: análisis de develop subido; el quality gate se verificó '
        'en el Pull Request',
      );
    });

    test('en los Pull Requests y en el push a main el quality gate es '
        'obligatorio: no agrega nada', () {
      expect(lineaSonarCloud(const DestinoDelCambio.pullRequest('develop')), isNull);
      expect(lineaSonarCloud(const DestinoDelCambio.pullRequest('main')), isNull);
      expect(lineaSonarCloud(const DestinoDelCambio.rama('main')), isNull);
      expect(lineaSonarCloud(null), isNull);
    });
  });
}
