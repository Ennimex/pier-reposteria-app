// lib/ui/main/widgets/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/auth/widgets/login_screen.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/animated_indexed_stack.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';
import 'package:pier_reposteria/ui/more/widgets/more_screen.dart';
import 'package:pier_reposteria/ui/orders/widgets/orders_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

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

  // Un HeroController por Navigator de pestaña: el Navigator raíz pone
  // HeroControllerScope.none a sus descendientes, así que sin esto ningún
  // Hero de las pestañas vuela. No se pueden compartir entre Navigators y
  // viven aquí (si build los recreara, un vuelo a medias se rompería).
  final List<HeroController> _heroes = List<HeroController>.generate(
    5,
    (_) => MaterialApp.createMaterialHeroController(),
  );

  @override
  void dispose() {
    for (final heroe in _heroes) {
      heroe.dispose();
    }
    super.dispose();
  }

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
    } on Object catch (_) {}
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
            await SystemNavigator.pop();
          }
        }
      },
      // Ámbito del vuelo al carrito: las pantallas de las pestañas lanzan la
      // miniatura y el ícono del carrito de la barra (DestinoVuelo) la recibe.
      child: VueloAlCarrito(
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
                heroController: _heroes[0],
                child: const HomeScreen(),
              ),
              // Tab 1 — Catálogo
              _NestedNavigator(
                navigatorKey: _navigatorKeys[1],
                heroController: _heroes[1],
                child: const ProductsScreen(initialCategory: 'Todos'),
              ),
              // Tab 2 — Carrito
              _NestedNavigator(
                navigatorKey: _navigatorKeys[2],
                heroController: _heroes[2],
                child: const CartScreen(),
              ),
              // Tab 3 — Pedidos (auth-aware, recrea el navigator al cambiar
              // auth). Las dos ramas comparten el GlobalKey del Navigator, así
              // que también comparten su HeroController.
              if (isAuthenticated)
                _NestedNavigator(
                  key: const ValueKey('pedidos_auth'),
                  navigatorKey: _navigatorKeys[3],
                  heroController: _heroes[3],
                  child: const OrdersScreen(),
                )
              else
                _NestedNavigator(
                  key: const ValueKey('pedidos_guest'),
                  navigatorKey: _navigatorKeys[3],
                  heroController: _heroes[3],
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
                heroController: _heroes[4],
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
            // IconoPestana en las dos ranuras (mismo estado): al elegir la
            // pestaña crece una píldora suave con un pop y al dejarla se
            // encoge y se apaga.
            items: const [
              BottomNavigationBarItem(
                icon: IconoPestana(LucideIcons.house, activo: false),
                activeIcon: IconoPestana(LucideIcons.house),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: IconoPestana(LucideIcons.store, activo: false),
                activeIcon: IconoPestana(LucideIcons.store),
                label: 'Catálogo',
              ),
              BottomNavigationBarItem(
                icon: _IconoCarrito(activo: false),
                activeIcon: _IconoCarrito(activo: true),
                label: 'Carrito',
              ),
              BottomNavigationBarItem(
                icon: IconoPestana(LucideIcons.receiptText, activo: false),
                activeIcon: IconoPestana(LucideIcons.receiptText),
                label: 'Pedidos',
              ),
              BottomNavigationBarItem(
                icon: IconoPestana(LucideIcons.menu, activo: false),
                activeIcon: IconoPestana(LucideIcons.menu),
                label: 'Más',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono del carrito en la barra: es el destino del vuelo al carrito y
/// lleva la insignia de cantidad, también cuando la pestaña está activa.
/// Las dos ranuras de la barra lo construyen igual, así que el destino y la
/// insignia conservan su estado al cambiar de pestaña.
class _IconoCarrito extends StatelessWidget {
  const _IconoCarrito({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return DestinoVuelo(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconoPestana(LucideIcons.shoppingCart, activo: activo),
          Positioned(
            right: -5,
            top: -5,
            // Solo la insignia escucha al carrito: la barra no se reconstruye.
            child: Consumer<CartProvider>(
              builder: (context, cart, _) =>
                  InsigniaCarrito(cantidad: cart.totalQuantity),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget que encapsula cada Navigator anidado
class _NestedNavigator extends StatelessWidget {
  const _NestedNavigator({
    required this.navigatorKey,
    required this.heroController,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final HeroController heroController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope(
      controller: heroController,
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => child),
      ),
    );
  }
}

// Vista para tabs que requieren login
class _LoginRequiredView extends StatelessWidget {
  const _LoginRequiredView({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  // La cascada espera AppMovimiento.trasPestana: empieza cuando la pestaña
  // ya está apareciendo. Como la pestaña oculta tiene sus tickers pausados,
  // se ve la primera vez que se abre (no al arrancar la app, fuera de
  // pantalla).
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
                EntradaSuave(
                  retraso: AppMovimiento.trasPestana,
                  escalaInicial: 0.9,
                  child: Container(
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
                ),
                const SizedBox(height: 24),
                EntradaSuave(
                  orden: 1,
                  retraso: AppMovimiento.trasPestana,
                  child: Text(title,
                      style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
                EntradaSuave(
                  orden: 2,
                  retraso: AppMovimiento.trasPestana,
                  child: Text(message,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.5),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 32),
                EntradaSuave(
                  orden: 3,
                  retraso: AppMovimiento.trasPestana,
                  child: SizedBox(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
