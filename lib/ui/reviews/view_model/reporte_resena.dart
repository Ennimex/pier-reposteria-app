// lib/ui/reviews/view_model/reporte_resena.dart
//
// «Reportar» la reseña de otro cliente (#328). Google Play pide que se pueda
// reportar lo que publican los usuarios, pero el backend todavía no tiene
// dónde guardar reportes: mientras tanto se abre un correo ya escrito a la
// dirección de contacto del negocio, como «Eliminar mi cuenta» (#222). Aquí
// vive todo lo que decide qué se reporta y cómo va el correo; las vistas
// solo lo abren.
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';

class ReporteResena {
  ReporteResena._();

  /// Hasta cuántos caracteres del texto de la reseña van en el correo.
  static const maxTexto = 500;

  /// La línea que el cliente completa con lo que pasa con la reseña.
  static const lineaMotivo = 'Motivo: ';

  static String asunto({
    required String resenaId,
    required String productoNombre,
  }) =>
      'Reportar reseña #$resenaId de $productoNombre';

  /// El aviso cuando no hay app de correo, con la dirección para copiarla.
  static String sinAppDeCorreo(String destinatario) =>
      'No encontramos una app de correo. Escribe a $destinatario para '
      'reportar la reseña.';

  /// ¿Es de otro cliente? Sin sesión, todas lo son. Con sesión, solo las
  /// que llegaron con su autor y no son del cliente: si no se sabe quién la
  /// escribió, no se ofrece reportarla (podría ser la propia).
  static bool esDeOtroCliente({
    required String autorId,
    required bool conSesion,
    String? usuarioSesion,
  }) {
    if (!conSesion) return true;
    final yo = usuarioSesion?.trim() ?? '';
    return autorId.isNotEmpty && yo.isNotEmpty && autorId != yo;
  }

  /// La dirección de contacto del negocio y, si no hay, la de respaldo.
  static String destinatario(String? emailContacto) {
    final email = emailContacto?.trim() ?? '';
    return email.isEmpty ? BusinessInfo.email : email;
  }

  /// El texto hasta [maxTexto] caracteres, con «…» si se recortó. Cuenta
  /// caracteres completos (runas) para no partir un emoji a la mitad.
  static String recortar(String texto) {
    final limpio = texto.trim();
    final runas = limpio.runes;
    if (runas.length <= maxTexto) return limpio;
    return '${String.fromCharCodes(runas.take(maxTexto)).trimRight()}…';
  }

  /// El correo para reportar [resena]: a quién va, el asunto y un cuerpo
  /// con el producto, la reseña como se ve en la app y la línea del motivo.
  static Uri correo({
    required ResenaProducto resena,
    required String productoId,
    required String productoNombre,
    String? emailContacto,
  }) {
    final titulo = resena.titulo.trim();
    final cuerpo = [
      'Hola, Pier:',
      '',
      'Quiero reportar esta reseña de la app.',
      '',
      'Producto: $productoNombre (id $productoId)',
      'Reseña: #${resena.id}',
      'Autor: ${resena.autor.isEmpty ? 'Sin nombre' : resena.autor}',
      'Fecha: ${_fecha(resena.creadaEn)}',
      'Estrellas: ${resena.estrellas} de 5',
      if (titulo.isNotEmpty) 'Título: ${recortar(titulo)}',
      'Texto: ${recortar(resena.comentario)}',
      '',
      lineaMotivo,
    ].join('\n');
    // Con queryParameters los espacios saldrían como «+», que algunas apps
    // de correo dejan tal cual; así salen como %20 (igual que la baja).
    String consulta(Map<String, String> partes) => partes.entries
        .map((parte) => '${parte.key}=${Uri.encodeComponent(parte.value)}')
        .join('&');
    return Uri(
      scheme: 'mailto',
      path: destinatario(emailContacto),
      query: consulta({
        'subject': asunto(resenaId: resena.id, productoNombre: productoNombre),
        'body': cuerpo,
      }),
    );
  }

  /// [correo] con la dirección de contacto guardada en el teléfono (la
  /// última que llegó del servidor); sin ella, la de BusinessInfo. No pide
  /// nada a la red: el correo se abre al instante.
  static Future<Uri> correoConContacto(
    ConfiguracionRepository? configRepo, {
    required ResenaProducto resena,
    required String productoId,
    required String productoNombre,
  }) async {
    final contacto = await configRepo?.contactoGuardado();
    return correo(
      resena: resena,
      productoId: productoId,
      productoNombre: productoNombre,
      emailContacto: contacto?.email,
    );
  }

  static String _fecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }
}
