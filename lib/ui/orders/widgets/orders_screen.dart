// lib/ui/orders/widgets/orders_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/skeletons.dart';
import 'package:pier_pasteleria/ui/orders/view_model/orders_view_model.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const OrdersScreen({super.key, this.viewModel});

  final OrdersViewModel? viewModel;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  NavigationProvider? _nav;

  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final OrdersViewModel _vm =
      widget.viewModel ?? OrdersViewModel(repo: PedidosRepository());

  @override
  void initState() {
    super.initState();
    unawaited(_cargarPedidos());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar la lista cada vez que se entra a la pestaña Pedidos (index 3),
    // para que no quede con datos viejos como pasa con el resto de la app.
    final nav = context.read<NavigationProvider>();
    if (!identical(nav, _nav)) {
      _nav?.removeListener(_onNavChanged);
      _nav = nav;
      _nav!.addListener(_onNavChanged);
    }
  }

  void _onNavChanged() {
    if (mounted && _nav?.selectedIndex == 3) {
      unawaited(_cargarPedidos(silent: true));
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_onNavChanged);
    _tabController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _cargarPedidos({bool silent = false}) => _vm.cargar(
        conSesion: context.read<AuthProvider>().isAuthenticated,
        silenciosa: silent,
      );

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildPantalla(context),
    );
  }

  Widget _buildPantalla(BuildContext context) {
    final activos = _vm.activos;
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mis Pedidos',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  // Badge total activos
                  if (activos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${activos.length} activo${activos.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // ── TABS ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  indicator: BoxDecoration(
                    color: AppColors.pierVerde,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Activos'),
                    Tab(text: 'Historial'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: _vm.cargando
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, _) => const OrderSkeletonCard(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _cargarPedidos(silent: true),
                      color: AppColors.pierVerde,
                      child: TabBarView(
                        controller: _tabController,
                        children: context.watch<AuthProvider>().isAuthenticated
                            ? [
                                _buildOrdersList(
                                  activos,
                                  'No tienes pedidos activos',
                                  'Cuando realices un pedido\naparecerá aquí.',
                                  LucideIcons.receiptText,
                                ),
                                _buildOrdersList(
                                  _vm.finalizados,
                                  'Sin historial aún',
                                  'Tus pedidos completados\naparecerán aquí.',
                                  LucideIcons.history,
                                ),
                              ]
                            : [
                                _buildOrdersList(
                                  const [],
                                  'Inicia sesión',
                                  'Inicia sesión para ver\ntus pedidos.',
                                  LucideIcons.logIn,
                                  conLogin: true,
                                ),
                                _buildOrdersList(
                                  const [],
                                  'Inicia sesión',
                                  'Inicia sesión para ver\ntu historial.',
                                  LucideIcons.logIn,
                                  conLogin: true,
                                ),
                              ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders, String title,
      String subtitle, IconData icon, {bool conLogin = false}) {
    if (orders.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 46,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[500])),
            if (conLogin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen())),
                icon: const Icon(LucideIcons.logIn,
                    size: 18, color: Colors.white),
                label: const Text('Iniciar sesión',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _buildOrderCard(orders[i])
          .animate()
          .fadeIn(
            duration: 350.ms,
            delay: (50 * (i % 6)).ms,
            curve: Curves.easeOut,
          )
          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildOrderCard(Order order) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            // ── HEADER CARD ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.shoppingBag,
                        color: AppColors.pierVerde, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ← Corregido: usa order.numero
                        Text(order.numero,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                        Text(_formatDate(order.createdAt),
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  // Chip de estado
                  _buildStatusChip(order),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),

            // ── FOOTER CARD ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  // Items resumen
                  Expanded(
                    child: Text(
                      order.items.isEmpty
                          ? 'Sin productos'
                          : order.items.length == 1
                              ? order.items.first.nombre
                              : '${order.items.first.nombre} +${order.items.length - 1} más',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('\$${order.total.toStringAsFixed(0)} MXN',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.pierDoradoOscuro)),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.chevronRight,
                      color: Colors.grey, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Order order) {
    final status = order.status;
    Color color;
    String label;
    switch (status) {
      case OrderStatus.pending:
        color = AppColors.estadoPendiente;
        label = order.porConfirmar ? 'Por confirmar' : 'Pendiente';
      case OrderStatus.preparing:
        color = AppColors.estadoPreparacion;
        label = 'Preparando';
      case OrderStatus.ready:
        color = AppColors.estadoListo;
        label = 'Listo ✓';
      case OrderStatus.completed:
        color = AppColors.estadoCompletado;
        label = 'Completado';
      case OrderStatus.cancelled:
        color = AppColors.estadoCancelado;
        label = 'Cancelado';
      case OrderStatus.assigned:
        color = AppColors.estadoAsignada;
        label = 'Asignado';
      case OrderStatus.onTheWay:
        color = AppColors.estadoEnCamino;
        label = 'En camino';
      case OrderStatus.delivered:
        color = AppColors.estadoEntregada;
        label = 'Entregado';
      case OrderStatus.deliveryFailed:
        color = AppColors.estadoFallida;
        label = 'Entrega fallida';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Ene','Feb','Mar','Abr','May','Jun',
                    'Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
