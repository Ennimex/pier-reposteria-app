// test/unitarias/ci/workflows_test.dart — reglas de .github/workflows/ que
// el pipeline necesita sostener y que no tienen código Dart que probar:
//   · todos los trabajos en la imagen fija ubuntu-24.04, para que GitHub no
//     cambie el entorno de las pruebas al mover ubuntu-latest de versión;
//   · ningún trabajo de las etapas de pipeline.yml es condicional: en un
//     Pull Request ninguno puede salir «skipped»;
//   · release.yml solo publica un candidato que pasó las pruebas en el
//     entorno de liberación y que se aprobó en el Environment «produccion».
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cada workflow del repositorio: nombre del archivo → su contenido.
Map<String, String> _workflows() {
  final archivos = Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((archivo) => archivo.path.endsWith('.yml'));
  return {
    for (final archivo in archivos)
      archivo.uri.pathSegments.last: archivo.readAsStringSync(),
  };
}

void main() {
  test('los trabajos de GitHub corren en ubuntu-24.04, no en ubuntu-latest', () {
    final imagenes = <String>[];

    for (final MapEntry(key: workflow, value: contenido)
        in _workflows().entries) {
      for (final uso in RegExp(r'runs-on:\s*(ubuntu-\S+)').allMatches(contenido)) {
        imagenes.add('$workflow: ${uso.group(1)}');
        expect(uso.group(1), 'ubuntu-24.04', reason: workflow);
      }
    }

    // Si ningún trabajo usara una máquina de GitHub, la prueba no revisaría
    // nada.
    expect(imagenes, isNotEmpty);
  });

  test('ninguna etapa de pipeline.yml tiene trabajos condicionales', () {
    final workflows = _workflows();
    final etapas = RegExp(r'uses: \./\.github/workflows/(\S+\.yml)')
        .allMatches(workflows['pipeline.yml']!)
        .map((uso) => uso.group(1)!)
        .toList();
    // Un «if:» con cuatro espacios es de un trabajo (los de los pasos llevan
    // más): un trabajo condicional sale «skipped» cuando no se cumple.
    final condicionDeTrabajo = RegExp('^    if:', multiLine: true);

    expect(etapas, hasLength(7));
    for (final etapa in etapas) {
      expect(
        condicionDeTrabajo.hasMatch(workflows[etapa]!),
        isFalse,
        reason: '$etapa tiene un trabajo con if:',
      );
    }
    // En pipeline.yml, solo «Evidencias y decisión», que corre siempre.
    expect(
      condicionDeTrabajo.allMatches(workflows['pipeline.yml']!),
      hasLength(1),
    );
    expect(workflows['pipeline.yml'], contains('    if: always()'));
  });

  test('release.yml publica solo un candidato probado y aprobado', () {
    final release = _workflows()['release.yml']!;
    final inicioDePublicar = release.indexOf('\n  publicar:');
    final pruebas = release.substring(
      release.indexOf('\n  pruebas-entorno-liberacion:'),
      inicioDePublicar,
    );
    final publicar = release.substring(inicioDePublicar);

    // Las pruebas corren siempre (con un tag y en el ensayo): el candidato
    // de release, en el emulador, contra el entorno aislado.
    expect(RegExp('^    if:', multiLine: true).hasMatch(pruebas), isFalse);
    expect(pruebas, contains('uses: ./.github/actions/entorno-aislado'));
    expect(pruebas, contains('flutter build apk --release'));
    expect(pruebas, contains('dart run tool/smoke_liberacion.dart'));

    // Publicar espera a las pruebas y a la aprobación de «produccion», no
    // corre en el ensayo y al final revisa producción sin escribir nada.
    expect(publicar, contains('needs: pruebas-entorno-liberacion'));
    expect(publicar, contains(r'if: ${{ !inputs.ensayo }}'));
    expect(publicar, contains('name: produccion'));
    expect(
      publicar,
      contains('https://pier-reposteria-backend.onrender.com/api/health'),
    );
  });
}
