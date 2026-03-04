import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/auth_provider.dart';

// Importamos pantallas
import 'home/home_screen.dart'; 
import 'products/products_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart'; 
import 'more/more_screen.dart'; // IMPORTACIÓN CORREGIDA
import '../auth/login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Verificamos si el usuario tiene sesión iniciada
    final isAuthenticated = Provider.of<AuthProvider>(context).isAuthenticated;

    // 2. Definimos qué mostrar en cada Tab dependiendo del Auth
    final List<Widget> screens = [
      const HomeScreen(),                             // Tab 0: Inicio (Para todos)
      const ProductsScreen(initialCategory: 'Todos'), // Tab 1: Catálogo (Para todos)
      const CartScreen(),                             // Tab 2: Carrito (Para todos)
      
      // Tab 3: Pedidos (Protegido - Requiere Login)
      isAuthenticated 
          ? const OrdersScreen() 
          : const _LoginRequiredView(
              title: 'Mis Pedidos',
              message: 'Inicia sesión para hacer seguimiento a tus compras y ver tu historial.',
              icon: Icons.receipt_long,
            ),
            
      // Tab 4: Más (Público - Su contenido cambia por dentro si hay login)
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.pierVerde,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), 
            activeIcon: Icon(Icons.home), 
            label: 'Inicio'
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined), 
            activeIcon: Icon(Icons.storefront), 
            label: 'Catálogo'
          ),
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Stack(
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
                            shape: BoxShape.circle
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16, 
                            minHeight: 16
                          ),
                          child: Text(
                            '${cart.totalQuantity}', 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 10, 
                              fontWeight: FontWeight.bold
                            ), 
                            textAlign: TextAlign.center
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            activeIcon: const Icon(Icons.shopping_cart),
            label: 'Carrito',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined), 
            activeIcon: Icon(Icons.receipt_long), 
            label: 'Pedidos'
          ),
          // CAMBIO APLICADO: Icono de hamburguesa y texto "Más"
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu), 
            activeIcon: Icon(Icons.menu_open), 
            label: 'Más'
          ),
        ],
      ),
    );
  }
}

// --- WIDGET PARA PESTAÑAS BLOQUEADAS (ESTILO MERCADO LIBRE) ---
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
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // Usando withValues como lo dicta el estándar actualizado
                  color: AppColors.pierVerde.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 80, color: AppColors.pierVerde),
              ),
              const SizedBox(height: 30),
              const Text(
                '¡Hola! Para ver esto debes iniciar sesión',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.textPrimary
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Lo llevamos a la pantalla de Login
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                  child: const Text(
                    'Iniciar Sesión', 
                    style: TextStyle(
                      fontSize: 16, 
                      color: Colors.white, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}