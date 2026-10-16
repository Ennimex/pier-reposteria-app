// test/unitarias/ci/cobertura_test.dart — lectura de coverage/lcov.info y su
// tabla de cobertura por carpeta en el resumen de la corrida (#157).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/cobertura.dart';

String _registro(String ruta, int lineas, int cubiertas) =>
    'SF:$ruta\nDA:1,1\nLF:$lineas\nLH:$cubiertas\nend_of_record\n';

void main() {
  group('leerLcov', () {
    test('lee líneas y cubiertas de cada archivo con su ruta desde lib/', () {
      final archivos = leerLcov(
        _registro('/home/runner/work/app/app/lib/ui/cart/cart_screen.dart', 40, 30) +
            _registro(r'lib\utils\command.dart', 10, 10),
      );

      expect(archivos, hasLength(2));
      expect(archivos.first.archivo, 'lib/ui/cart/cart_screen.dart');
      expect(archivos.first.lineas, 40);
      expect(archivos.first.cubiertas, 30);
      expect(archivos.first.porcentaje, 75);
      expect(archivos.last.archivo, 'lib/utils/command.dart');
    });

    test('sin LF ni LH cuenta las líneas DA', () {
      final archivo = leerLcov(
        'SF:lib/main.dart\nDA:1,3\nDA:2,0\nDA:5,1\nend_of_record\n',
      ).single;

      expect(archivo.lineas, 3);
      expect(archivo.cubiertas, 2);
    });
  });

  group('resumenCobertura', () {
    final archivos = leerLcov(
      _registro('lib/ui/cart/cart_screen.dart', 40, 30) +
          _registro('lib/ui/home/home_screen.dart', 60, 30) +
          _registro('lib/utils/command.dart', 10, 10) +
          _registro('lib/main.dart', 10, 0),
    );

    test('muestra el total en negritas', () {
      expect(
        resumenCobertura(archivos),
        startsWith('**Cobertura de líneas: 58.3 %** (70 de 120 líneas)\n'),
      );
    });

    test('agrupa por carpeta de primer nivel dentro de lib/', () {
      expect(
        resumenCobertura(archivos),
        contains(
          '| Carpeta | Líneas | Cubiertas | Cobertura |\n'
          '|---|--:|--:|--:|\n'
          '| `lib` | 10 | 0 | 0.0 % |\n'
          '| `lib/ui` | 100 | 60 | 60.0 % |\n'
          '| `lib/utils` | 10 | 10 | 100.0 % |\n',
        ),
      );
    });

    test('lista en una sección plegable los archivos con menos cobertura', () {
      final texto = resumenCobertura(archivos);

      expect(
        texto,
        contains('<summary>Los 4 archivos con menos cobertura</summary>'),
      );
      expect(
        texto.indexOf('| `lib/main.dart` | 10 | 0 | 0.0 % |'),
        lessThan(texto.indexOf('| `lib/ui/home/home_screen.dart` |')),
      );
    });

    test('avisa si no hay reporte', () {
      expect(resumenCobertura([]), contains('No se generó el reporte'));
    });
  });

  group('lineaCobertura', () {
    test('da el total en una línea', () {
      expect(
        lineaCobertura(leerLcov(_registro('lib/main.dart', 8, 6))),
        'cobertura 75.0 %',
      );
    });
  });
}
