// lib/config/business_info.dart
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

  // Contacto. El teléfono y el WhatsApp son el respaldo de la configuración
  // (contacto) cuando nunca llegó: los reales, los mismos de la web (#312).
  static const String telefono = '789 896 5413';
  static const String email = 'pierreposteria@gmail.com';

  /// Sitio web / panel administrativo (roles internos operan aquí).
  static const String sitioWeb = 'https://pier-reposteria.vercel.app';

  /// Solo dígitos con lada país, para enlaces de WhatsApp (wa.me).
  static const String whatsappNumero = '527898965413';

  // Horario. Respaldo de la configuración de contacto (`horarios`) cuando
  // nunca llegó (#320): el que Dirección capturó en el panel para cada
  // sucursal, tomado de «Encuéntranos» el 15-nov-2026. Si la Lic. Itzel da
  // otro, se cambia aquí y en la tabla del #320.
  static const List<({String sucursal, String horario})> sucursales = [
    (sucursal: 'Sucursal Aviacion', horario: 'Lun - Dom: 8:00 AM - 9:00 PM'),
    (sucursal: 'Sucursal Tahuizan', horario: 'Lun - Dom: 9:00 AM - 10:00 PM'),
  ];

  /// El de [sucursales] en una línea, para mostrar.
  static const String horario =
      'Lun–Dom • Aviación 8:00–21:00 · Tahuizán 9:00–22:00 hrs';

  // Las horas en que abren las dos [sucursales], para la lógica de abierto o
  // cerrado (DateTime.weekday: lunes=1 … domingo=7): Lun–Dom, 9:00–21:00.
  static const int horaApertura = 9;
  static const int horaCierre = 21;
  static const List<int> diasAbiertos = [1, 2, 3, 4, 5, 6, 7]; // Lun–Dom

  /// ¿El negocio está abierto ahora (o en la fecha dada)?
  static bool estaAbierto([DateTime? ahora]) {
    final now = ahora ?? DateTime.now();
    if (!diasAbiertos.contains(now.weekday)) return false;
    final minutos = now.hour * 60 + now.minute;
    return minutos >= horaApertura * 60 && minutos < horaCierre * 60;
  }

  /// Enlace directo a WhatsApp con un mensaje opcional.
  static String whatsappUrl([String mensaje = 'Hola, tengo una pregunta']) =>
      'https://wa.me/$whatsappNumero?text=${Uri.encodeComponent(mensaje)}';
}
