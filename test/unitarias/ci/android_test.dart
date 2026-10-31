// test/unitarias/ci/android_test.dart — configuración de Android que no
// tiene código Dart que probar:
//   · #217: ni el respaldo en la nube ni la transferencia entre celulares
//     copian los datos de la app (sesión y datos personales).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const manifiesto = 'android/app/src/main/AndroidManifest.xml';
  const reglas = 'android/app/src/main/res/xml/data_extraction_rules.xml';

  test('#217: el manifiesto apaga el respaldo y usa las reglas de extracción',
      () {
    final contenido = _leer(manifiesto);

    expect(contenido, contains('android:allowBackup="false"'));
    expect(
      contenido,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('#217: las reglas excluyen todo de la nube y de la transferencia', () {
    final contenido = _leer(reglas);
    const dominios = ['root', 'file', 'database', 'sharedpref', 'external'];

    for (final seccion in ['cloud-backup', 'device-transfer']) {
      final inicio = contenido.indexOf('<$seccion>');
      final fin = contenido.indexOf('</$seccion>');
      expect(inicio, isNonNegative, reason: 'falta <$seccion>');
      final bloque = contenido.substring(inicio, fin);
      for (final dominio in dominios) {
        expect(
          bloque,
          contains('<exclude domain="$dominio" path="." />'),
          reason: '$seccion debe excluir $dominio',
        );
      }
      expect(bloque, isNot(contains('<include')));
    }
  });
}
