import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'core/services/api_service.dart';
import 'data/providers/cart_provider.dart';
import 'data/providers/order_provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/product_provider.dart';
import 'data/providers/navigation_provider.dart';
import 'data/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar publishable key del backend para no hardcodearla
  try {
    final result = await ApiService().get('/pagos/config');
    if (result['success'] == true) {
      Stripe.publishableKey = result['publishableKey'] as String;
      await Stripe.instance.applySettings();
    }
  } catch (_) {
    // Si falla la carga, Stripe no estará disponible — el checkout lo maneja
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}