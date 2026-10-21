// lib/ui/feed/widgets/novedades_inicio.dart
//
// Las publicaciones en el Inicio del cliente (#175): justo después del
// carrusel y las categorías, las 3 más recientes con «Ver todo» hacia
// Novedades, que tiene el resto con sus promociones y sugerencias. Quien no
// inició sesión no puede verlas (el backend las niega): en su lugar va la
// invitación a entrar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/feed_sliver.dart';
import 'package:pier_reposteria/ui/feed/widgets/novedades_screen.dart';

class NovedadesInicio extends StatelessWidget {
  const NovedadesInicio({required this.feed, super.key});

  /// El del Inicio; Novedades usa el mismo.
  final FeedViewModel feed;

  void _verTodo(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => NovedadesScreen(viewModel: feed)),
  ).ignore();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: feed,
    builder: (context, _) {
      final recientes = feed.recientes;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloNovedades(
            alVerTodo: recientes.isEmpty ? null : () => _verTodo(context),
          ),
          if (feed.sinPublicaciones)
            const AvisoFeed.sinPublicaciones()
          else if (!feed.iniciado && feed.error != null)
            AvisoFeed.errorAlCargar(feed)
          else if (recientes.isEmpty && feed.cargando)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.pierVerde),
              ),
            ),
          for (final p in recientes) PublicacionDelFeed(p, feed: feed),
        ],
      );
    },
  );
}

/// Para quien no inició sesión: las publicaciones son de los clientes.
class InvitacionNovedades extends StatelessWidget {
  const InvitacionNovedades({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.pierDorado.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        Icon(LucideIcons.sparkles, size: 32, color: AppColors.pierVerde),
        const SizedBox(height: 8),
        const Text(
          'Lo nuevo de Pier',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Inicia sesión para ver las publicaciones de la pastelería: '
          'pasteles recién salidos del horno, novedades y promociones.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          style: FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
          child: const Text('Iniciar sesión'),
        ),
      ],
    ),
  );
}
