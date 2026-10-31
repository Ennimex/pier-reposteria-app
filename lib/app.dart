import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_theme.dart';
import 'package:pier_reposteria/ui/core/ui/aviso_sesion_expirada.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.initialLocation = AppRoutes.splash,
  });

  final String initialLocation;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Crear el router solo una vez
    _router ??= AppRoutes.router(
      context,
      initialLocation: widget.initialLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruye el ThemeData cuando cambia el tema de temporada; el router
    // se conserva, así el cambio no pierde la navegación.
    context.watch<TemaProvider>();
    return MaterialApp.router(
      title: 'Pier Repostería',
      theme: AppTheme.lightTheme,
      // El cambio de paleta de temporada se aplica en un solo cuadro: sin
      // esto el ThemeData se interpola 200 ms mientras los widgets que leen
      // AppColors cambian al instante (el color cambiaba en dos pasos).
      themeAnimationStyle: AnimationStyle.noAnimation,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // Avisa en cualquier pantalla si la sesión expiró (#218).
      builder: (context, child) =>
          AvisoSesionExpirada(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''),
      ],
    );
  }
}
