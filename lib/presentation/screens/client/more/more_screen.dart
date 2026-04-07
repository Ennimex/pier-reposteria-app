// lib/presentation/screens/client/more/more_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../routes/app_routes.dart';
import '../../public/about_us_screen.dart';
import '../../public/faq_screen.dart';
import '../../public/contact_screen.dart';
import '../../public/legal_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../refunds/refunds_screen.dart';
import '../reviews/my_reviews_screen.dart';
import '../more/edit_profile_screen.dart';
import '../more/profile_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final ApiService _api = ApiService();

  int _totalPedidos = 0;
  int _totalFavoritos = 0;
  int _totalResenas = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarStats();
    });
  }

  Future<void> _cargarStats() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      if (mounted) setState(() => _loadingStats = false);
      return;
    }

    final results = await Future.wait([
      _api.getAuth(ApiConstants.misPedidos),
      _api.getAuth('/favoritos/ids'),
      _api.getAuth(ApiConstants.misResenas),
    ]);

    if (!mounted) return;

    setState(() {
      _totalPedidos = results[0]['success'] == true
          ? ((results[0]['pedidos'] ?? []) as List).length
          : 0;
      _totalFavoritos = results[1]['success'] == true
          ? ((results[1]['ids'] ?? []) as List).length
          : 0;
      _totalResenas = results[2]['success'] == true
          ? ((results[2]['resenas'] ?? []) as List).length
          : 0;
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
        content: const Text('¿Estás seguro que deseas cerrar tu sesión?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              auth.logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, elevation: 0),
            child: const Text('Salir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isAuth = auth.isAuthenticated;
    final nombre = auth.currentUser?['nombre']?.toString() ?? '';
    final email = auth.currentUser?['email']?.toString() ?? '';
    final inicial =
        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── HERO HEADER ─────────────────────────────────────────
          _buildHeroHeader(isAuth, nombre, email, inicial, auth),
          const SizedBox(height: 20),

          // ── STATS (autenticado) o REWARDS BANNER (guest) ────────
          if (isAuth) _buildStatsRow() else _buildRewardsBanner(),
          const SizedBox(height: 24),

          // ── MI CUENTA ───────────────────────────────────────────
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
                    child: const Text('Acceso requerido',
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
                icon: Icons.notifications_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Notificaciones',
                onTap: () =>
                    _goProtected(const NotificationsScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.star_rounded,
                iconColor: AppColors.pierDorado,
                title: 'Mis Reseñas',
                onTap: () =>
                    _goProtected(const MyReviewsScreen()),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Mis Reembolsos',
                onTap: () => _goProtected(const RefundsScreen()),
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
                icon: Icons.menu_book_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Nuestra Historia',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutUsScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.help_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Preguntas Frecuentes',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FAQScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.chat_bubble_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Contacto',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContactScreen())),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.shield_rounded,
                iconColor: AppColors.pierVerde,
                title: 'Términos Legales y Privacidad',
                onTap: () => Navigator.push(
                    context,
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
                  Icons.cookie_outlined, 'Artesanal', 'Hecho a mano')),
              const SizedBox(width: 12),
              Expanded(child: _buildBadgeCard(
                  Icons.local_fire_department_outlined,
                  'Fresco',
                  'Horneado hoy')),
            ]),
          ),

          const SizedBox(height: 24),

          // ── CERRAR SESIÓN ────────────────────────────────────────
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
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 14),
                    const Text('Cerrar sesión',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.red)),
                  ]),
                ),
              ),
            ),

          const SizedBox(height: 28),

          // ── FOOTER ──────────────────────────────────────────────
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _footerIcon(Icons.help_outline_rounded),
                const SizedBox(width: 20),
                _footerIcon(Icons.privacy_tip_outlined),
                const SizedBox(width: 20),
                _footerIcon(Icons.info_outline_rounded),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Versión 1.0.0 • Pier Repostería',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Hecho con amor en la panadería',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── HERO HEADER ──────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isAuth, String nombre, String email,
      String inicial, AuthProvider auth) {
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
              child: const Icon(Icons.bakery_dining_outlined,
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
                ? _heroAuthContent(nombre, email, inicial, auth)
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
            icon: const Icon(Icons.login_rounded,
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

  Widget _heroAuthContent(
      String nombre, String email, String inicial, AuthProvider auth) {
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
            child: Center(
              child: Text(inicial,
                  style: const TextStyle(
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
              child: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ]),
      ],
    );
  }

  // ── REWARDS BANNER (solo guest) ──────────────────────────────────
  Widget _buildRewardsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.pierDorado.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Únete a Pier Rewards',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pierDoradoOscuro,
                        fontFamily: 'Playfair Display')),
                const SizedBox(height: 6),
                Text(
                    'Acumula puntos en cada compra y canjéalos por tus postres favoritos.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown[400],
                        height: 1.4)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Iniciar sesión',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.pierDorado.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.pierDorado, size: 28),
          ),
        ]),
      ),
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _statCard(_loadingStats ? '—' : '$_totalPedidos', 'Pedidos'),
        const SizedBox(width: 10),
        _statCard(
            _loadingStats ? '—' : '$_totalFavoritos', 'Favoritos'),
        const SizedBox(width: 10),
        _statCard(_loadingStats ? '—' : '$_totalResenas', 'Reseñas'),
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
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.pierVerde))
              : Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
            ? const BorderRadius.vertical(
                bottom: Radius.circular(18))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
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
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
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
          color: Colors.grey.withValues(alpha: 0.2)),
    );
  }

  Widget _footerIcon(IconData icon) {
    return Icon(icon, color: Colors.grey[400], size: 22);
  }
}