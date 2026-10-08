// lib/config/api_constants.dart
//
// La URL del backend depende del ambiente, que se elige al compilar:
//   flutter run --dart-define=AMBIENTE=dev
//   flutter run --dart-define=AMBIENTE=dev --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
// Sin --dart-define el ambiente es prod (el build de siempre).

enum Ambiente { dev, staging, prod }

class ApiConstants {
  static const String prodUrl = 'https://pier-reposteria-backend.onrender.com/api';

  /// Backend local en la PC, visto desde el emulador de Android. En un
  /// celular físico usar API_BASE_URL con la IP de la PC en la red.
  static const String devUrl = 'http://10.0.2.2:3000/api';

  static const String _ambienteDefine =
      String.fromEnvironment('AMBIENTE', defaultValue: 'prod');
  static const String _urlForzada = String.fromEnvironment('API_BASE_URL');

  static Ambiente get ambiente => ambienteDesde(_ambienteDefine);

  static String get baseUrl => resolverBaseUrl(
        ambiente,
        // Sin --dart-define el analizador ve '' y lo cree redundante, pero
        // quitarlo rompería API_BASE_URL.
        // ignore: avoid_redundant_argument_values
        urlForzada: _urlForzada,
      );

  /// Valor de AMBIENTE a enum; vacío o desconocido es prod.
  static Ambiente ambienteDesde(String valor) => Ambiente.values.firstWhere(
        (a) => a.name == valor.trim().toLowerCase(),
        orElse: () => Ambiente.prod,
      );

  static String resolverBaseUrl(Ambiente ambiente, {String urlForzada = ''}) {
    if (urlForzada.isNotEmpty) return urlForzada;
    switch (ambiente) {
      case Ambiente.dev:
        return devUrl;
      case Ambiente.staging:
        // Aún no existe un backend de staging: usa el de producción.
        return prodUrl;
      case Ambiente.prod:
        return prodUrl;
    }
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
  static const String alexaGenerarCodigo   = '/auth/alexa/generar-codigo';

  // ── CATEGORÍAS ────────────────────────────────────────────────────
  static const String categorias = '/categorias';

  // ── PRODUCTOS ─────────────────────────────────────────────────────
  static const String productos           = '/productos';
  static const String productosDestacados = '/productos-destacados';
  static const String filtros             = '/filtros';
  static String productoById(String id)         => '/productos/$id';
  static String categoriaOpciones(String catId) => '/categoria-opciones/$catId';
  // Recomendaciones (público): top 3 afines por co-compra; si hay poco
  // historial el backend cae a más vendidos de otras categorías (afinidad null)
  static String recomendaciones(String productoId) =>
      '/recomendaciones/$productoId';

  // ── PEDIDOS ───────────────────────────────────────────────────────
  static const String crearPedido        = '/pedidos';
  static const String misPedidos         = '/pedidos/mis-pedidos';
  static const String productosComprados = '/pedidos/productos-comprados';
  static String pedidoById(String id)    => '/pedidos/$id';
  // Cancelación por el propio cliente: solo estados pendiente/listo,
  // mientras ningún repartidor haya tomado el pedido
  static String pedidoCancelar(String id) => '/pedidos/$id/cancelar';

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

  // ── DIRECCIONES DE ENTREGA (cliente) ──────────────────────────────
  static const String direcciones          = '/direcciones';
  static String direccionById(String id)   => '/direcciones/$id';

  // ── ZONAS DE ENVÍO (público) ──────────────────────────────────────
  static const String zonasColonias        = '/zonas-envio/colonias';
  static String cotizarEnvio(String colonia) =>
      '/zonas-envio/cotizar?colonia=${Uri.encodeQueryComponent(colonia)}';

  // ── ENTREGAS (repartidor) ─────────────────────────────────────────
  static const String misEntregas          = '/entregas/mis-entregas';
  static const String entregasDisponibles  = '/entregas/disponibles';
  static const String entregasAceptar      = '/entregas/aceptar';
  static const String disponibilidad       = '/entregas/disponibilidad';
  static String entregaEstado(String id)   => '/entregas/$id/estado';
  // Aviso "llegué al domicilio": notifica al cliente sin cambiar estado
  static String entregaLlegue(String id)   => '/entregas/$id/llegue';

  // ── DEMANDA NO ATENDIDA (público, registro silencioso) ────────────
  // Espejo de src/utils/demandaNoAtendida.ts de la web. Alimentan el reporte
  // "qué buscó la gente y no tuvimos" del panel de Dirección.
  static const String busquedas     = '/busquedas';      // {texto, num_resultados}
  static const String clicsAgotados = '/clics-agotados'; // {producto_id}

  // ── UPLOAD ────────────────────────────────────────────────────────
  static const String uploadImagen        = '/upload/imagen';
  static const String updateProfileData   = '/usuarios/perfil/actualizar'; // PUT

  // ── CONFIGURACIÓN (público, solo lectura) ─────────────────────────
  static String configuracionSeccion(String seccion) => '/configuracion/$seccion';
}
