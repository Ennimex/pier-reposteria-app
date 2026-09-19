// lib/ui/main/widgets/main_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/animated_indexed_stack.dart';
import 'package:flutter/services.dart';

import 'package:pier_pasteleria/ui/home/widgets/home_screen.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/orders_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/more_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Navigators anidados para tabs 0-4
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _onItemTapped(int index) {
    final navProvider = context.read<NavigationProvider>();
    final current = navProvider.selectedIndex;
    if (current == index) {
      final nav = _navigatorKeys[index].currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((r) => r.isFirst);
      }
    } else {
      navProvider.setSelectedIndex(index);
    }
  }

  Future<bool> _onWillPop() async {
    final index = context.read<NavigationProvider>().selectedIndex;
    try {
      final nav = _navigatorKeys[index].currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return false;
      }
    } catch (_) {}
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final navProvider = context.watch<NavigationProvider>();
    final selectedIndex = navProvider.selectedIndex;
    final isAuthenticated =
        context.watch<AuthProvider>().isAuthenticated;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: AnimatedIndexedStack(
          index: selectedIndex,
          // Deslizar entre pestañas (fling); equivale a tocar la pestaña
          onSwipeToIndex: (i) =>
              context.read<NavigationProvider>().setSelectedIndex(i),
          children: [
            // Tab 0 — Inicio
            _NestedNavigator(
              navigatorKey: _navigatorKeys[0],
              child: const HomeScreen(),
            ),
            // Tab 1 — Catálogo
            _NestedNavigator(
              navigatorKey: _navigatorKeys[1],
              child: const ProductsScreen(initialCategory: 'Todos'),
            ),
            // Tab 2 — Carrito
            _NestedNavigator(
              navigatorKey: _navigatorKeys[2],
              child: const CartScreen(),
            ),
            // Tab 3 — Pedidos (auth-aware, recrea el navigator al cambiar auth)
            isAuthenticated
                ? _NestedNavigator(
                    key: const ValueKey('pedidos_auth'),
                    navigatorKey: _navigatorKeys[3],
                    child: const OrdersScreen(),
                  )
                : _NestedNavigator(
                    key: const ValueKey('pedidos_guest'),
                    navigatorKey: _navigatorKeys[3],
                    child: const _LoginRequiredView(
                      title: 'Mis Pedidos',
                      message:
                          'Inicia sesión para hacer seguimiento a tus compras y ver tu historial.',
                      icon: LucideIcons.receiptText,
                    ),
                  ),
            // Tab 4 — Más
            _NestedNavigator(
              navigatorKey: _navigatorKeys[4],
              child: const MoreScreen(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.pierVerde,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 10,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.house),
              activeIcon: Icon(LucideIcons.house),
              label: 'Inicio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.store),
              activeIcon: Icon(LucideIcons.store),
              label: 'Catálogo',
            ),
            BottomNavigationBarItem(
              icon: Consumer<CartProvider>(
                builder: (context, cart, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(LucideIcons.shoppingCart),
                    if (cart.totalQuantity > 0)
                      Positioned(
                        right: -5, top: -5,
                        // Rebote al cambiar la cantidad (la key reinicia el tween)
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(cart.totalQuantity),
                          tween: Tween(begin: 1.5, end: 1.0),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.elasticOut,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '${cart.totalQuantity}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              activeIcon: const Icon(LucideIcons.shoppingCart),
              label: 'Carrito',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.receiptText),
              activeIcon: Icon(LucideIcons.receiptText),
              label: 'Pedidos',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.menu),
              activeIcon: Icon(LucideIcons.menu),
              label: 'Más',
            ),
          ],
        ),
      ),
    );
  }
}

// Widget que encapsula cada Navigator anidado
class _NestedNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const _NestedNavigator({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => child),
    );
  }
}

// Vista para tabs que requieren login
class _LoginRequiredView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _LoginRequiredView({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                      color:
                          AppColors.pierVerde.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 24),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(message,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                    icon: const Icon(LucideIcons.logIn,
                        color: Colors.white, size: 18),
                    label: const Text('Iniciar Sesión',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}