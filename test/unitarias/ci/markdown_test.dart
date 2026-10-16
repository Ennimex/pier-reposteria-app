// test/unitarias/ci/markdown_test.dart — formatos que comparten los resúmenes
// de los pipelines (#157): números, tiempos, tamaños, tablas y secciones.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/markdown.dart';

void main() {
  group('miles', () {
    test('separa los miles con coma', () {
      expect(miles(7), '7');
      expect(miles(1171), '1,171');
      expect(miles(1234567), '1,234,567');
    });
  });

  group('porcentaje', () {
    test('redondea a un decimal y deja el espacio antes del signo', () {
      expect(porcentaje(84.26), '84.3 %');
      expect(porcentaje(100), '100.0 %');
    });
  });

  group('duracion', () {
    test('usa segundos debajo del minuto y minutos con segundos arriba', () {
      expect(duracion(const Duration(milliseconds: 400)), 'menos de 1 s');
      expect(duracion(const Duration(seconds: 13)), '13 s');
      expect(duracion(const Duration(seconds: 112)), '1 min 52 s');
      expect(duracion(const Duration(minutes: 3)), '3 min');
    });
  });

  group('tamano', () {
    test('muestra bytes, KB o MB según el tamaño', () {
      expect(tamano(900), '900 B');
      expect(tamano(2048), '2.0 KB');
      expect(tamano(19293798), '18.4 MB');
    });
  });

  group('celda', () {
    test('escapa las barras y junta los renglones para no romper la tabla',
        () {
      expect(celda('a | b\nc'), r'a \| b c');
    });
  });

  group('bloque', () {
    test('encierra el texto en un bloque de código', () {
      expect(bloque('Expected: 0'), '```text\nExpected: 0\n```\n');
    });

    test('alarga la cerca si el texto ya trae una', () {
      expect(bloque('```dart\nx\n```'), '````text\n```dart\nx\n```\n````\n');
    });
  });

  group('plegable', () {
    test('arma una sección que se despliega con su título', () {
      expect(
        plegable('Avisos (2)', '- uno\n- dos\n'),
        '<details><summary>Avisos (2)</summary>\n\n- uno\n- dos\n\n'
        '</details>\n',
      );
    });
  });
}
