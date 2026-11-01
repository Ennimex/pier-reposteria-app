// test/unitarias/ci/workflows_test.dart — reglas de .github/workflows/ que
// el pipeline necesita sostener y que no tienen código Dart que probar:
//   · todos los trabajos en la imagen fija ubuntu-24.04, para que GitHub no
//     cambie el entorno de las pruebas al mover ubuntu-latest de versión;
//   · ningún trabajo de las etapas de pipeline.yml es condicional: en un
//     Pull Request ninguno puede salir «skipped»;
//   · release.yml solo publica un candidato que pasó las pruebas en el
//     entorno de liberación y que se aprobó en el Environment «produccion»;
//   · pipeline.yml corre en los Pull Requests y pushes de main y de develop
//     (estrategia de ramas del README);
//   · los trabajos que compilan el APK en una computadora de GitHub liberan
//     disco antes, sin tocar el SDK de Android;
//   · el arranque en frío se mide contra el APK de develop, que solo guarda
//     un push a develop, con permiso de leer artefactos solo donde hace falta.
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

  test('release.yml arma el AAB en el ensayo y publica el firmado (#226)', () {
    final release = _workflows()['release.yml']!.replaceAll('\r\n', '\n');
    final inicioDePublicar = release.indexOf('\n  publicar:');
    final pruebas = release.substring(0, inicioDePublicar);
    final publicar = release.substring(inicioDePublicar);
    const aabDeGradle =
        'build/app/outputs/bundle/prodRelease/app-prod-release.aab';

    // En las pruebas (también en el ensayo) se comprueba que el AAB compila
    // y trae el código de las tres arquitecturas.
    expect(pruebas, contains('flutter build appbundle --release --flavor prod'));
    expect(pruebas, contains(aabDeGradle));
    for (final arquitectura in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
      expect(pruebas, contains('base/lib/$arquitectura/libapp.so'));
    }

    // Al publicar: el AAB con Sentry, firmado con la llave del equipo (la
    // huella se compara antes de copiarlo) y adjunto a la Release.
    expect(
      publicar,
      contains('flutter build appbundle --release --flavor prod '
          r'--dart-define=SENTRY_DSN="$SENTRY_DSN"'),
    );
    final verificacion = publicar.indexOf('keytool -printcert -jarfile');
    expect(verificacion, isNonNegative);
    expect(
      publicar.indexOf(r'cp "$aab"'),
      greaterThan(verificacion),
    );
    expect(
      publicar,
      contains(r'build/pier-reposteria-${{ github.ref_name }}.aab'),
    );
    expect(publicar, contains('build/pier-reposteria-*.aab'));
  });

  test('los trabajos que compilan el APK liberan disco antes, sin tocar el SDK '
      'de Android', () {
    // Compila el APK quien lo arma, lo maneja con flutter drive o corre
    // pruebas de integration_test en el emulador.
    final compila = RegExp(
        'flutter build apk|flutter drive|flutter test integration_test');
    final revisados = <String>[];

    for (final MapEntry(key: workflow, value: contenido)
        in _workflows().entries) {
      final texto = contenido.replaceAll('\r\n', '\n');
      final inicioTrabajos = texto.indexOf('\njobs:\n');
      if (inicioTrabajos < 0) continue;
      final trabajos = texto
          .substring(inicioTrabajos)
          .split(RegExp(r'\n(?=  [a-zA-Z0-9_-]+:\n)'))
          .skip(1);
      for (final trabajo in trabajos) {
        if (!trabajo.contains('runs-on: ubuntu-24.04') ||
            !compila.hasMatch(trabajo)) {
          continue;
        }
        final nombre = '$workflow: ${trabajo.split(':').first.trim()}';
        revisados.add(nombre);
        final libera = trabajo.indexOf('uses: ./.github/actions/liberar-disco');
        expect(libera, isNot(-1), reason: '$nombre no libera disco');
        // Antes de compilar: si no, el disco ya se llenó.
        expect(libera, lessThan(compila.firstMatch(trabajo)!.start),
            reason: '$nombre libera disco después de compilar');
      }
    }

    // Los 10 de hoy: aceptación, monkey, smoke, flujo de compra aislado,
    // peso, arranque, flujo de compra, regresión completa y los dos de
    // release. Si la prueba no encontrara ninguno, no revisaría nada.
    expect(revisados, hasLength(greaterThanOrEqualTo(10)));
    final accion =
        File('.github/actions/liberar-disco/action.yml').readAsStringSync();
    final borra = RegExp(r'rm -rf[^\n]*(\\\r?\n[^\n]*)*').stringMatch(accion)!;
    expect(borra, isNot(contains('android')));
    expect(borra, isNot(contains('ndk')));
  });

  test('el arranque se mide contra el APK de develop, que solo guarda un push '
      'a develop', () {
    final workflows = _workflows();
    final rendimiento =
        workflows['rendimiento.yml']!.replaceAll('\r\n', '\n');
    final arranque =
        rendimiento.substring(rendimiento.indexOf('\n  arranque-en-frio:'));
    final guardar = arranque.substring(
      arranque.indexOf('- name: Guardar el APK de develop'),
      arranque.indexOf('- name: Descargar el APK de develop'),
    );

    // Solo un push a develop guarda la referencia, 14 días; un Pull Request
    // nunca la reemplaza.
    expect(
      guardar,
      contains("if: github.event_name == 'push' && "
          "github.ref == 'refs/heads/develop'"),
    );
    expect(guardar, contains('name: apk-arranque-develop'));
    expect(guardar, contains('retention-days: 14'));
    // Se descarga sin tomar el de esta misma corrida y el emulador lo recibe.
    expect(arranque, contains(r'CORRIDA: ${{ github.run_id }}'));
    expect(arranque, contains('bash tool/arranque_alternado.sh'));
    expect(arranque, contains(r'${{ steps.apk-develop.outputs.apk }}'));
    // Leer artefactos: solo el trabajo del arranque y, en pipeline.yml, solo
    // la etapa de rendimiento que lo llama.
    expect(RegExp('actions: read').allMatches(rendimiento), hasLength(1));
    expect(arranque, contains('actions: read'));
    final pipeline = workflows['pipeline.yml']!.replaceAll('\r\n', '\n');
    expect(RegExp('actions: read').allMatches(pipeline), hasLength(1));
    expect(
      pipeline.substring(
        pipeline.indexOf('\n  rendimiento:'),
        pipeline.indexOf('\n  esfuerzo:'),
      ),
      contains('actions: read'),
    );
  });

  test('pipeline.yml corre en los Pull Requests y pushes de main y develop', () {
    final pipeline = _workflows()['pipeline.yml']!;
    final disparadores = RegExp(
      r'^  (pull_request|push):\s*\n    branches: \[(.*)\]',
      multiLine: true,
    ).allMatches(pipeline.replaceAll('\r\n', '\n'));

    expect(
      {
        for (final disparador in disparadores)
          disparador.group(1): disparador.group(2),
      },
      {'pull_request': 'main, develop', 'push': 'main, develop'},
    );
  });

  test('SonarCloud espera el quality gate salvo en un push a develop, sin '
      'if:', () {
    final analisis = _workflows()['analisis-estatico.yml']!
        .replaceAll('\r\n', '\n');
    final trabajoDeSonar = analisis.substring(
      analisis.indexOf('\n  sonarcloud:'),
    );

    // La expresión: verdadera en los Pull Requests y en el push a main.
    expect(
      trabajoDeSonar,
      contains(
        r"ESPERA_EL_QUALITY_GATE: ${{ github.event_name != 'push' || "
        "github.ref_name != 'develop' }}",
      ),
    );
    expect(
      trabajoDeSonar,
      contains(r'-Dsonar.qualitygate.wait=${{ env.ESPERA_EL_QUALITY_GATE }}'),
    );
    // Ni el trabajo ni sus pasos son condicionales: corren siempre.
    expect(RegExp(r'^\s+if:', multiLine: true).hasMatch(trabajoDeSonar), isFalse);
  });
}
