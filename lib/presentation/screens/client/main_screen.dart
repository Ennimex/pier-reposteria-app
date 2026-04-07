// lib/presentation/screens/client/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/navigation_provider.dart';

import 'home/home_screen.dart';
import 'products/products_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart';
import 'more/more_screen.dart';
import '../auth/login_screen.dart';

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
    final navProvider = context.watch<NavigationProvider>();
    final selectedIndex = navProvider.selectedIndex;
    final isAuthenticated =
        context.watch<AuthProvider>().isAuthenticated;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
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
                      icon: Icons.receipt_long,
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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Catálogo',
            ),
            BottomNavigationBarItem(
              icon: Consumer<CartProvider>(
                builder: (context, cart, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    if (cart.totalQuantity > 0)
                      Positioned(
                        right: -5, top: -5,
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
                  ],
                ),
              ),
              activeIcon: const Icon(Icons.shopping_cart),
              label: 'Carrito',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              activeIcon: Icon(Icons.menu_open),
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
                    icon: const Icon(Icons.login_rounded,
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