//lib/core/constants/api_constants.dart
import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _webUrl    = 'http://localhost:5000/api';
  static const String _mobileUrl = 'http://192.168.0.82:5000/api'; // Celular físico → IP local del PC
  // static const String _emulatorUrl = 'http://10.0.2.2:5000/api'; // Emulador Android
  // static const String _prodUrl = 'https://pier-reposteria-backend.onrender.com/api';

  static String get baseUrl {
    // Cuando se quiera usar Render en producción, descomentar _prodUrl y esta línea:
    // if (!kDebugMode) return _prodUrl;
    return kIsWeb ? _webUrl : _mobileUrl;    // Chrome → localhost, Celular → IP local
  }

  // Auth
  static const String login                = '/auth/login';
  static const String register             = '/auth/register';
  static const String verifyEmail          = '/auth/verify-email';
  static const String resendVerification   = '/auth/resend-verification';
  static const String logout               = '/auth/logout';
  static const String profile              = '/auth/profile';
  static const String updateProfile        = '/auth/update-profile';
  static const String requestPasswordReset = '/auth/request-password-reset';
  static const String resetPassword        = '/auth/reset-password';
  static const String googleAuth           = '/auth/google';

  // ========================================
  // MÓVIL — Google Sign In
  // ========================================
  static const String googleMobile = '/auth/google/mobile';
  // ========================================

  // Productos
  static const String productos = '/productos';
  static String productoById(String id) => '/productos/$id';

  // Pedidos
  static const String crearPedido = '/pedidos/crear';
  static const String misPedidos  = '/pedidos/mis-pedidos';

  // Favoritos
  static const String favoritos = '/favoritos';
  static String favoritoById(String id) => '/favoritos/$id';

  // Notificaciones
  static const String notificaciones = '/notificaciones';
  static String marcarNotificacionLeida(String id) => '/notificaciones/$id/leer';

  // Reseñas
  static const String crearResena = '/resenas/crear';
  static String resenasPorProducto(String id) => '/resenas/producto/$id';

  // Reembolsos
  static const String crearReembolso = '/reembolsos/crear';
  static const String misReembolsos  = '/reembolsos/mis-solicitudes';

  // Contacto
  static const String enviarContacto = '/contacto/enviar';
}