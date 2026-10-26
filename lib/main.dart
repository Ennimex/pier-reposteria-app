import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pier_reposteria/app.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/config/monitoreo.dart';
import 'package:pier_reposteria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:provider/provider.dart';

// Sentry (#23) envuelve todo el arranque si el build trae SENTRY_DSN.
Future<void> main() => Monitoreo.arrancar(_arrancarApp);

Future<void> _arrancarApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ApiService es un Singleton: ApiService() devuelve siempre la misma
  // instancia, el único cliente HTTP de la app, y dependencias() se la pasa a
  // los 17 repositorios.
  final api = ApiService();

  // Cargar publishable key del backend para no hardcodearla
  try {
    final result = await PagosRepositoryRemote(api: api).config();
    if (result['success'] == true) {
      Stripe.publishableKey = result['publishableKey'] as String;
      await Stripe.instance.applySettings();
    }
  } catch (_) {
    // Si falla la carga, Stripe no estará disponible — el checkout lo maneja
  }

  runApp(
    MultiProvider(
      providers: dependencias(api),
      child: const MyApp(),
    ),
  );
}
