// lib/domain/models/slide_hero.dart
//
// Un slide del carrusel del inicio: los de respaldo de la app o los que se
// administran en Dirección → Personalización (como en la web).

/// A dónde lleva el botón del slide.
enum RutaSlide { catalogo, contacto }

class SlideHero {
  const SlideHero({
    required this.titulo,
    required this.subtitulo,
    required this.cta,
    required this.imagen,
    this.etiqueta = '',
    this.ruta = RutaSlide.catalogo,
  });

  /// Píldora de arriba ("ARTESANAL"); vacía en los del panel.
  final String etiqueta;
  final String titulo;
  final String subtitulo;

  /// Texto del botón.
  final String cta;
  final RutaSlide ruta;
  final String imagen;

  SlideHero copyWith({String? titulo, String? subtitulo}) => SlideHero(
        etiqueta: etiqueta,
        titulo: titulo ?? this.titulo,
        subtitulo: subtitulo ?? this.subtitulo,
        cta: cta,
        ruta: ruta,
        imagen: imagen,
      );
}
