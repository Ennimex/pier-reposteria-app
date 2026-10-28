import 'package:flutter/material.dart';
import 'package:pier_reposteria/app.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:provider/provider.dart';

// Sentry (#23) envuelve todo el arranque si el build trae SENTRY_DSN.
Future<void> main() => Monitoreo.arrancar(_arrancarApp);

// La primera pantalla se dibuja sin esperar al servidor (#198). Android no
// muestra la ventana hasta el primer cuadro de Flutter: si el arranque espera
// una respuesta (con Render dormido tarda más de 10 s) y el cliente toca la
// pantalla, Android la marca como congelada a los 5 s. La llave pública de
// Stripe no se precarga: el checkout la recibe en cada intento de pago
// (POST /pagos/crear-intent) y PasarelaStripe la aplica antes de abrir la
// hoja de pago.
Future<void> _arrancarApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ApiService es un Singleton: ApiService() devuelve siempre la misma
  // instancia, el único cliente HTTP de la app, y dependencias() se la pasa a
  // los 17 repositorios.
  final api = ApiService();

  runApp(
    MultiProvider(
      providers: dependencias(api),
      child: const MyApp(),
    ),
  );
}
