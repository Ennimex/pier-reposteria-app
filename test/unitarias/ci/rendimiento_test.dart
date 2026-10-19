// test/unitarias/ci/rendimiento_test.dart — peso del APK (flutter build apk
// --analyze-size) y tiempos por cuadro (timeline_summary.json de
// flutter_driver) en el resumen de la corrida (#157).
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/rendimiento.dart';

const int _mb = 1024 * 1024;

/// Misma forma que escribe flutter_tools (base/analyze_size.dart).
Map<String, dynamic> _analisisDePeso() => {
      'n': 'Root',
      'value': 20 * _mb,
      'type': 'apk',
      'children': [
        {
          'n': 'lib',
          'value': 14 * _mb,
          'children': [
            {
              'n': 'arm64-v8a',
              'value': 14 * _mb,
              'children': [
                {
                  'n': 'libapp.so (Dart AOT)',
                  'value': 6 * _mb,
                  'children': [
                    {'n': 'package:flutter', 'value': 3 * _mb},
                    {
                      'n': 'package:pier_reposteria',
                      'children': [
                        {'n': 'package:pier_reposteria/ui', 'value': _mb},
                        {'n': 'package:pier_reposteria/data', 'value': _mb},
                      ],
                    },
                    {'n': 'dart:core', 'value': _mb ~/ 2},
                    {'n': 'dart:_internal', 'value': 4 * _mb},
                    {'n': '@stubs', 'value': 5 * _mb},
                  ],
                },
                {'n': 'libflutter.so (Flutter Engine)', 'value': 8 * _mb},
              ],
            },
          ],
        },
        {'n': 'classes.dex', 'value': 3 * _mb},
        {
          'n': 'assets',
          'value': 2 * _mb,
          'children': [
            {'n': 'flutter_assets', 'value': 2 * _mb},
          ],
        },
      ],
    };

void main() {
  group('leerAnalisisDePeso', () {
    test('desglosa el APK hasta el código Dart y el motor de Flutter', () {
      final partes = leerAnalisisDePeso(_analisisDePeso()).partes;

      expect(partes.map((p) => p.nombre), [
        'lib/arm64-v8a/libflutter.so (Flutter Engine)',
        'lib/arm64-v8a/libapp.so (Dart AOT)',
        'classes.dex',
        'assets/flutter_assets',
      ]);
      expect(partes.first.bytes, 8 * _mb);
    });

    test('ordena los paquetes de Dart sin los internos ni los @', () {
      final paquetes = leerAnalisisDePeso(_analisisDePeso()).paquetes;

      expect(paquetes.map((p) => p.nombre), [
        'package:flutter',
        'package:pier_reposteria',
        'dart:core',
      ]);
      expect(paquetes[1].bytes, 2 * _mb);
    });
  });

  group('resumenPeso', () {
    test('muestra el peso total y lo que más ocupa', () {
      final texto = resumenPeso(
        apk: 'app-prod-release.apk',
        bytes: 19293798,
        analisis: leerAnalisisDePeso(_analisisDePeso()),
      );

      expect(texto, startsWith('### 📦 Peso del APK de release\n'));
      expect(texto, contains('| `app-prod-release.apk` | **18.4 MB** |'));
      expect(
        texto,
        contains('| `lib/arm64-v8a/libflutter.so (Flutter Engine)` | 8.0 MB |'),
      );
      expect(texto, contains('| `package:flutter` | 3.0 MB |'));
    });

    test('sin el desglose muestra solo el peso total', () {
      final texto = resumenPeso(apk: 'app-prod-release.apk', bytes: 2048);

      expect(texto, contains('| `app-prod-release.apk` | **2.0 KB** |'));
      expect(texto, isNot(contains('Paquetes')));
    });
  });

  group('resumenTiempos', () {
    test('pone una columna por medición con los tiempos por cuadro', () {
      final texto = resumenTiempos({
        'catalogo': {
          'frame_count': 1200,
          'average_frame_build_time_millis': 4.21,
          '90th_percentile_frame_build_time_millis': 7.5,
          'worst_frame_build_time_millis': 31.0,
          'missed_frame_build_budget_count': 3,
          'average_frame_rasterizer_time_millis': 6.04,
          '90th_percentile_frame_rasterizer_time_millis': 9.9,
          'worst_frame_rasterizer_time_millis': 40.2,
          'missed_frame_rasterizer_budget_count': 5,
        },
        'checkout': <String, dynamic>{'frame_count': 300},
      });

      expect(texto, startsWith('### ⏱️ Fluidez en el celular\n'));
      expect(texto, contains('| | catalogo | checkout |'));
      expect(texto, contains('| Cuadros dibujados | 1,200 | 300 |'));
      expect(texto, contains('| Construcción promedio | 4.2 ms | — |'));
      expect(
        texto,
        contains('| Cuadros que tardaron más de 16 ms en construirse | 3 | — |'),
      );
    });

    test('avisa si no hubo mediciones', () {
      expect(resumenTiempos({}), contains('No se generaron mediciones'));
    });
  });
}
