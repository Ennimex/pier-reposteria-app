import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/tema_provider.dart';
import 'routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Crear el router solo una vez
    _router ??= AppRoutes.router(context);
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruye el ThemeData cuando cambia el tema de temporada; el router
    // se conserva, así el cambio no pierde la navegación.
    context.watch<TemaProvider>();
    return MaterialApp.router(
      title: 'Pier Repostería',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router!,
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