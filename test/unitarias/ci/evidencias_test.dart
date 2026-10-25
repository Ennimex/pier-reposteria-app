// test/unitarias/ci/evidencias_test.dart — la tabla final del pipeline
// (job «Evidencias y decisión» de pipeline.yml): una fila por etapa con su
// resultado y sus métricas clave, y la decisión.
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
      expect(
        texto,
        contains('**Decisión:** ✅ pasaron las 2 etapas; el Pull Request '
            'puede unirse a main.'),
      );
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
            'Esfuerzo. El pipeline falla y main no recibe el cambio.'),
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
}
