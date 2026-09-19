// lib/ui/more/widgets/more_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/utils/config_format.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/order_provider.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/public/widgets/about_us_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/faq_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/legal_screen.dart';
import 'package:pier_pasteleria/ui/favorites/widgets/favorites_screen.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:pier_pasteleria/ui/refunds/widgets/refunds_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/my_reviews_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/profile_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/quejas_screen.dart'; // ✅ NUEVO
import 'package:pier_pasteleria/ui/more/widgets/vincular_alexa_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _configRepo = ConfiguracionRepository();
  final _pedidosRepo = PedidosRepository();
  final _favoritosRepo = FavoritosRepository();
  final _resenasRepo = ResenasRepository();

  int _totalPedidos   = 0;
  int _totalFavoritos = 0;
  int _totalResenas   = 0;
  bool _loadingStats  = true;

  Map<String, dynamic> _configContacto = {};
  bool _loadingConfig = true;

  String? _lastUserEmail;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userEmail = auth.currentUser?['email']?.toString();

    if (userEmail != _lastUserEmail) {
      _lastUserEmail = userEmail;
      if (auth.isAuthenticated && userEmail != null) {
        _cargarStats();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _totalPedidos   = 0;
              _totalFavoritos = 0;
              _totalResenas   = 0;
              _loadingStats   = false;
            });
          }
        });
      }
    }
  }

  Future<void> _cargarConfiguracion() async {
    // El horario vive dentro de 'contacto' (clave 'horarios'); no hay seccion
    // 'horarios' publica.
    final result =
        await _configRepo.seccion('contacto');

    if (!mounted) return;
    setState(() {
      if (result['success'] == true) {
        _configContacto = Map<String, dynamic>.from(result['config'] ?? {});
      }
      _loadingConfig = false;
    });
  }

  Future<void> _cargarStats() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      if (mounted) setState(() => _loadingStats = false);
      return;
    }

    final results = await Future.wait([
      _pedidosRepo.misPedidos(),
      _favoritosRepo.ids(),
      _resenasRepo.misResenas(),
    ]);

    if (!mounted) return;
    setState(() {
      _totalPedidos = results[0]['success'] == true
          ? ((results[0]['pedidos'] ?? []) as List).length : 0;
      _totalFavoritos = results[1]['success'] == true
          ? ((results[1]['ids'] ?? []) as List).length : 0;
      _totalResenas = results[2]['success'] == true
          ? ((results[2]['resenas'] ?? []) as List).length : 0;
      _loadingStats = false;
    });
  }

  void _goProtected(Widget screen) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      context.go(AppRoutes.login);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  void _showLogoutDialog(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content:
            const Text('¿Estás seguro que deseas cerrar tu sesión?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // Limpiar el estado en memoria del usuario que se va:
              // las pestañas viven en el IndexedStack y sin esto
              // seguirían mostrando sus pedidos/carrito/notificaciones
              // como invitado (o al entrar con otra cuenta).
              final orders = context.read<OrderProvider>();
              final cart = context.read<CartProvider>();
              final notifs = context.read<NotificationProvider>();
              await auth.logout();
              orders.limpiar();
              cart.limpiarLocal(); // solo local: el backend lo conserva
              notifs.stopPolling(); // detiene polling y limpia lista/badge
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, elevation: 0),
            child: const Text('Salir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth     = Provider.of<AuthProvider>(context);
    final isAuth   = auth.isAuthenticated;
    final user     = auth.currentUser;
    final nombre   = user?['nombre']?.toString() ?? '';
    final apellido = user?['apellido']?.toString() ?? '';
    final email    = user?['email']?.toString() ?? '';
    final apellidoInicial =
        apellido.isNotEmpty ? apellido[0].toUpperCase() : '';
    final iniciales =
        '${nombre.isNotEmpty ? nombre[0].toUpperCase() : ''}$apellidoInicial';
    final fotoUrl = user?['avatar_url']?.toString() ??
        user?['foto_url']?.toString();

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── HERO HEADER ─────────────────────────────────────────
          _buildHeroHeader(
              isAuth, nombre, email, iniciales, fotoUrl, auth),
          const SizedBox(height: 20),

          // ── STATS (solo con sesión) ──────────────────────────────
          // El banner "Pier Rewards" para invitados se quitó (2026-07-25):
          // prometía un programa de puntos/sorteos que no existe en backend.
          if (isAuth) ...[
            _buildStatsRow(),
            const SizedBox(height: 24),
          ],

          // ── ENCUÉNTRANOS ─────────────────────────────────────────
          _buildEncuentranos(),
          const SizedBox(height: 24),

          // ── MI CUENTA ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mi Cuenta',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Playfair Display')),
                if (!isAuth)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Acceso requerido',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.pierVerde,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildCard(children: [
              _buildTile(
                icon: Icons.favorite_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Mis Favoritos',
                onTap: () => _goProtected(const FavoritesScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.bell,
                iconColor: AppColors.pierVerde,
                title: 'Notificaciones',
                onTap: () => _goProtected(const NotificationsScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.star_rounded,
                iconColor: AppColors.pierDorado,
                title: 'Mis Reseñas',
                onTap: () => _goProtected(const MyReviewsScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.receiptText,
                iconColor: AppColors.pierVerde,
                title: 'Mis Reembolsos',
                onTap: () => _goProtected(const RefundsScreen()),
              ),
              _buildDivider(), // ✅ NUEVO
              _buildTile(     // ✅ NUEVO
                icon: LucideIcons.messageCircle,
                iconColor: AppColors.pierDoradoOscuro,
                title: 'Quejas y Sugerencias',
                onTap: () => _goProtected(QuejasScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.mic,
                iconColor: AppColors.pierVerde,
                title: 'Vincular con Alexa',
                onTap: () => _goProtected(const VincularAlexaScreen()),
                last: true,
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── ACERCA DE PIER ───────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Acerca de Pier',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Playfair Display')),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildCard(children: [
              _buildTile(
                icon: LucideIcons.bookOpen,
                iconColor: AppColors.pierVerde,
                title: 'Nuestra Historia',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AboutUsScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.circleHelp,
                iconColor: AppColors.pierVerde,
                title: 'Preguntas Frecuentes',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const FAQScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.messageCircle,
                iconColor: AppColors.pierVerde,
                title: 'Contacto',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ContactScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: LucideIcons.shield,
                iconColor: AppColors.pierVerde,
                title: 'Términos Legales y Privacidad',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const LegalScreen())),
                last: true,
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── BADGES ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: _buildBadgeCard(
                  LucideIcons.cookie, 'Artesanal', 'Hecho a mano')),
              const SizedBox(width: 12),
              Expanded(child: _buildBadgeCard(
                  LucideIcons.flame,
                  'Fresco', 'Horneado hoy')),
            ]),
          ),

          const SizedBox(height: 24),

          // ── CERRAR SESIÓN ─────────────────────────────────────────
          if (isAuth)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => _showLogoutDialog(auth),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.logOut,
                          color: AppColors.error, size: 18),
                    ),
                    const SizedBox(width: 14),
                    const Text('Cerrar sesión',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error)),
                  ]),
                ),
              ),
            ),

          const SizedBox(height: 28),

          // ── FOOTER ───────────────────────────────────────────────
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _footerIcon(LucideIcons.circleHelp),
                const SizedBox(width: 20),
                _footerIcon(LucideIcons.shieldAlert),
                const SizedBox(width: 20),
                _footerIcon(LucideIcons.info),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Versión 1.0.0 • Pier Repostería',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Hecho con amor en la panadería',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── ENCUÉNTRANOS ─────────────────────────────────────────────────
  Widget _buildEncuentranos() {
    final direccion = formatearDireccion(_configContacto['direccion'],
        fallback: BusinessInfo.direccion);
    final telefono =
        _configContacto['telefono']?.toString() ?? BusinessInfo.telefono;
    final emailContacto =
        _configContacto['email']?.toString() ?? BusinessInfo.email;
    final horario = formatearHorario(_configContacto['horarios'],
        fallback: BusinessInfo.horario);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Encuéntranos',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Playfair Display')),
          const SizedBox(height: 12),
          _loadingConfig
              ? Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.pierVerde, strokeWidth: 2),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.pierVerdeOscuro,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.pierVerdeOscuro
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.mapPin,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(BusinessInfo.sucursal,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(direccion,
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.15),
                            height: 1),
                      ),

                      Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.clock,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Horario de atención',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(horario,
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),

                      if (telefono.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.15),
                              height: 1),
                        ),
                        Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.phone,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Teléfono',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(telefono,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                      ],

                      if (emailContacto.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.15),
                              height: 1),
                        ),
                        Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.mail,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(emailContacto,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ContactScreen())),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messageCircle,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Enviar mensaje',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // ── HERO HEADER ──────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isAuth, String nombre, String email,
      String iniciales, String? fotoUrl, AuthProvider auth) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.pierVerdeOscuro,
              child: const Icon(LucideIcons.croissant,
                  color: Colors.white54, size: 60),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20, right: 20, bottom: 20,
            ),
            child: isAuth
                ? _heroAuthContent(
                    nombre, email, iniciales, fotoUrl, auth)
                : _heroGuestContent(),
          ),
        ],
      ),
    );
  }

  Widget _heroGuestContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('¡Bienvenido!',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Playfair Display')),
        const SizedBox(height: 4),
        Text(
            'Ingresa a tu cuenta para ver tus pedidos, favoritos y más.',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.login),
            icon: const Icon(LucideIcons.logIn,
                color: Colors.white, size: 18),
            label: const Text('Iniciar Sesión',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroAuthContent(String nombre, String email, String iniciales,
      String? fotoUrl, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF5E6D3),
              shape: BoxShape.circle,
            ),
            child: fotoUrl != null && fotoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      fotoUrl,
                      width: 52, height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                            iniciales.isNotEmpty ? iniciales : 'U',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pierDoradoOscuro)),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                        iniciales.isNotEmpty ? iniciales : 'U',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pierDoradoOscuro)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre.isNotEmpty ? nombre : 'Usuario',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                Text(email,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileScreen())),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(LucideIcons.chevronRight,
                  color: Colors.white, size: 22),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _statCard(_loadingStats ? '—' : '$_totalPedidos',   'Pedidos'),
        const SizedBox(width: 10),
        _statCard(_loadingStats ? '—' : '$_totalFavoritos', 'Favoritos'),
        const SizedBox(width: 10),
        _statCard(_loadingStats ? '—' : '$_totalResenas',   'Reseñas'),
      ]),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          _loadingStats
              ? SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.pierVerde))
              : Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildBadgeCard(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.pierVerde.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.pierVerde, size: 22),
        ),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(sub,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool last = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: last
            ? const BorderRadius.vertical(bottom: Radius.circular(18))
            : BorderRadius.zero,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.textSecondary, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppColors.textSecondary.withValues(alpha: 0.2)),
    );
  }

  Widget _footerIcon(IconData icon) =>
      Icon(icon, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 22);
}