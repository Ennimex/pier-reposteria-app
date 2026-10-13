// lib/ui/feed/widgets/tarjeta_publicacion.dart
//
// Tarjeta de una publicación del inicio (#132): la marca y cuándo se publicó,
// el texto («Ver más» si es largo), las fotos o videos (deslizables, con su
// proporción acotada), «Me encanta», «Comentar» y los comentarios más
// recientes (#133). Los videos muestran su portada; la reproducción llega en
// #134.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/publicacion.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Líneas visibles del texto antes de «Ver más».
const _lineasTexto = 5;

/// 'hace un momento', 'hace 5 min', 'hace 2 h', 'hace 3 días' o '12 oct'.
String haceCuanto(DateTime? cuando, DateTime ahora) {
  if (cuando == null) return '';
  final d = ahora.difference(cuando);
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  if (d.inDays < 7) {
    return d.inDays == 1 ? 'hace 1 día' : 'hace ${d.inDays} días';
  }
  final local = cuando.toLocal();
  return '${local.day} ${_mesesCortos[local.month - 1]}';
}

/// '0:12', '1:05'.
String duracionVideo(double segundos) {
  final s = segundos.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class TarjetaPublicacion extends StatelessWidget {
  const TarjetaPublicacion(
    this.publicacion, {
    required this.alMeEncanta,
    required this.alComentar,
    super.key,
  });

  final Publicacion publicacion;
  final VoidCallback alMeEncanta;

  /// Abre la hoja de comentarios.
  final VoidCallback alComentar;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(p),
          if (p.texto case final texto?) _TextoPublicacion(texto),
          if (p.medios.isNotEmpty) _Medios(p.medios),
          _Acciones(p, alMeEncanta: alMeEncanta, alComentar: alComentar),
          if (p.comentariosRecientes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in p.comentariosRecientes) ComentarioBreve(c),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.publicacion);

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) {
    final cuando = haceCuanto(publicacion.creada, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.pierVerde,
            child: const Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pier Repostería',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  publicacion.editada ? '$cuando · editada' : cuando,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextoPublicacion extends StatefulWidget {
  const _TextoPublicacion(this.texto);

  final String texto;

  @override
  State<_TextoPublicacion> createState() => _TextoPublicacionState();
}

class _TextoPublicacionState extends State<_TextoPublicacion> {
  bool _completo = false;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 15, height: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: LayoutBuilder(
        builder: (context, limites) {
          final medida = TextPainter(
            text: TextSpan(text: widget.texto, style: estilo),
            maxLines: _lineasTexto,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: limites.maxWidth);
          final largo = medida.didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.texto,
                style: estilo,
                maxLines: _completo ? null : _lineasTexto,
                overflow: _completo ? null : TextOverflow.ellipsis,
              ),
              if (largo)
                GestureDetector(
                  onTap: () => setState(() => _completo = !_completo),
                  child: Text(
                    _completo ? 'Ver menos' : 'Ver más',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Fotos y videos deslizables con la proporción del primero.
class _Medios extends StatefulWidget {
  const _Medios(this.medios);

  final List<MedioPublicacion> medios;

  @override
  State<_Medios> createState() => _MediosState();
}

class _MediosState extends State<_Medios> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    final medios = widget.medios;
    return AspectRatio(
      aspectRatio: medios.first.proporcion,
      child: Stack(
        children: [
          PageView(
            onPageChanged: (i) => setState(() => _actual = i),
            children: [for (final m in medios) _Medio(m)],
          ),
          if (medios.length > 1)
            Positioned(
              top: 10,
              right: 10,
              child: _Pastilla('${_actual + 1}/${medios.length}'),
            ),
        ],
      ),
    );
  }
}

class _Medio extends StatelessWidget {
  const _Medio(this.medio);

  final MedioPublicacion medio;

  @override
  Widget build(BuildContext context) {
    final imagen = medio.esVideo ? medio.portada : medio.url;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imagen == null)
          const ColoredBox(color: Colors.black87)
        else
          ImagenFeed(imagen),
        if (medio.esVideo) ...[
          const Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black54,
              child: Icon(LucideIcons.play, color: Colors.white, size: 28),
            ),
          ),
          if (medio.duracion case final segundos?)
            Positioned(
              bottom: 10,
              right: 10,
              child: _Pastilla(duracionVideo(segundos)),
            ),
        ],
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      texto,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// «Me encanta» con su contador, «Comentar» y «Ver los N comentarios».
class _Acciones extends StatelessWidget {
  const _Acciones(
    this.publicacion, {
    required this.alMeEncanta,
    required this.alComentar,
  });

  final Publicacion publicacion;
  final VoidCallback alMeEncanta;
  final VoidCallback alComentar;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    final comentarios = p.totalComentarios;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: p.meEncanta ? 'Quitar me encanta' : 'Me encanta',
            onPressed: alMeEncanta,
            icon: Icon(
              p.meEncanta ? Icons.favorite : Icons.favorite_border,
              color: p.meEncanta ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          Text('${p.corazones}'),
          IconButton(
            tooltip: 'Comentar',
            onPressed: alComentar,
            icon: const Icon(
              LucideIcons.messageCircle,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (comentarios > 0)
            TextButton(
              onPressed: alComentar,
              child: Text(
                comentarios == 1
                    ? 'Ver el comentario'
                    : 'Ver los $comentarios comentarios',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un comentario en una línea: autor y texto; la respuesta oficial resalta.
class ComentarioBreve extends StatelessWidget {
  const ComentarioBreve(this.comentario, {super.key, this.alBorrar});

  final ComentarioPublicacion comentario;

  /// Si se puede borrar (los propios), muestra «Eliminar comentario».
  final VoidCallback? alBorrar;

  @override
  Widget build(BuildContext context) {
    final c = comentario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                c.autorNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (c.esOficial)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Respuesta de Pier',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pierVerde,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(c.texto, style: const TextStyle(fontSize: 13)),
              ),
              if (alBorrar != null)
                IconButton(
                  tooltip: 'Eliminar comentario',
                  visualDensity: VisualDensity.compact,
                  onPressed: alBorrar,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Imagen de red con un recuadro gris si no carga.
class ImagenFeed extends StatelessWidget {
  const ImagenFeed(this.url, {super.key, this.ajuste = BoxFit.cover});

  final String url;
  final BoxFit ajuste;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: ajuste,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFE5E7EB),
      child: Center(
        child: Icon(LucideIcons.imageOff, color: AppColors.textSecondary),
      ),
    ),
  );
}
