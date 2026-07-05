// lib/core/constants/business_info.dart
//
// FUENTE ÚNICA de la información del negocio.
// El backend NO expone dirección/teléfono/email/horario/redes por ninguna ruta
// (la tabla de configuración es key-value sin seed y no tiene sección
// contacto/horarios). Por eso estos datos viven aquí, centralizados, para
// evitar copias hardcodeadas e inconsistentes por toda la app.
//
// Si algún día el backend empieza a exponer estos datos, basta con cambiarlos
// aquí (o cablear el fetch), sin tocar cada pantalla.
class BusinessInfo {
  BusinessInfo._();

  // Marca
  static const String marca = 'Pier Repostería';
  static const String tagline = 'Dulces momentos';

  // Sucursal / ubicación
  static const String sucursal = 'Sucursal Principal';
  static const String calle = 'Calle Allende, Col. Tahuizán';
  static const String ciudad = 'Huejutla de Reyes, Hgo.';
  static const String cp = '43000';

  /// Dirección corta (una línea, para tarjetas/checkout).
  static const String direccion = '$calle — $ciudad';

  /// Dirección completa (con CP, para legal/FAQ/Nosotros).
  static const String direccionCompleta =
      '$calle, $ciudad, C.P. $cp';

  // Contacto
  static const String telefono = '771 123 4567';
  static const String email = 'pierreposteria@gmail.com';

  /// Sitio web / panel administrativo (roles internos operan aquí).
  static const String sitioWeb = 'https://pier-reposteria.vercel.app';

  /// Solo dígitos con lada país, para enlaces de WhatsApp (wa.me).
  static const String whatsappNumero = '527711234567';

  // Horario
  static const String horario = 'Lun–Sáb • 9:00 – 21:00 hrs';

  /// Enlace directo a WhatsApp con un mensaje opcional.
  static String whatsappUrl([String mensaje = 'Hola, tengo una pregunta']) =>
      'https://wa.me/$whatsappNumero?text=${Uri.encodeComponent(mensaje)}';
}
