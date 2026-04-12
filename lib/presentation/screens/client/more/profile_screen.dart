// lib/presentation/screens/client/more/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/models/product_model.dart';
import '../favorites/favorites_screen.dart';
import '../orders/orders_screen.dart';
import '../products/product_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();

  List<Product> _favoritos = [];
  List<Map<String, dynamic>> _pedidos = [];
  bool _loadingFavoritos = true;
  bool _loadingPedidos = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // Favoritos
    final favResult = await _api.getAuth(ApiConstants.favoritos);
    if (mounted && favResult['success'] == true) {
      final data = favResult['favoritos'] ?? favResult['data'] ?? [];
      setState(() {
        _favoritos = (data as List).map((json) {
          final map = Map<String, dynamic>.from(json as Map<String, dynamic>);
          map['activo'] = true;
          return Product.fromJson(map);
        }).toList();
        _loadingFavoritos = false;
      });
    } else if (mounted) {
      setState(() => _loadingFavoritos = false);
    }

    // Pedidos
    final pedResult = await _api.getAuth(ApiConstants.misPedidos);
    if (mounted && pedResult['success'] == true) {
      setState(() {
        _pedidos = List<Map<String, dynamic>>.from(
            pedResult['pedidos'] ?? []);
        _loadingPedidos = false;
      });
    } else if (mounted) {
      setState(() => _loadingPedidos = false);
    }
  }

  void _showLogoutDialog(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text(
            '¿Estás seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // cierra el diálogo
              Navigator.of(context).pop();       // cierra ProfileScreen (vuelve al tab)
              await auth.logout();               // GoRouter redirige al login
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

  String _formatFechaPedido(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return 'Hoy, $h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
      }
      final months = ['Ene','Feb','Mar','Abr','May','Jun',
                      'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final nombre = user?['nombre']?.toString() ?? '';
    final apellido = user?['apellido']?.toString() ?? '';
    final apellidoInicial =
        apellido.isNotEmpty ? apellido[0].toUpperCase() : '';
    final iniciales =
        '${nombre.isNotEmpty ? nombre[0].toUpperCase() : ''}$apellidoInicial';
    final fotoUrl = user?['foto_url']?.toString();
    final saludo =
        '$nombre ${apellido.isNotEmpty ? '${apellido[0]}.' : ''}'.trim();

    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── HEADER ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mi Perfil',
                              style: TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Hola, $saludo',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    // Avatar circular verde
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      ).then((_) => setState(() {})),
                      child: Stack(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: const BoxDecoration(
                              color: AppColors.pierVerde,
                              shape: BoxShape.circle,
                            ),
                            child: fotoUrl != null && fotoUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      fotoUrl,
                                      width: 52, height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildAvatarIniciales(iniciales),
                                    ),
                                  )
                                : _buildAvatarIniciales(iniciales),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── MIS FAVORITOS ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mis Favoritos',
                        style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const FavoritesScreen())),
                      child: const Text('Ver todo',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.pierVerde,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _loadingFavoritos
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde),
                    ))
                  : _favoritos.isEmpty
                      ? Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Sin favoritos aún',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _favoritos.take(5).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final p = _favoritos[i];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(
                                              product: p)),
                                ),
                                child: SizedBox(
                                  width: 120,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.network(
                                          p.imagenUrl,
                                          width: 120, height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, _, _) => Container(
                                            width: 120, height: 100,
                                            color: AppColors.pierArena,
                                            child: const Icon(
                                                Icons.cake_outlined,
                                                color:
                                                    AppColors.pierVerde),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(p.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Row(children: [
                                        Text(
                                            '\$${p.precio.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.pierVerde,
                                                fontWeight:
                                                    FontWeight.w700)),
                                        const Spacer(),
                                        const Icon(
                                            Icons.favorite_rounded,
                                            color: Colors.red,
                                            size: 14),
                                      ]),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── HISTORIAL DE PEDIDOS ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Historial de Pedidos',
                        style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrdersScreen())),
                      child: Icon(Icons.history_rounded,
                          color: Colors.grey[500], size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            _loadingPedidos
                ? const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: AppColors.pierVerde),
                  )))
                : _pedidos.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Sin pedidos aún',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final p = _pedidos[i];
                              final numero =
                                  p['numero']?.toString() ?? '#${p['id']}';
                              final estado =
                                  p['estado']?.toString() ?? 'pendiente';
                              final items = List<Map<String, dynamic>>.from(
                                  p['items'] ?? []);
                              final total = double.tryParse(
                                      p['total']?.toString() ?? '0') ??
                                  0.0;
                              final resumen = items.isEmpty
                                  ? 'Sin productos'
                                  : items.length == 1
                                      ? '1x ${items.first['nombre_producto'] ?? items.first['nombre'] ?? ''}'
                                      : '${items.first['cantidad']}x ${(items.first['nombre_producto'] ?? items.first['nombre'] ?? '').toString().split(' ').take(2).join(' ')}..., ${items.length > 1 ? '${items.length - 1}x más' : ''}';
                              final imagen = items.isNotEmpty
                                  ? items.first['imagen_url']?.toString() ??
                                      ''
                                  : '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPedidoCard(
                                  numero: numero,
                                  fecha: _formatFechaPedido(p['created_at']),
                                  estado: estado,
                                  resumen: resumen,
                                  total: total,
                                  imagenUrl: imagen,
                                ),
                              );
                            },
                            childCount: _pedidos.take(5).length,
                          ),
                        ),
                      ),

            // ── CERRAR SESIÓN ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('¿Deseas salir?',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                            Text('Cerrar sesión de tu cuenta actual',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500])),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () =>
                              _showLogoutDialog(auth),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar Sesión',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
            Icon(icon, color: AppColors.pierVerde, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _buildPedidoCard({
    required String numero,
    required String fecha,
    required String estado,
    required String resumen,
    required double total,
    required String imagenUrl,
  }) {
    Color estadoColor;
    switch (estado) {
      case 'completado': estadoColor = Colors.grey; break;
      case 'en_preparacion':
      case 'preparando': estadoColor = Colors.blue; break;
      case 'listo': estadoColor = AppColors.pierVerde; break;
      case 'cancelado': estadoColor = Colors.red; break;
      default: estadoColor = Colors.orange;
    }

    return Container(
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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text(numero,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: estadoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(estado,
                  style: TextStyle(
                      fontSize: 11,
                      color: estadoColor,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(fecha,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        Divider(
            height: 20,
            color: Colors.grey.withValues(alpha: 0.12)),

        // Items + Reordenar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imagenUrl.isNotEmpty
                  ? Image.network(imagenUrl,
                      width: 48, height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resumen,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('\$${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.pierVerde)),
                ],
              ),
            ),
            // Botón Reordenar
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_rounded,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Reordenar',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppColors.pierArena,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined,
          color: Colors.grey, size: 22),
    );
  }

  Widget _buildAvatarIniciales(String iniciales) {
    return Center(
      child: Text(iniciales,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
    );
  }
}