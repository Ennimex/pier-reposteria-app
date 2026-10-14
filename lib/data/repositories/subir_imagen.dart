// lib/data/repositories/subir_imagen.dart
//
// Subida de una foto a POST /upload/imagen (Cloudinary), compartida por los
// repositorios que guardan evidencia: la entrega del repartidor y la
// solicitud de reembolso. [tipo] es la carpeta en Cloudinary.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Sube [filePath] y devuelve su URL. Lanza ApiException con el mensaje del
/// backend, o uno genérico si no regresó la URL.
Future<String> subirImagen(
  ApiClient api,
  String filePath, {
  required String tipo,
}) async {
  const porDefecto = 'No se pudo subir la foto';
  final r =
      await api.uploadImageAuth(ApiConstants.uploadImagen, filePath, {'tipo': tipo});
  if (r['success'] != true) {
    throw ApiException(r['message']?.toString() ?? porDefecto);
  }
  final imagen = r['imagen'];
  final url = imagen is Map ? imagen['url']?.toString() : null;
  if (url == null || url.isEmpty) throw const ApiException(porDefecto);
  return url;
}
