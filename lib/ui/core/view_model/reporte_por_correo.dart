// lib/ui/core/view_model/reporte_por_correo.dart
//
// Lo común de «Reportar» lo que publican otros clientes (#328): las reseñas
// (reporte_resena.dart) y los comentarios de Novedades
// (reporte_comentario.dart). Google Play pide que se pueda reportar, pero el
// backend todavía no tiene dónde guardar reportes: mientras tanto se abre un
// correo ya escrito a la dirección de contacto del negocio, como «Eliminar
// mi cuenta» (#222). Aquí va a quién se escribe, cómo se arma el correo y
// cuánto del texto va; cada reporte pone su asunto y sus datos.
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';

class ReportePorCorreo {
  ReportePorCorreo._();

  /// Hasta cuántos caracteres del texto reportado van en el correo.
  static const maxTexto = 500;

  /// La línea que el cliente completa con lo que pasa.
  static const lineaMotivo = 'Motivo: ';

  /// El aviso cuando no hay app de correo, con la dirección para copiarla;
  /// [que] es lo que se reporta («la reseña», «el comentario»).
  static String sinAppDeCorreo(String destinatario, {required String que}) =>
      'No encontramos una app de correo. Escribe a $destinatario para '
      'reportar $que.';

  /// La dirección de contacto del negocio y, si no hay, la de respaldo.
  static String destinatario(String? emailContacto) {
    final email = emailContacto?.trim() ?? '';
    return email.isEmpty ? BusinessInfo.email : email;
  }

  /// [texto] hasta [max] caracteres, con «…» si se recortó. Cuenta
  /// caracteres completos (runas) para no partir un emoji a la mitad.
  static String recortar(String texto, {int max = maxTexto}) {
    final limpio = texto.trim();
    final runas = limpio.runes;
    if (runas.length <= max) return limpio;
    return '${String.fromCharCodes(runas.take(max)).trimRight()}…';
  }

  /// La fecha como 'dd/mm/aaaa', o 'Sin fecha'.
  static String fecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }

  /// El correo para reportar [que] («esta reseña»): a la dirección de
  /// contacto (o a la de respaldo), con [asunto] y un cuerpo con [datos] (lo
  /// reportado como se ve en la app) y la línea del motivo.
  static Uri correo({
    required String asunto,
    required String que,
    required List<String> datos,
    String? emailContacto,
  }) {
    final cuerpo = [
      'Hola, Pier:',
      '',
      'Quiero reportar $que de la app.',
      '',
      ...datos,
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
      query: consulta({'subject': asunto, 'body': cuerpo}),
    );
  }

  /// La dirección de contacto guardada en el teléfono (la última que llegó
  /// del servidor); null si nunca llegó. No pide nada a la red: el correo se
  /// abre al instante.
  static Future<String?> emailGuardado(
    ConfiguracionRepository? configRepo,
  ) async => (await configRepo?.contactoGuardado())?.email;
}
