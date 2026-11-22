// lib/ui/feed/widgets/novedades_inicio.dart
//
// Las publicaciones en el Inicio del cliente (#175): justo después del
// carrusel y las categorías, las 3 más recientes con «Ver todo» hacia
// Novedades, que tiene el resto con sus promociones y sugerencias. Quien no
// inició sesión no puede verlas (el backend las niega): en su lugar va la
// invitación a entrar.
//
// Van en dos partes para que el Inicio no arme de golpe lo que no se ve
// (#341). NovedadesInicio es la caja con el título y la primera publicación,
// que es la que asoma al abrir la app. MasNovedadesInicio es el sliver con
// las demás: cada una aparta su lugar y se arma cuando el scroll la acerca.
// Mientras cargan, la caja aparta el alto de una publicación: sin eso, las
// secciones de abajo se armaban pegadas al título y las publicaciones, al
// llegar, las mandaban fuera de la pantalla.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/sliver_al_acercarse.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/feed_sliver.dart';
import 'package:pier_reposteria/ui/feed/widgets/novedades_screen.dart';

/// Alto que se aparta para una publicación que todavía no se ve: mientras
/// cargan todas, o las que esperan a que el scroll las acerque. Es menos de
/// lo que mide una con foto, pero alcanza para que lo de abajo quede lejos.
const double _altoDeUnaPublicacion = 480;

/// El título, el aviso que toque y la primera publicación.
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
      // Sin respuesta todavía: cargando, o a punto de pedirlas (el Inicio
      // las pide después de su primer cuadro).
      final esperando =
          recientes.isEmpty &&
          (feed.cargando || (!feed.iniciado && feed.error == null));
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
          else if (esperando)
            SizedBox(
              height: _altoDeUnaPublicacion,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.pierVerde),
                ),
              ),
            ),
          if (recientes.isNotEmpty)
            PublicacionDelFeed(recientes.first, feed: feed),
        ],
      );
    },
  );
}

/// Las publicaciones del Inicio después de la primera, como sliver: cada una
/// se arma cuando el scroll la acerca.
class MasNovedadesInicio extends StatelessWidget {
  const MasNovedadesInicio({required this.feed, super.key});

  final FeedViewModel feed;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: feed,
    builder: (context, _) => SliverMainAxisGroup(
      slivers: [
        for (final p in feed.recientes.skip(1))
          SliverAlAcercarse(
            key: ValueKey('novedad-${p.id}'),
            altoApartado: _altoDeUnaPublicacion,
            child: PublicacionDelFeed(p, feed: feed),
          ),
      ],
    ),
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
