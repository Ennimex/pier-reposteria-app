// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/utils/logger.dart';
import '../data/providers/auth_provider.dart';
import '../data/models/product_model.dart';
import '../data/models/order_model.dart';

// Splash
import '../presentation/screens/splash/splash_screen.dart';

// Auth
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/auth/verify_email_screen.dart';

// Shell cliente (BottomNavBar)
import '../presentation/screens/client/main_screen.dart';

// Públicas
import '../presentation/screens/public/about_us_screen.dart';
import '../presentation/screens/public/contact_screen.dart';
import '../presentation/screens/public/faq_screen.dart';
import '../presentation/screens/public/legal_screen.dart';

// Cliente - push screens
import '../presentation/screens/client/products/product_detail_screen.dart';
import '../presentation/screens/client/checkout/checkout_screen.dart';
import '../presentation/screens/client/checkout/order_success_screen.dart';
import '../presentation/screens/client/orders/order_detail_screen.dart';
import '../presentation/screens/client/favorites/favorites_screen.dart';
import '../presentation/screens/client/notifications/notifications_screen.dart';
import '../presentation/screens/client/refunds/refunds_screen.dart';
import '../presentation/screens/client/reviews/create_review_screen.dart';
import '../presentation/screens/client/reviews/product_reviews_screen.dart';
import '../presentation/screens/client/more/profile_screen.dart';
import '../presentation/screens/client/more/edit_profile_screen.dart';

class AppRoutes {
  static const String splash              = '/splash';
  static const String login               = '/login';
  static const String registro            = '/registro';
  static const String recuperarContrasena = '/recuperar-contrasena';
  static const String verificarEmail      = '/verificar-email';
  static const String main                = '/main';
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

  static GoRouter router(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: splash,
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
            loc.startsWith('/cliente/pedido');

        if (isProtected && !isAuth) return login;

        // FIX: verificarEmail removido de esta lista para permitir que
        // un usuario recién registrado llegue a verificar su email
        // aunque el backend haya devuelto un token anticipado.
        if ([login, registro].contains(loc) && isAuth) {
          return main;
        }

        return null;
      },
      routes: [
        GoRoute(path: splash, builder: (c, s) => const SplashScreen()),

        GoRoute(path: login,               builder: (c, s) => const LoginScreen()),
        GoRoute(path: registro,            builder: (c, s) => const RegisterScreen()),
        GoRoute(path: recuperarContrasena, builder: (c, s) => ForgotPasswordScreen()),

        GoRoute(
          path: verificarEmail,
          builder: (c, s) {
            final args = s.extra as Map<String, dynamic>;
            return VerifyEmailScreen(email: args['email'] as String);
          },
        ),

        GoRoute(path: main,     builder: (c, s) => const MainScreen()),
        GoRoute(path: nosotros, builder: (c, s) => const AboutUsScreen()),
        GoRoute(path: contacto, builder: (c, s) => const ContactScreen()),
        GoRoute(path: faq,      builder: (c, s) => const FAQScreen()),
        GoRoute(path: legales,  builder: (c, s) => const LegalScreen()),

        GoRoute(
          path: '/producto/:id',
          builder: (c, s) => ProductDetailScreen(product: s.extra as Product),
        ),

        GoRoute(path: checkout, builder: (c, s) => const CheckoutScreen()),

        GoRoute(
          path: orderSuccess,
          builder: (c, s) {
            final args = s.extra as Map<String, dynamic>;
            return OrderSuccessScreen(
              orderId:    args['orderId']    as String,
              pickupDate: args['pickupDate'] as String,
              pickupTime: args['pickupTime'] as String,
              total:      args['total']      as double,
            );
          },
        ),

        GoRoute(
          path: '/cliente/pedido/:id',
          builder: (c, s) => OrderDetailScreen(order: s.extra as Order),
        ),

        GoRoute(path: favoritos,      builder: (c, s) => const FavoritesScreen()),
        GoRoute(path: notificaciones, builder: (c, s) => const NotificationsScreen()),
        GoRoute(path: reembolsos,     builder: (c, s) => const RefundsScreen()),

        GoRoute(
          path: crearResena,
          builder: (c, s) =>
              CreateReviewScreen(product: s.extra as Product),
        ),

        GoRoute(
          path: opiniones,
          builder: (c, s) =>
              ProductReviewsScreen(product: s.extra as Product),
        ),

        GoRoute(path: clienteContacto, builder: (c, s) => const ContactScreen()),
        GoRoute(path: perfil,          builder: (c, s) => const ProfileScreen()),
        GoRoute(path: editarPerfil,    builder: (c, s) => const EditProfileScreen()),
      ],
    );
  }
}