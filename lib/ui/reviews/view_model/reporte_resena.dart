// lib/ui/reviews/view_model/reporte_resena.dart
//
// «Reportar» la reseña de otro cliente (#328). Google Play pide que se pueda
// reportar lo que publican los usuarios, pero el backend todavía no tiene
// dónde guardar reportes: mientras tanto se abre un correo ya escrito a la
// dirección de contacto del negocio, como «Eliminar mi cuenta» (#222). Aquí
// vive lo que decide qué reseñas se reportan y qué dice su correo; a quién
// va y cómo se arma es lo común con los comentarios de Novedades
// (ReportePorCorreo). Las vistas solo lo abren.
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/core/view_model/reporte_por_correo.dart';

class ReporteResena {
  ReporteResena._();

  /// Hasta cuántos caracteres del texto de la reseña van en el correo.
  static const int maxTexto = ReportePorCorreo.maxTexto;

  static String asunto({
    required String resenaId,
    required String productoNombre,
  }) =>
      'Reportar reseña #$resenaId de $productoNombre';

  /// El aviso cuando no hay app de correo, con la dirección para copiarla.
  static String sinAppDeCorreo(String destinatario) =>
      ReportePorCorreo.sinAppDeCorreo(destinatario, que: 'la reseña');

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

  /// El texto hasta [maxTexto] caracteres, con «…» si se recortó.
  static String recortar(String texto) => ReportePorCorreo.recortar(texto);

  /// El correo para reportar [resena]: a quién va, el asunto y un cuerpo
  /// con el producto, la reseña como se ve en la app y la línea del motivo.
  static Uri correo({
    required ResenaProducto resena,
    required String productoId,
    required String productoNombre,
    String? emailContacto,
  }) {
    final titulo = resena.titulo.trim();
    return ReportePorCorreo.correo(
      asunto: asunto(resenaId: resena.id, productoNombre: productoNombre),
      que: 'esta reseña',
      emailContacto: emailContacto,
      datos: [
        'Producto: $productoNombre (id $productoId)',
        'Reseña: #${resena.id}',
        'Autor: ${resena.autor.isEmpty ? 'Sin nombre' : resena.autor}',
        'Fecha: ${ReportePorCorreo.fecha(resena.creadaEn)}',
        'Estrellas: ${resena.estrellas} de 5',
        if (titulo.isNotEmpty) 'Título: ${recortar(titulo)}',
        'Texto: ${recortar(resena.comentario)}',
      ],
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
  }) async =>
      correo(
        resena: resena,
        productoId: productoId,
        productoNombre: productoNombre,
        emailContacto: await ReportePorCorreo.emailGuardado(configRepo),
      );
}
