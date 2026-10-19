// tool/resumen/release.dart — publicación al crear un tag vX.Y.Z (#22): el
// tag debe ser la versión del pubspec (la que muestra «Acerca de») y las
// notas de la Release salen de los commits desde el tag anterior, que siguen
// Conventional Commits (feat, fix, refactor…).

/// Null si [tag] es `v` + la versión de [pubspec] sin el número de build
/// (`version: 1.2.0+3` → `v1.2.0`); si no, el motivo en una línea.
String? diferenciaDeVersion(String tag, String pubspec) {
  final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(pubspec)
      ?.group(1);
  if (version == null) return 'El pubspec.yaml no trae `version:`.';
  final esperado = 'v${version.split('+').first}';
  if (tag == esperado) return null;
  return 'El tag `$tag` no coincide con la versión del pubspec '
      '(`$version`): se esperaba `$esperado`.';
}

const _grupos = [
  ('✨ Nuevo', {'feat'}),
  ('🐛 Correcciones', {'fix'}),
  (
    '🔧 Mantenimiento',
    {'refactor', 'perf', 'build', 'ci', 'docs', 'test', 'chore', 'style'},
  ),
];
const _otros = '📝 Otros cambios';

final _convencional = RegExp(r'^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.+)$');
final _merge = RegExp('^Merge (pull request|branch|remote-tracking branch)');

/// Notas en Markdown para la Release [tag] a partir de los asuntos de los
/// commits (`git log --format=%s`), agrupados por tipo y sin los merges.
String notasDeRelease(String tag, List<String> asuntos) {
  final porGrupo = <String, List<String>>{};
  for (final asunto in asuntos.map((a) => a.trim())) {
    if (asunto.isEmpty || _merge.hasMatch(asunto)) continue;
    final (grupo, linea) = _clasificar(asunto);
    porGrupo.putIfAbsent(grupo, () => []).add(linea);
  }

  final texto = StringBuffer('## Pier Repostería $tag\n\n');
  if (porGrupo.isEmpty) {
    texto.writeln('Sin cambios desde la versión anterior.');
    return texto.toString();
  }
  final secciones = [
    for (final titulo in [..._grupos.map((g) => g.$1), _otros])
      if (porGrupo[titulo] case final lineas?)
        '### $titulo\n\n${lineas.map((l) => '- $l\n').join()}',
  ];
  texto.write(secciones.join('\n'));
  return texto.toString();
}

(String, String) _clasificar(String asunto) {
  final partes = _convencional.firstMatch(asunto);
  if (partes == null) return (_otros, asunto);
  final tipo = partes.group(1)!;
  final grupo = _grupos.where((g) => g.$2.contains(tipo)).firstOrNull;
  if (grupo == null) return (_otros, asunto);
  final alcance = partes.group(2);
  final rompe = partes.group(3) != null ? '⚠️ ' : '';
  final descripcion = partes.group(4)!;
  return (
    grupo.$1,
    alcance == null ? '$rompe$descripcion' : '$rompe**$alcance:** $descripcion',
  );
}
