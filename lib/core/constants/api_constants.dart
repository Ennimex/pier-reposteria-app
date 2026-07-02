// lib/core/constants/api_constants.dart

class ApiConstants {
  static const String _prodUrl = 'https://pier-reposteria-backend.onrender.com/api';

  static String get baseUrl => _prodUrl;

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

  // ── CATEGORÍAS ────────────────────────────────────────────────────
  static const String categorias = '/categorias';

  // ── PRODUCTOS ─────────────────────────────────────────────────────
  static const String productos           = '/productos';
  static const String productosDestacados = '/productos-destacados';
  static const String filtros             = '/filtros';
  static String productoById(String id)         => '/productos/$id';
  static String categoriaOpciones(String catId) => '/categoria-opciones/$catId';

  // ── PEDIDOS ───────────────────────────────────────────────────────
  static const String crearPedido        = '/pedidos';
  static const String misPedidos         = '/pedidos/mis-pedidos';
  static const String productosComprados = '/pedidos/productos-comprados';
  static String pedidoById(String id)    => '/pedidos/$id';

  // ── PAGOS (Stripe) ────────────────────────────────────────────────
  static const String crearPaymentIntent = '/pagos/crear-intent';
  static const String confirmarPago      = '/pagos/confirmar';
  static const String stripeConfig       = '/pagos/config';

  // ── CARRITO ───────────────────────────────────────────────────────
  static const String carrito      = '/carrito';
  static const String carritoCount = '/carrito/count';
  static String carritoItem(String itemId) => '/carrito/$itemId';

  // ── PROMOCIONES ───────────────────────────────────────────────────
  static const String promocionesActivas     = '/promociones/activas';
  static const String validarCodigoDescuento = '/promociones/validar-codigo';

  // ── FAVORITOS ─────────────────────────────────────────────────────
  static const String favoritos    = '/favoritos';
  static const String favoritosIds = '/favoritos/ids';
  static String favoritoById(String id) => '/favoritos/$id';

  // ── NOTIFICACIONES ────────────────────────────────────────────────
  static const String notificaciones          = '/notificaciones';
  static const String notificacionesLeerTodas = '/notificaciones/leer-todas';
  static String marcarNotificacionLeida(String id) =>
      '/notificaciones/$id/leer';

  // ── RESEÑAS ───────────────────────────────────────────────────────
  static const String crearResena       = '/resenas';
  static const String misResenas        = '/resenas/mis-resenas';
  static const String resenasDestacadas = '/resenas/destacadas';
  static String resenasPorProducto(String id) => '/resenas/producto/$id';
  static String likeResena(String id)          => '/resenas/$id/like';
  static String editarResena(String id)        => '/resenas/$id';

  // ── REEMBOLSOS ────────────────────────────────────────────────────
  static const String crearReembolso = '/reembolsos';
  static const String misReembolsos  = '/reembolsos/mis-reembolsos';

  // ── QUEJAS Y SUGERENCIAS ──────────────────────────────────────────
  static const String crearQueja = '/quejas';       // ✅ NUEVO: POST auth
  static const String misQuejas  = '/quejas/mis-quejas'; // ✅ NUEVO: GET auth

  // ── CONTACTO ──────────────────────────────────────────────────────
  static const String enviarContacto = '/contacto';

  // ── ENTREGAS (repartidor) ─────────────────────────────────────────
  static const String misEntregas          = '/entregas/mis-entregas';
  static const String disponibilidad       = '/entregas/disponibilidad';
  static String entregaEstado(String id)   => '/entregas/$id/estado';

  // ── UPLOAD ────────────────────────────────────────────────────────
  static const String uploadImagen        = '/upload/imagen';
  static const String updateProfileData   = '/usuarios/perfil/actualizar'; // PUT

  // ── CONFIGURACIÓN (público, solo lectura) ─────────────────────────
  static String configuracionSeccion(String seccion) => '/configuracion/$seccion';
}