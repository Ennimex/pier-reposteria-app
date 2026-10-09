// lib/domain/models/codigo_alexa.dart
//
// Código de un solo uso para vincular la cuenta con la skill de Alexa.
// Fuente: POST /api/auth/alexa/generar-codigo -> {codigo, expira_en_segundos}
class CodigoAlexa {
  const CodigoAlexa({required this.codigo, required this.expiraEnSegundos});

  factory CodigoAlexa.fromJson(Map<String, dynamic> json) => CodigoAlexa(
        codigo: json['codigo'].toString(),
        expiraEnSegundos:
            (json['expira_en_segundos'] as num?)?.toInt() ?? duracionPorDefecto,
      );

  /// El backend da 5 minutos; se usa si la respuesta no trae el dato.
  static const int duracionPorDefecto = 300;

  final String codigo;
  final int expiraEnSegundos;
}
