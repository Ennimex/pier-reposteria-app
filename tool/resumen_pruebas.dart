// tool/resumen_pruebas.dart — escribe los resultados de cada pipeline en el
// resumen de su corrida de GitHub Actions, para verlos sin descargar
// artifacts (#157). Lo llaman los workflows de .github/workflows/; los
// comandos están en tool/resumen/cli.dart. Ejemplo:
//
//   dart run tool/resumen_pruebas.dart pruebas build/resultados/unitarias.json \
//     --titulo "Pruebas unitarias y de widget" --cobertura coverage/lcov.info
import 'dart:io';

import 'resumen/cli.dart';

void main(List<String> argumentos) {
  exitCode = ejecutar(
    argumentos,
    raiz: Directory.current.path,
    entorno: Platform.environment,
    salida: stdout,
  );
}
