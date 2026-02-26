import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/providers/cart_provider.dart';

// Importamos todas las pantallas del cliente
import 'home/home_screen.dart';
import 'products/products_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart'; // Asegúrate que tu archivo se llame así
import 'profile/profile_screen.dart'; // Asegúrate que tu archivo se llame así

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Lista de pantallas según el orden de la documentación (5 Tabs)
  final List<Widget> _screens = [
    const HomeScreen(),                                  // Tab 1: Inicio
    const ProductsScreen(initialCategory: 'Todos'),      // Tab 2: Catálogo
    const CartScreen(),                                  // Tab 3: Carrito
    const OrdersScreen(),                                // Tab 4: Pedidos (Antes OrdersListScreen)
    const ProfileScreen(),                               // Tab 5: Perfil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.pierVerde,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Necesario para 4+ items
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          // 1. Inicio
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          
          // 2. Catálogo
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),

          // 3. Carrito (Con Badge Rojo)
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    if (cart.totalQuantity > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${cart.totalQuantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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

          // 4. Pedidos
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),

          // 5. Perfil
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}