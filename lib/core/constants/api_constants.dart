// lib/core/constants/api_constants.dart
import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _webUrl    = 'http://localhost:5000/api';
  static const String _mobileUrl = 'http://192.168.0.82:5000/api';
  // static const String _emulatorUrl = 'http://10.0.2.2:5000/api';
  // static const String _prodUrl = 'https://pier-reposteria-backend.onrender.com/api';

  static String get baseUrl {
    // return _prodUrl; // ← descomentar para producción
    return kIsWeb ? _webUrl : _mobileUrl;
  }

  // ── AUTH ─────────────────────────────────────────────────────────
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
  static const String googleMobile         = '/auth/google/mobile';

  // ── PRODUCTOS ─────────────────────────────────────────────────────
  static const String productos = '/productos';
  static String productoById(String id) => '/productos/$id';

  // ── PEDIDOS ───────────────────────────────────────────────────────
  static const String crearPedido = '/pedidos/crear';
  static const String misPedidos  = '/pedidos/mis-pedidos';

  // ── FAVORITOS ─────────────────────────────────────────────────────
  static const String favoritos = '/favoritos';
  static String favoritoById(String id) => '/favoritos/$id';

  // ── NOTIFICACIONES ────────────────────────────────────────────────
  static const String notificaciones = '/notificaciones';
  static String marcarNotificacionLeida(String id) =>
      '/notificaciones/$id/leer';

  // ── RESEÑAS ───────────────────────────────────────────────────────
  static const String crearResena  = '/resenas';
  static const String misResenas   = '/resenas/mis-resenas';
  static String resenasPorProducto(String id) => '/resenas/producto/$id';
  static String likeResena(String id)          => '/resenas/$id/like';

  // ── REEMBOLSOS ────────────────────────────────────────────────────
  static const String crearReembolso = '/reembolsos';
  static const String misReembolsos  = '/reembolsos/mis-reembolsos';

  // ── CONTACTO ──────────────────────────────────────────────────────
  // Backend: POST /contacto (sin /enviar)
  static const String enviarContacto = '/contacto';
}