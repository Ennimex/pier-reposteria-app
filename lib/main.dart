import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/order_provider.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar publishable key del backend para no hardcodearla
  try {
    final result = await PagosRepository().config();
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
        ChangeNotifierProvider(create: (_) => EntregasProvider()),
        ChangeNotifierProvider(create: (_) => TemaProvider()),
      ],
      child: const MyApp(),
    ),
  );
}