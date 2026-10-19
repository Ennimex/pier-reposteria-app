// lib/data/repositories/respuesta_api.dart
//
// Revisión común de las respuestas de los módulos que releen al usuario en
// cada petición (comandas y publicaciones, middleware usuarioVigente del
// backend): si la cuenta ya no está vigente responden
// `codigo: 'SESION_INVALIDA'`.
import 'package:pier_reposteria/data/api_exception.dart';

/// [respuesta] si trae success: true; si no, SesionInvalidaException (cuenta
/// desactivada o cambiada) o ApiException con su mensaje (o [porDefecto]).
Map<String, dynamic> exigirExito(
  Map<String, dynamic> respuesta,
  String porDefecto,
) {
  if (respuesta['success'] == true) return respuesta;
  final mensaje = respuesta['message']?.toString() ?? porDefecto;
  if (respuesta['codigo'] == 'SESION_INVALIDA') {
    throw SesionInvalidaException(mensaje);
  }
  throw ApiException(mensaje);
}
