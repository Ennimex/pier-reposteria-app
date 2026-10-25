// test/unitarias/ci/flujo_test.dart — resumen del flujo principal en el
// emulador: el reporte que deja test_driver/aceptacion_driver.dart.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/flujo.dart';

Map<String, dynamic> _reporte({
  bool aprobado = true,
  List<Map<String, dynamic>> fallas = const [],
}) =>
    {
      'escenario': 'Flujo principal #34 → #35 → #36',
      'aprobado': aprobado,
      'pasos': [
        {'paso': '01_inicio_de_sesion', 'segundos': 2.5},
        {'paso': '02_inicio', 'segundos': 6.2},
      ],
      'capturas': [
        'build/resultados/capturas/01_inicio_de_sesion.png',
        'build/resultados/capturas/02_inicio.png',
      ],
      'fallas': fallas,
    };

void main() {
  group('leerReporteDelFlujo', () {
    test('lee el resultado, los pasos con sus segundos y las capturas', () {
      final reporte = leerReporteDelFlujo(_reporte());

      expect(reporte.escenario, 'Flujo principal #34 → #35 → #36');
      expect(reporte.aprobado, isTrue);
      expect(reporte.pasos.map((paso) => paso.nombre),
          ['01_inicio_de_sesion', '02_inicio']);
      expect(reporte.segundos, 6.2);
      expect(reporte.capturas, 2);
      expect(reporte.fallas, isEmpty);
    });

    test('un reporte incompleto no rompe el resumen', () {
      final reporte = leerReporteDelFlujo({'pasos': 'basura'});

      expect(reporte.aprobado, isFalse);
      expect(reporte.pasos, isEmpty);
      expect(reporte.capturas, 0);
      expect(reporte.segundos, 0);
    });
  });

  group('resumenFlujo', () {
    test('pone el resultado y una fila por paso', () {
      final texto = resumenFlujo(leerReporteDelFlujo(_reporte()));

      expect(texto, startsWith('### 📱 Flujo principal en el emulador\n'));
      expect(texto, contains('| ✅ Aprobado | 2 | 2 | 6.2 s |'));
      expect(
        texto,
        contains(
          '| Paso | Segundos desde el inicio |\n'
          '|---|--:|\n'
          '| 01_inicio_de_sesion | 2.5 s |\n'
          '| 02_inicio | 6.2 s |\n',
        ),
      );
      expect(texto, contains('Las capturas de cada paso están en Artifacts.'));
      expect(texto, isNot(contains('Lo que falló')));
    });

    test('si falló muestra el detalle de la prueba', () {
      final texto = resumenFlujo(
        leerReporteDelFlujo(
          _reporte(
            aprobado: false,
            fallas: [
              {
                'prueba': 'Escenario: del inicio de sesión al checkout',
                'detalle': 'no apareció «Finalizar Pedido»',
              },
            ],
          ),
        ),
      );

      expect(texto, contains('| ❌ Falló |'));
      expect(texto, contains('#### ❌ Lo que falló'));
      expect(texto, contains('no apareció «Finalizar Pedido»'));
    });
  });

  group('lineaFlujo', () {
    test('aprobado: pasos, capturas y tiempo', () {
      expect(
        lineaFlujo(leerReporteDelFlujo(_reporte())),
        '✅ 2 pasos · 2 capturas en 6.2 s',
      );
    });

    test('fallido: hasta dónde llegó', () {
      expect(
        lineaFlujo(leerReporteDelFlujo(_reporte(aprobado: false))),
        '❌ Falló después de 2 pasos',
      );
    });
  });
}
