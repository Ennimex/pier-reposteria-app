import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Un solo cliente HTTP para toda la app (lo reciben todos los repositorios).
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
