// lib/routing/app_routes.dart
//
// Los builders leen `extra` tal como lo manda quien navega (el mismo parseo
// de siempre): si faltara, el cast falla igual que antes, así que se dejan
// los casts directos en lugar de agregar `!`.
// ignore_for_file: cast_nullable_to_non_nullable
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/auth/widgets/forgot_password_screen.dart';
// Auth
import 'package:pier_pasteleria/ui/auth/widgets/login_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/register_screen.dart';
import 'package:pier_pasteleria/ui/auth/widgets/verify_email_screen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/rutas.dart';
import 'package:pier_pasteleria/ui/favorites/widgets/favorites_screen.dart';
// Shell cliente (BottomNavBar)
import 'package:pier_pasteleria/ui/main/widgets/main_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/edit_profile_screen.dart';
import 'package:pier_pasteleria/ui/more/widgets/profile_screen.dart';
import 'package:pier_pasteleria/ui/notifications/widgets/notifications_screen.dart';
import 'package:pier_pasteleria/ui/orders/widgets/order_detail_screen.dart';
// Cliente - push screens
import 'package:pier_pasteleria/ui/products/widgets/product_detail_screen.dart';
// Públicas
import 'package:pier_pasteleria/ui/public/widgets/about_us_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/faq_screen.dart';
import 'package:pier_pasteleria/ui/public/widgets/legal_screen.dart';
import 'package:pier_pasteleria/ui/refunds/widgets/refunds_screen.dart';
// Shell repartidor
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_main_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_pasteleria/ui/reviews/widgets/product_reviews_screen.dart';
// Roles internos (empleado / gerencia / dirección) → panel web
import 'package:pier_pasteleria/ui/roles/widgets/panel_web_screen.dart';
// Splash
import 'package:pier_pasteleria/ui/splash/widgets/splash_screen.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

class AppRoutes {
  static const String splash              = '/splash';
  static const String login               = '/login';
  static const String registro            = '/registro';
  static const String recuperarContrasena = '/recuperar-contrasena';
  static const String verificarEmail      = '/verificar-email';
  static const String main                = '/main';
  static const String repartidor          = '/repartidor';
  static const String panelWeb            = '/panel-web';
  static const String nosotros            = '/nosotros';
  static const String contacto            = '/contacto';
  static const String faq                 = '/faq';
  static const String legales             = '/legales';
  static const String productoDetalle     = '/producto/:id';
  static const String checkout            = '/cliente/checkout';
  static const String orderSuccess        = '/cliente/order-success';
  static const String orderDetail         = '/cliente/pedido/:id';
  static const String favoritos           = '/cliente/favoritos';
  static const String notificaciones      = '/cliente/notificaciones';
  static const String reembolsos          = '/cliente/reembolsos';
  static const String crearResena         = '/cliente/resena';
  static const String opiniones           = '/cliente/opiniones';
  static const String clienteContacto     = '/cliente/contacto';
  static const String perfil              = '/cliente/perfil';
  static const String editarPerfil        = '/cliente/perfil/editar';

  /// Ruta de inicio según el rol del usuario autenticado.
  /// Los roles internos (empleado/gerencia/dirección) no operan en la app:
  /// se les manda al aviso de panel web. El resto es cliente.
  static String homeForRole(String? rol) {
    if (rol == 'repartidor') return repartidor;
    if (rol == 'empleado' || rol == 'gerencia' || rol == 'direccion_general') {
      return panelWeb;
    }
    return main;
  }

  /// Página raíz de Pier para una ruta (paginaRaiz): fondo opaco y
  /// revelado en vez del deslizamiento sobre un lienzo vacío. El builder
  /// corre dentro de la ruta, igual que con `builder:`.
  static GoRouterPageBuilder _raiz(GoRouterWidgetBuilder constructor) =>
      (_, state) => paginaRaiz(
            state,
            Builder(builder: (context) => constructor(context, state)),
          );

  static GoRouter router(
    BuildContext context, {
    String initialLocation = splash,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuth = authProvider.isAuthenticated;
        final loc = state.matchedLocation;

        PierLog.nav('redirect loc=$loc isAuth=$isAuth');

        if (loc == splash) return null;

        final protectedRoutes = [
          checkout, orderSuccess, favoritos, notificaciones,
          reembolsos, perfil, editarPerfil, clienteContacto,
          crearResena, opiniones,
        ];

        final isProtected = protectedRoutes.contains(loc) ||
            loc.startsWith('/cliente/pedido') ||
            loc == repartidor ||
            loc == panelWeb;

        if (isProtected && !isAuth) return login;

        // El repartidor tiene su propio shell: si cae en el shell de cliente
        // (p. ej. desde el splash), lo mandamos a su panel de entregas.
        if (isAuth && authProvider.isRepartidor && loc == main) {
          return repartidor;
        }

        // Los roles internos no tienen vistas en la app: si aterrizan en el
        // shell de cliente, se les muestra el aviso de panel web.
        if (isAuth && authProvider.isRolInterno && loc == main) {
          return panelWeb;
        }

        // FIX: verificarEmail removido de esta lista para permitir que
        // un usuario recién registrado llegue a verificar su email
        // aunque el backend haya devuelto un token anticipado.
        if ([login, registro].contains(loc) && isAuth) {
          return homeForRole(authProvider.rol);
        }

        return null;
      },
      routes: [
        GoRoute(path: splash, pageBuilder: _raiz((c, s) => const SplashScreen())),

        GoRoute(path: login,               pageBuilder: _raiz((c, s) => const LoginScreen())),
        GoRoute(path: registro,            pageBuilder: _raiz((c, s) => const RegisterScreen())),
        GoRoute(path: recuperarContrasena, pageBuilder: _raiz((c, s) => const ForgotPasswordScreen())),

        GoRoute(
          path: verificarEmail,
          pageBuilder: _raiz((c, s) {
            final args = s.extra as Map<String, dynamic>;
            return VerifyEmailScreen(email: args['email'] as String);
          }),
        ),

        GoRoute(path: main,        pageBuilder: _raiz((c, s) => const MainScreen())),
        GoRoute(path: repartidor,  pageBuilder: _raiz((c, s) => const RepartidorMainScreen())),
        GoRoute(path: panelWeb,    pageBuilder: _raiz((c, s) => const PanelWebScreen())),
        GoRoute(path: nosotros, pageBuilder: _raiz((c, s) => const AboutUsScreen())),
        GoRoute(path: contacto, pageBuilder: _raiz((c, s) => const ContactScreen())),
        GoRoute(path: faq,      pageBuilder: _raiz((c, s) => const FAQScreen())),
        GoRoute(path: legales,  pageBuilder: _raiz((c, s) => const LegalScreen())),

        GoRoute(
          path: '/producto/:id',
          pageBuilder: _raiz((c, s) => ProductDetailScreen(product: s.extra as Product)),
        ),

        GoRoute(path: checkout, pageBuilder: _raiz((c, s) => const CheckoutScreen())),

        GoRoute(
          path: orderSuccess,
          pageBuilder: _raiz((c, s) {
            final args = s.extra as Map<String, dynamic>;
            return OrderSuccessScreen(
              orderId:    args['orderId']    as String,
              pickupDate: args['pickupDate'] as String,
              pickupTime: args['pickupTime'] as String,
              total:      args['total']      as double,
            );
          }),
        ),

        GoRoute(
          path: '/cliente/pedido/:id',
          pageBuilder: _raiz((c, s) => OrderDetailScreen(order: s.extra as Order)),
        ),

        GoRoute(path: favoritos,      pageBuilder: _raiz((c, s) => const FavoritesScreen())),
        GoRoute(path: notificaciones, pageBuilder: _raiz((c, s) => const NotificationsScreen())),
        GoRoute(path: reembolsos,     pageBuilder: _raiz((c, s) => const RefundsScreen())),

        GoRoute(
          path: crearResena,
          pageBuilder: _raiz((c, s) =>
              CreateReviewScreen(product: s.extra as Product)),
        ),

        GoRoute(
          path: opiniones,
          pageBuilder: _raiz((c, s) =>
              ProductReviewsScreen(product: s.extra as Product)),
        ),

        GoRoute(path: clienteContacto, pageBuilder: _raiz((c, s) => const ContactScreen())),
        GoRoute(path: perfil,          pageBuilder: _raiz((c, s) => const ProfileScreen())),
        GoRoute(path: editarPerfil,    pageBuilder: _raiz((c, s) => const EditProfileScreen())),
      ],
    );
  }
}
