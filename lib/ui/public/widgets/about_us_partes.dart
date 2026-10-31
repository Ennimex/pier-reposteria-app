// lib/ui/public/widgets/about_us_partes.dart
//
// Secciones de «Nosotros» que Dirección captura en el editor del sitio:
// «Nuestro recorrido» (etapas con año, título, descripción y foto opcional)
// y «Conoce al equipo» (foto redonda o, sin ella, el emoji). Mismos títulos
// que Nosotros.tsx; la pantalla solo las pinta si hay algo capturado.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/info_nosotros.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/public/widgets/movimiento_contenido.dart';

/// Foto del editor del sitio: asset de la app ("assets/…") o URL https. Si
/// no carga, deja el [respaldo].
class FotoDelSitio extends StatelessWidget {
  const FotoDelSitio({
    required this.ruta,
    required this.respaldo,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String ruta;
  final Widget respaldo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: ruta.startsWith('assets/')
          ? AssetImage(ruta)
          : NetworkImage(ruta) as ImageProvider,
      fit: fit,
      frameBuilder: (_, foto, cuadro, sincrona) =>
          FotoAlLlegar(foto: foto, cuadro: cuadro, sincrona: sincrona),
      errorBuilder: (_, _, _) => respaldo,
    );
  }
}

/// Título de sección con su subtítulo, como en la web.
class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.titulo, this.subtitulo);

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitulo,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
      ],
    );
  }
}

/// «Nuestro recorrido»: una línea vertical con un punto por etapa; el año
/// alterna verde y dorado, como en la web.
class SeccionRecorrido extends StatelessWidget {
  const SeccionRecorrido({required this.etapas, super.key});

  final List<EtapaRecorrido> etapas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EntradaAlVer(
          child: _TituloSeccion('Nuestro Recorrido',
              'Un viaje de pasión, dedicación y crecimiento continuo'),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < etapas.length; i++)
          EntradaAlVer(
            child: _Etapa(
              etapa: etapas[i],
              color: i.isEven ? AppColors.pierVerde : AppColors.pierDorado,
              ultima: i == etapas.length - 1,
            ),
          ),
      ],
    );
  }
}

class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.etapa,
    required this.color,
    required this.ultima,
  });

  final EtapaRecorrido etapa;
  final Color color;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final imagen = etapa.imagen;
    final descripcion = etapa.descripcion;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Punto y línea: la línea no sigue después de la última etapa.
          SizedBox(
            width: 20,
            child: Column(children: [
              const SizedBox(height: 6),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.pierVerde, width: 3),
                ),
              ),
              if (!ultima)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.pierVerde.withValues(alpha: 0.3),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (etapa.anio.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(etapa.anio,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 8),
                  Text(etapa.titulo,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.pierVerdeOscuro)),
                  if (descripcion != null) ...[
                    const SizedBox(height: 4),
                    Text(descripcion,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5)),
                  ],
                  if (imagen != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: FotoDelSitio(
                          ruta: imagen,
                          // Sin foto que cargar, la etapa queda sin ella.
                          respaldo: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Conoce al equipo»: una tarjeta por persona con su foto redonda o, si no
/// tiene, su emoji (y si tampoco, la inicial de su nombre).
class SeccionEquipo extends StatelessWidget {
  const SeccionEquipo({required this.integrantes, super.key});

  final List<IntegranteEquipo> integrantes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EntradaAlVer(
          child: _TituloSeccion('Conoce al Equipo',
              'Las manos expertas detrás de cada creación'),
        ),
        const SizedBox(height: 16),
        for (final persona in integrantes)
          EntradaAlVer(child: _Integrante(persona)),
      ],
    );
  }
}

class _Integrante extends StatelessWidget {
  const _Integrante(this.persona);

  final IntegranteEquipo persona;

  static const double _diametro = 64;

  @override
  Widget build(BuildContext context) {
    final descripcion = persona.descripcion;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.nombre,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.pierVerdeOscuro)),
                if (persona.puesto.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(persona.puesto,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pierDorado)),
                ],
                if (descripcion != null) ...[
                  const SizedBox(height: 6),
                  Text(descripcion,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final sinFoto = Container(
      width: _diametro,
      height: _diametro,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pierVerde.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: persona.emoji != null
          ? Text(persona.emoji!, style: const TextStyle(fontSize: 30))
          : persona.nombre.isNotEmpty
              ? Text(persona.nombre.characters.first.toUpperCase(),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pierVerde))
              : Icon(LucideIcons.user, color: AppColors.pierVerde),
    );
    final foto = persona.foto;
    if (foto == null) return sinFoto;
    return PopAlCompas(
      child: ClipOval(
        child: SizedBox(
          width: _diametro,
          height: _diametro,
          // Si la foto no carga, el emoji o la inicial.
          child: FotoDelSitio(ruta: foto, respaldo: sinFoto),
        ),
      ),
    );
  }
}
