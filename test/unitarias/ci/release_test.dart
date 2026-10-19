// test/unitarias/ci/release_test.dart — publicación de la app al crear un
// tag vX.Y.Z (#22): el tag debe coincidir con la versión del pubspec y las
// notas de la Release salen de los commits (Conventional Commits) desde el
// tag anterior.
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/resumen/release.dart';

void main() {
  group('diferenciaDeVersion', () {
    test('el tag coincide con la versión del pubspec sin el build', () {
      expect(diferenciaDeVersion('v1.2.0', 'name: x\nversion: 1.2.0+3\n'),
          isNull);
    });

    test('avisa si el tag no es la versión del pubspec', () {
      final error =
          diferenciaDeVersion('v1.2.1', 'name: x\nversion: 1.2.0+3\n');

      expect(error, contains('v1.2.1'));
      expect(error, contains('1.2.0+3'));
    });

    test('el tag debe empezar con v', () {
      expect(diferenciaDeVersion('1.2.0', 'version: 1.2.0+3\n'), isNotNull);
    });

    test('avisa si el pubspec no trae versión', () {
      expect(diferenciaDeVersion('v1.2.0', 'name: x\n'), isNotNull);
    });
  });

  group('notasDeRelease', () {
    test('agrupa los commits por tipo y quita el prefijo', () {
      final notas = notasDeRelease('v1.2.0', [
        'feat(monitoreo): errores y rendimiento en Sentry',
        'fix(catalogo): avisar sin conexión y ofrecer «Reintentar»',
        'refactor: renombrar el paquete pier_pasteleria a pier_reposteria',
        'docs(ci): explicar los workflows en lenguaje claro',
      ]);

      expect(
        notas,
        '## Pier Repostería v1.2.0\n'
        '\n'
        '### ✨ Nuevo\n'
        '\n'
        '- **monitoreo:** errores y rendimiento en Sentry\n'
        '\n'
        '### 🐛 Correcciones\n'
        '\n'
        '- **catalogo:** avisar sin conexión y ofrecer «Reintentar»\n'
        '\n'
        '### 🔧 Mantenimiento\n'
        '\n'
        '- renombrar el paquete pier_pasteleria a pier_reposteria\n'
        '- **ci:** explicar los workflows en lenguaje claro\n',
      );
    });

    test('omite los merges de los Pull Requests y de ramas', () {
      final notas = notasDeRelease('v1.2.0', [
        'Merge pull request #164 from Ennimex/refactor/renombrar',
        "Merge branch 'main' into feature/firma-release",
        'fix: algo',
      ]);

      expect(notas, isNot(contains('Merge')));
      expect(notas, contains('- algo'));
    });

    test('marca los cambios que rompen compatibilidad', () {
      final notas = notasDeRelease('v2.0.0', ['feat(api)!: nuevo contrato']);

      expect(notas, contains('- ⚠️ **api:** nuevo contrato'));
    });

    test('lo que no sigue Conventional Commits va en otros cambios', () {
      final notas = notasDeRelease('v1.2.0', ['Actualizar el README']);

      expect(notas, contains('### 📝 Otros cambios\n\n- Actualizar el README'));
    });

    test('sin commits lo dice en vez de dejar la Release vacía', () {
      expect(
        notasDeRelease('v1.2.0', ['Merge pull request #1 from a/b']),
        '## Pier Repostería v1.2.0\n\nSin cambios desde la versión anterior.\n',
      );
    });
  });
}
