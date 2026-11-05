// test/unitarias/android/icono_app_test.dart — #327: el ícono de la app en
// Android es el mismo diseño del ícono de la ficha de Play (fondo verde
// olivo y el pastel con «PIER» en dorado).
//   · Android 8+: ícono adaptable con el fondo de color y el logo como primer
//     plano, un PNG transparente de 108 dp por densidad.
//   · Android 7 o anterior: ic_launcher.png, un cuadro opaco de 48 dp por
//     densidad.
// Las imágenes se revisan leyendo el encabezado IHDR del PNG: ancho y alto
// (big-endian) en los bytes 16-23 y el tipo de color en el byte 25
// (2 = RGB, 6 = RGB con alfa).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Pixeles por dp de cada carpeta de densidad.
const _densidades = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

const _tipoRgb = 2;
const _tipoRgbConAlfa = 6;

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Ancho, alto y tipo de color de un PNG según su encabezado IHDR.
({int ancho, int alto, int tipoColor}) _encabezadoPng(String ruta) {
  final archivo = File(ruta);
  expect(archivo.existsSync(), isTrue, reason: 'falta $ruta');
  final bytes = archivo.readAsBytesSync();
  expect(bytes.length, greaterThan(25), reason: '$ruta está incompleto');
  // Firma de todo PNG, seguida del bloque IHDR.
  expect(
    bytes.sublist(0, 8),
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    reason: '$ruta no es un PNG',
  );
  expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR');
  final datos = ByteData.sublistView(bytes);
  return (
    ancho: datos.getUint32(16),
    alto: datos.getUint32(20),
    tipoColor: bytes[25],
  );
}

void main() {
  test('#327: el manifiesto usa el ícono de la app', () {
    expect(
      _leer('android/app/src/main/AndroidManifest.xml'),
      contains('android:icon="@mipmap/ic_launcher"'),
    );
  });

  test(
    '#327: en Android 8+ es un ícono adaptable con fondo y primer plano',
    () {
      final contenido = _leer('$_res/mipmap-anydpi-v26/ic_launcher.xml');

      expect(contenido, contains('<adaptive-icon'));
      expect(
        contenido,
        contains(
          '<background android:drawable="@color/ic_launcher_background"/>',
        ),
      );
      expect(
        contenido,
        contains(
          '<foreground android:drawable="@mipmap/ic_launcher_foreground"/>',
        ),
      );
    },
  );

  test('#327: el fondo es el verde olivo de la marca (#6B7C3E)', () {
    final contenido = _leer('$_res/values/ic_launcher_background.xml');
    final color = RegExp(
      '<color name="ic_launcher_background">(#[0-9A-Fa-f]+)</color>',
    ).firstMatch(contenido);

    expect(color, isNotNull, reason: 'falta el color ic_launcher_background');
    expect(color!.group(1)!.toUpperCase(), '#6B7C3E');
  });

  group('#327: imágenes por densidad', () {
    for (final MapEntry(key: densidad, value: factor) in _densidades.entries) {
      test('$densidad: primer plano de 108 dp con transparencia', () {
        final png = _encabezadoPng(
          '$_res/mipmap-$densidad/ic_launcher_foreground.png',
        );
        final lado = (108 * factor).round();

        expect(png.ancho, lado);
        expect(png.alto, lado);
        expect(png.tipoColor, _tipoRgbConAlfa, reason: 'debe tener alfa');
      });

      test('$densidad: ícono de Android 7 de 48 dp, opaco', () {
        final png = _encabezadoPng('$_res/mipmap-$densidad/ic_launcher.png');
        final lado = (48 * factor).round();

        expect(png.ancho, lado);
        expect(png.alto, lado);
        expect(
          png.tipoColor,
          _tipoRgb,
          reason: 'el cuadro verde no lleva alfa',
        );
      });
    }
  });
}
