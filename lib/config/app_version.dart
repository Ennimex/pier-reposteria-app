// lib/config/app_version.dart
//
// Versión de la app para mostrarla en pantalla (SemVer: MAJOR.MINOR.PATCH+BUILD).
// La fuente de verdad es `version:` en pubspec.yaml; estos valores son su copia
// para la UI. `test/app_version_test.dart` falla si dejan de coincidir, así que
// al subir la versión se cambian ambos lugares en el mismo commit.
class AppVersion {
  AppVersion._();

  static const String name = '1.1.0';
  static const int build = 2;

  /// `1.1.0+2`, igual que en pubspec.yaml.
  static const String full = '$name+$build';
}
