// tool/resumen/markdown.dart — formatos que comparten los resúmenes de los
// pipelines (#157). GitHub muestra el resumen de cada corrida en Markdown.
import 'dart:math';

/// 1171 → «1,171», como los números del README.
String miles(int numero) {
  final digitos = numero.abs().toString();
  final texto = StringBuffer(numero < 0 ? '-' : '');
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) texto.write(',');
    texto.write(digitos[i]);
  }
  return texto.toString();
}

/// 84.26 → «84.3 %».
String porcentaje(double valor) => '${valor.toStringAsFixed(1)} %';

/// 112 s → «1 min 52 s».
String duracion(Duration tiempo) {
  if (tiempo.inSeconds < 1) return 'menos de 1 s';
  final minutos = tiempo.inMinutes;
  final segundos = tiempo.inSeconds % 60;
  if (minutos == 0) return '$segundos s';
  if (segundos == 0) return '$minutos min';
  return '$minutos min $segundos s';
}

/// Bytes en B, KB o MB (de 1,024 en 1,024, como Android Studio).
String tamano(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

/// Texto seguro dentro de una celda: una barra o un salto de renglón
/// partirían la tabla.
String celda(String texto) =>
    texto.replaceAll('|', r'\|').replaceAll(RegExp(r'\r?\n'), ' ');

/// Bloque de código; si el texto ya trae una cerca de acentos graves, la
/// del bloque se alarga para no cerrarlo antes de tiempo.
String bloque(String texto) {
  final masLarga = RegExp('`+')
      .allMatches(texto)
      .fold(0, (largo, cerca) => max(largo, cerca.end - cerca.start));
  final cerca = '`' * max(3, masLarga + 1);
  return '${cerca}text\n$texto\n$cerca\n';
}

/// Sección que GitHub muestra cerrada y se despliega con un clic.
String plegable(String titulo, String contenido) =>
    '<details><summary>$titulo</summary>\n\n$contenido\n</details>\n';
