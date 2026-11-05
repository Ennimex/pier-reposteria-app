// lib/ui/feed/view_model/reporte_comentario.dart
//
// «Reportar» el comentario de otro cliente en Novedades (#328), como las
// reseñas: un correo ya escrito a la dirección de contacto del negocio
// (ReportePorCorreo) mientras el backend no tenga dónde guardar reportes.
// Aquí se decide en cuáles comentarios se ofrece y qué dice el correo; lo
// usan la tarjeta de la publicación (FeedViewModel) y la hoja de comentarios
// (ComentariosViewModel). La publicación y la respuesta de Pier son de la
// marca, no de un cliente: esas no se reportan.
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/core/view_model/reporte_por_correo.dart';

class ReporteComentario {
  ReporteComentario._();

  /// Hasta cuántos caracteres del texto de la publicación van en el correo:
  /// solo el inicio, para que Pier la ubique.
  static const maxTextoPublicacion = 80;

  static String asunto({
    required int comentarioId,
    required int publicacionId,
  }) => 'Reportar comentario #$comentarioId de la publicación #$publicacionId';

  /// El aviso cuando no hay app de correo, con la dirección para copiarla.
  static String sinAppDeCorreo(String destinatario) =>
      ReportePorCorreo.sinAppDeCorreo(destinatario, que: 'el comentario');

  /// ¿Es de otro cliente? El servidor dice en cada comentario si es del
  /// cliente con sesión (es_tuyo) y si lo puede borrar: el que se puede
  /// borrar es suyo y no se reporta, y si no dijo de quién es, tampoco
  /// (podría ser el propio). Sin sesión no hay comentarios que ver: el
  /// backend niega Novedades a quien no inició sesión.
  static bool esDeOtroCliente(ComentarioPublicacion comentario) =>
      !comentario.esOficial &&
      comentario.esTuyo == false &&
      !comentario.puedeBorrar;

  /// El correo para reportar [comentario] de la publicación
  /// [publicacionId]: la publicación (el inicio de [publicacionTexto], en un
  /// renglón), el comentario como se ve en la app y la línea del motivo.
  static Uri correo({
    required ComentarioPublicacion comentario,
    required int publicacionId,
    String? publicacionTexto,
    String? emailContacto,
  }) {
    final inicio = ReportePorCorreo.recortar(
      (publicacionTexto ?? '').replaceAll(RegExp(r'\s+'), ' '),
      max: maxTextoPublicacion,
    );
    final autor = comentario.autorNombre.trim();
    return ReportePorCorreo.correo(
      asunto: asunto(comentarioId: comentario.id, publicacionId: publicacionId),
      que: 'este comentario',
      emailContacto: emailContacto,
      datos: [
        if (inicio.isEmpty)
          'Publicación: #$publicacionId'
        else
          'Publicación: #$publicacionId «$inicio»',
        'Comentario: #${comentario.id}',
        'Autor: ${autor.isEmpty ? 'Sin nombre' : autor}',
        // Llega en UTC; el día es el del teléfono, como en la tarjeta
        'Fecha: ${ReportePorCorreo.fecha(comentario.creado?.toLocal())}',
        'Texto: ${ReportePorCorreo.recortar(comentario.texto)}',
      ],
    );
  }

  /// [correo] con la dirección de contacto guardada en el teléfono; sin
  /// ella, la de BusinessInfo. No pide nada a la red.
  static Future<Uri> correoConContacto(
    ConfiguracionRepository? configRepo, {
    required ComentarioPublicacion comentario,
    required int publicacionId,
    String? publicacionTexto,
  }) async => correo(
    comentario: comentario,
    publicacionId: publicacionId,
    publicacionTexto: publicacionTexto,
    emailContacto: await ReportePorCorreo.emailGuardado(configRepo),
  );
}
