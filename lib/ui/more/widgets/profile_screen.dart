// lib/ui/more/widgets/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/favorites/widgets/favorites_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/orders_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/edit_profile_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _favoritosRepo = FavoritosRepository();
  final _pedidosRepo = PedidosRepository();

  List<Product> _favoritos = [];
  List<Map<String, dynamic>> _pedidos = [];
  bool _loadingFavoritos = true;
  bool _loadingPedidos = true;
  String? _reordenandoId; // id del pedido que se está reordenando

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ ProfileScreen');
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // ── Favoritos ──────────────────────────────────────────────────
    final favResult = await _favoritosRepo.listar();
    if (mounted) {
      if (favResult['success'] == true) {
        final data = favResult['favoritos'] ?? favResult['data'] ?? [];
        setState(() {
          _favoritos = (data as List).map((json) {
            final map = Map<String, dynamic>.from(json as Map<String, dynamic>);
            map['activo'] = true;
            return Product.fromJson(map);
          }).toList();
          _loadingFavoritos = false;
        });
        PierLog.info('✅ Favoritos: ${_favoritos.length}');
      } else {
        PierLog.error('Error favoritos: ${favResult['message']}');
        setState(() => _loadingFavoritos = false);
      }
    }

    // ── Pedidos ────────────────────────────────────────────────────
    final pedResult = await _pedidosRepo.misPedidos();
    if (mounted) {
      if (pedResult['success'] == true) {
        setState(() {
          _pedidos = List<Map<String, dynamic>>.from(
              pedResult['pedidos'] ?? []);
          _loadingPedidos = false;
        });
        PierLog.info('✅ Pedidos: ${_pedidos.length}');
      } else {
        PierLog.error('Error pedidos: ${pedResult['message']}');
        setState(() => _loadingPedidos = false);
      }
    }
  }

  // Vuelve a agregar los productos de un pedido al carrito y lleva al carrito.
  // mis-pedidos no trae producto_id, así que pedimos el detalle /pedidos/:id.
  Future<void> _reordenar(String pedidoId) async {
    if (pedidoId.isEmpty || _reordenandoId != null) return;
    setState(() => _reordenandoId = pedidoId);

    final result = await _pedidosRepo.detalle(pedidoId);
    if (!mounted) return;

    final items = result['success'] == true
        ? List<Map<String, dynamic>>.from(result['items'] ?? [])
        : <Map<String, dynamic>>[];

    if (items.isEmpty) {
      setState(() => _reordenandoId = null);
      _snack('No se pudieron cargar los productos del pedido');
      return;
    }

    final cart = context.read<CartProvider>();
    var agregados = 0;
    for (final it in items) {
      final pid = it['producto_id']?.toString() ?? '';
      if (pid.isEmpty) continue;
      final nombre = (it['nombre_producto'] ?? it['nombre'] ?? '').toString();
      final tamano = it['tamano']?.toString() ?? 'chico';
      final precio =
          double.tryParse(it['precio_unitario']?.toString() ?? '0') ?? 0.0;
      final cantidad = int.tryParse(it['cantidad']?.toString() ?? '1') ?? 1;
      await cart.addItem(
        Product(
          id: pid,
          nombre: nombre,
          precio: precio,
          imagenUrl: '',
          descripcion: '',
          categoria: '',
        ),
        cantidad,
        tamano,
        precio,
      );
      agregados++;
    }

    if (!mounted) return;
    setState(() => _reordenandoId = null);

    if (agregados == 0) {
      _snack('No se pudieron agregar los productos');
      return;
    }

    _snack('Productos agregados al carrito', success: true);
    // Cierra el perfil y cambia a la pestaña Carrito (índice 2).
    Navigator.of(context).pop();
    context.read<NavigationProvider>().setSelectedIndex(2);
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
      const months = ['Ene','Feb','Mar','Abr','May','Jun',
                      'Jul','Ago','Sep','Oct','Nov','Dic'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final nombre = user?['nombre']?.toString() ?? '';
    final apellido = user?['apellido']?.toString() ?? '';
    final apellidoInicial =
        apellido.isNotEmpty ? apellido[0].toUpperCase() : '';
    final iniciales =
        '${nombre.isNotEmpty ? nombre[0].toUpperCase() : ''}$apellidoInicial';
    final fotoUrl = user?['avatar_url']?.toString() ??
        user?['foto_url']?.toString();
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
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    // Avatar circular — toca para editar perfil
                    GestureDetector(
                      onTap: () {
                        PierLog.nav('→ EditProfileScreen');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const EditProfileScreen()),
                        ).then((_) => setState(() {}));
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.pierVerde,
                              shape: BoxShape.circle,
                            ),
                            child: fotoUrl != null && fotoUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      fotoUrl,
                                      width: 52, height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, e, __) =>
                                          _buildAvatarIniciales(iniciales),
                                    ),
                                  )
                                : _buildAvatarIniciales(iniciales),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.pierVerde,
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

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

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
                      onTap: () {
                        PierLog.nav('→ FavoritesScreen');
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const FavoritesScreen()));
                      },
                      child: Text('Ver todo',
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
                  ? Center(
                      child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde),
                    ))
                  : _favoritos.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          child: Text('Sin favoritos aún',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            // ✅ FIX: (_, i) en lugar de (_, _)
                            separatorBuilder: (_, i) =>
                                const SizedBox(width: 12),
                            itemCount:
                                _favoritos.take(5).length,
                            itemBuilder: (context, i) {
                              final p = _favoritos[i];
                              return GestureDetector(
                                onTap: () {
                                  PierLog.nav(
                                      '→ ProductDetailScreen: ${p.nombre}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailScreen(
                                                product: p)),
                                  );
                                },
                                child: SizedBox(
                                  width: 120,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        // ✅ FIX: (_, e, __) en lugar de (_, _, _)
                                        child: Image.network(
                                          p.imagenUrl,
                                          width: 120,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, e, __) =>
                                              Container(
                                            width: 120,
                                            height: 100,
                                            color: AppColors.pierArena,
                                            child: Icon(
                                                LucideIcons.cake,
                                                color:
                                                    AppColors.pierVerde),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(p.nombre,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 13,
                                              color:
                                                  AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      Row(children: [
                                        Text(
                                            '\$${p.precio.toStringAsFixed(0)}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.pierVerde,
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
                      onTap: () {
                        PierLog.nav('→ OrdersScreen');
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const OrdersScreen()));
                      },
                      child: Icon(LucideIcons.history,
                          color: AppColors.textSecondary, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            _loadingPedidos
                ? SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: AppColors.pierVerde),
                  )))
                : _pedidos.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          child: Text('Sin pedidos aún',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final p = _pedidos[i];
                              final pedidoId = p['id']?.toString() ?? '';
                              final numero =
                                  p['numero']?.toString() ??
                                      '#${p['id']}';
                              final estado =
                                  p['estado']?.toString() ??
                                      'pendiente';
                              final items =
                                  List<Map<String, dynamic>>.from(
                                      p['items'] ?? []);
                              final total = double.tryParse(
                                      p['total']?.toString() ??
                                          '0') ??
                                  0.0;
                              final resumen = items.isEmpty
                                  ? 'Sin productos'
                                  : items.length == 1
                                      ? '1x ${items.first['nombre_producto'] ?? items.first['nombre'] ?? ''}'
                                      : '${items.first['cantidad']}x ${(items.first['nombre_producto'] ?? items.first['nombre'] ?? '').toString().split(' ').take(2).join(' ')}..., '
                                          '${items.length > 1 ? '${items.length - 1}x más' : ''}';
                              final imagen = items.isNotEmpty
                                  ? items.first['imagen_url']
                                          ?.toString() ??
                                      ''
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 12),
                                child: _buildPedidoCard(
                                  numero: numero,
                                  fecha: _formatFechaPedido(
                                      p['created_at']),
                                  estado: estado,
                                  resumen: resumen,
                                  total: total,
                                  imagenUrl: imagen,
                                  reordenando: _reordenandoId == pedidoId,
                                  onReordenar: () => _reordenar(pedidoId),
                                ),
                              );
                            },
                            childCount: _pedidos.take(5).length,
                          ),
                        ),
                      ),

          ],
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
    required bool reordenando,
    required VoidCallback onReordenar,
  }) {
    Color estadoColor;
    switch (estado) {
      case 'completado': estadoColor = AppColors.estadoCompletado; break;
      case 'en_preparacion':
      case 'preparando': estadoColor = AppColors.estadoPreparacion; break;
      case 'listo': estadoColor = AppColors.estadoListo; break;
      case 'cancelado': estadoColor = AppColors.estadoCancelado; break;
      default: estadoColor = AppColors.estadoPendiente;
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(fecha,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ),
        Divider(
            height: 20,
            color: AppColors.textSecondary.withValues(alpha: 0.12)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imagenUrl.isNotEmpty
                  ? Image.network(imagenUrl,
                      width: 48, height: 48,
                      fit: BoxFit.cover,
                      // ✅ FIX: (_, e, __)
                      errorBuilder: (_, e, __) =>
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
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.pierVerde)),
                ],
              ),
            ),
            GestureDetector(
              onTap: reordenando ? null : onReordenar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    reordenando
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pierVerde),
                          )
                        : Icon(LucideIcons.rotateCcw,
                            size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(reordenando ? 'Agregando…' : 'Reordenar',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
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

  Widget _imagePlaceholder() => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.pierArena,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(LucideIcons.image,
            color: AppColors.textSecondary, size: 22),
      );

  Widget _buildAvatarIniciales(String iniciales) => Center(
        child: Text(iniciales,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      );
}