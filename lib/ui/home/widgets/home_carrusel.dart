// lib/ui/home/widgets/home_carrusel.dart
//
// Carrusel del inicio: avanza solo cada 5 s, con puntos de página. La página
// visible y el temporizador son estado de la interfaz; los slides llegan del
// HomeViewModel (los del editor del sitio, los del panel o los de respaldo).
// El botón abre la pantalla de su enlace: catálogo, contacto, nosotros,
// preguntas frecuentes o legales (#168).
//
// Movimiento: al pasar de slide la foto se queda un poco atrás de su página
// (paralaje) y crece apenas, y las líneas del texto se abren en abanico; los
// puntos siguen al deslizamiento. En reposo todo queda en su lugar exacto.
// Si los slides del panel reemplazan a los de respaldo, cada slide pasa al
// nuevo con un fundido. Con movimiento reducido no hay paralaje y el
// carrusel salta de slide en vez de deslizarse.
//
// Solo avanza a la vista: en una pestaña oculta o bajo otra ruta sus tickers
// están apagados, el deslizamiento quedaría congelado y barrería de golpe al
// volver. Del último slide pasa al primero hacia adelante: después del último
// va una copia del primero y, al quedar quieto en ella, salta al primero de
// verdad (se ven igual, así que no se nota). Antes regresaba barriendo hacia
// atrás por todos los slides, como un rebobinado.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/slide_hero.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/home/widgets/movimiento_inicio.dart';
import 'package:pier_reposteria/ui/public/widgets/about_us_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/contact_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/faq_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/legal_screen.dart';
import 'package:provider/provider.dart';

/// La página que se ve (con decimales mientras se desliza), o [respaldo] si
/// el PageView todavía no tiene medidas (leer `page` antes afirma).
double _paginaDe(PageController control, int respaldo) {
  if (control.hasClients && control.positions.length == 1) {
    final posicion = control.position;
    if (posicion.hasPixels && posicion.hasContentDimensions) {
      return control.page ?? respaldo.toDouble();
    }
  }
  return respaldo.toDouble();
}

class HomeCarrusel extends StatefulWidget {
  const HomeCarrusel({
    required this.slides,
    this.intervalo = const Duration(seconds: 5),
    super.key,
  });

  final List<SlideHero> slides;

  /// Cada cuánto avanza solo.
  final Duration intervalo;

  @override
  State<HomeCarrusel> createState() => _HomeCarruselState();
}

class _HomeCarruselState extends State<HomeCarrusel> {
  final PageController _pageController = PageController();
  late final Timer _timer;

  // Página del PageView. Con dos slides o más puede ser la copia del primero
  // (la página `slides.length`), solo hasta que el carrusel queda quieto.
  int _pagina = 0;
  bool _reducido = false;

  /// Con dos slides o más, después del último va una copia del primero.
  bool get _conCopia => widget.slides.length > 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.intervalo, (_) => _avanzar());
  }

  void _avanzar() {
    // Fuera de la vista (pestaña oculta o bajo otra ruta) no avanza.
    if (!mounted ||
        !_conCopia ||
        !TickerMode.getValuesNotifier(context).value.enabled) {
      return;
    }
    final total = widget.slides.length;
    if (_pagina >= total && _pageController.hasClients) {
      // Sigue en la copia (no ha quedado quieto): parte del primero de verdad.
      _pageController.jumpToPage(0);
      _pagina = 0;
    }
    final siguiente = _pagina + 1;
    if (_reducido || !_pageController.hasClients) {
      // Con movimiento reducido salta (animateToPage no acepta duración
      // cero), y nunca a la copia.
      setState(() => _pagina = siguiente % total);
      if (_pageController.hasClients) _pageController.jumpToPage(_pagina);
      return;
    }
    // Del último va hacia adelante, a la copia del primero.
    setState(() => _pagina = siguiente);
    _pageController
        .animateToPage(siguiente,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut)
        .ignore();
  }

  /// Cuando el carrusel queda quieto (solo o tras el dedo), si quedó en la
  /// copia del primer slide salta al primero de verdad. Se espera a que
  /// termine el aviso: saltar mientras se reparte movería el ScrollPosition
  /// a media actividad.
  bool _alQuedarQuieto(ScrollEndNotification aviso) {
    if (aviso.depth == 0 && _conCopia) scheduleMicrotask(_salirDeLaCopia);
    return false;
  }

  void _salirDeLaCopia() {
    if (!mounted || !_conCopia || !_pageController.hasClients) return;
    // El dedo ya lo mueve otra vez: espera a que vuelva a quedar quieto.
    if (_pageController.position.isScrollingNotifier.value) return;
    final enLaCopia =
        (_paginaDe(_pageController, _pagina) - widget.slides.length).abs() <
            0.001;
    if (enLaCopia) _pageController.jumpToPage(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = AppMovimiento.reducido(context);
  }

  @override
  void didUpdateWidget(HomeCarrusel anterior) {
    super.didUpdateWidget(anterior);
    // Si la lista se acorta con el carrusel avanzado (o estaba en la copia
    // del primero), volver al inicio.
    if (_pagina >= widget.slides.length) {
      _pagina = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _abrir(SlideHero slide) {
    final Widget pantalla;
    switch (slide.ruta) {
      case RutaSlide.catalogo:
        context.read<NavigationProvider>().goCatalogo();
        return;
      case RutaSlide.contacto:
        pantalla = const ContactScreen();
      case RutaSlide.nosotros:
        pantalla = const AboutUsScreen();
      case RutaSlide.faq:
        pantalla = const FAQScreen();
      case RutaSlide.legales:
        pantalla = const LegalScreen();
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla))
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    // El carrusel se repinta mientras desliza: aislado del resto del inicio.
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: _alQuedarQuieto,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _conCopia ? slides.length + 1 : slides.length,
                  onPageChanged: (i) => setState(() => _pagina = i),
                  itemBuilder: (context, i) {
                    // La última página es la copia del primer slide.
                    final slide = slides[i % slides.length];
                    return _PaginaCarrusel(
                      slide: slide,
                      indice: i,
                      control: _pageController,
                      paginaFija: _pagina,
                      reducido: _reducido,
                      alAbrir: () => _abrir(slide),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 12, right: 16,
                // Los puntos siguen al deslizamiento: el del slide que llega
                // se alarga y se aclara mientras el otro se encoge.
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    final actual = _paginaDe(_pageController, _pagina);
                    return Row(
                      children: List.generate(slides.length, (i) {
                        // El primer punto también se acerca desde la copia
                        // del primer slide (después del último).
                        var distancia = (actual - i).abs();
                        if (i == 0 && _conCopia) {
                          final hastaCopia = (actual - slides.length).abs();
                          if (hastaCopia < distancia) distancia = hastaCopia;
                        }
                        final cerca = clampDouble(1 - distancia, 0, 1);
                        return Container(
                          margin: const EdgeInsets.only(left: 4),
                          width: 6 + 12 * cerca,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.4 + 0.6 * cerca),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una página del carrusel. Recorta lo suyo (la foto del paralaje no se
/// asoma a la página vecina) y, si su slide cambia (llegan los del panel),
/// pasa al nuevo con un fundido.
class _PaginaCarrusel extends StatelessWidget {
  const _PaginaCarrusel({
    required this.slide,
    required this.indice,
    required this.control,
    required this.paginaFija,
    required this.reducido,
    required this.alAbrir,
  });

  final SlideHero slide;
  final int indice;
  final PageController control;

  /// La página actual sin decimales, por si el PageView aún no tiene medidas.
  final int paginaFija;

  final bool reducido;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final firma = [
      slide.imagen,
      slide.etiqueta,
      slide.titulo,
      slide.subtitulo,
      slide.cta,
    ].join('|');
    return ClipRect(
      child: CambioAnimado(
        duracion: AppMovimiento.media,
        child: KeyedSubtree(
          key: ValueKey(firma),
          child: _ContenidoSlide(
            slide: slide,
            indice: indice,
            control: control,
            paginaFija: paginaFija,
            reducido: reducido,
            alAbrir: alAbrir,
          ),
        ),
      ),
    );
  }
}

/// Foto, degradado y texto de un slide, con el paralaje mientras desliza.
class _ContenidoSlide extends StatelessWidget {
  const _ContenidoSlide({
    required this.slide,
    required this.indice,
    required this.control,
    required this.paginaFija,
    required this.reducido,
    required this.alAbrir,
  });

  final SlideHero slide;
  final int indice;
  final PageController control;
  final int paginaFija;
  final bool reducido;
  final VoidCallback alAbrir;

  // Cada línea del texto (etiqueta, título, subtítulo, botón) se abre un
  // poco más que la anterior al deslizar.
  static Widget _abanico(double desfase, int linea, Widget hijo) =>
      Transform.translate(
        offset: Offset(desfase * (24 + 10 * linea), 0),
        child: hijo,
      );

  @override
  Widget build(BuildContext context) {
    // Las piezas se arman una vez; al deslizar solo cambian sus posiciones.
    // Las fotos incluidas en la web vienen con la app; las demás, de la red.
    final foto = Image(
        image: slide.imagenEsAsset
            ? AssetImage(slide.imagen)
            : NetworkImage(slide.imagen),
        fit: BoxFit.cover,
        frameBuilder: (_, imagen, cuadro, sincrona) =>
            FotoConFundido(foto: imagen, cuadro: cuadro, sincrona: sincrona),
        errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.pierVerdeOscuro,
              child: const Icon(LucideIcons.cake, color: Colors.white, size: 60),
            ));
    final degradado = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
          ],
        ),
      ),
    );
    // Los slides del panel no traen etiqueta: sin badge
    final etiqueta = slide.etiqueta.isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.pierDorado,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(slide.etiqueta,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1)),
          );
    // maxLines: los textos del panel pueden ser largos
    final titulo = Text(slide.titulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.3));
    final subtitulo = Text(slide.subtitulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85)));
    final boton = PresionEscala(
      escala: AppMovimiento.escalaPresionChica,
      child: GestureDetector(
        onTap: alAbrir,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.pierVerde,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(slide.cta,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );

    // desfase: 0 = en su lugar; 1 = una página a la derecha; -1 = a la
    // izquierda.
    Widget armar(double desfase) => Stack(
      fit: StackFit.expand,
      children: [
        // Fondo mientras la foto llega (el mismo del error).
        ColoredBox(color: AppColors.pierVerdeOscuro),
        // Paralaje: la foto va al 70 % de su página y crece apenas fuera
        // del centro. Lo que se destapa queda siempre del lado que no se ve.
        FractionalTranslation(
          translation: Offset(-0.3 * desfase, 0),
          child: Transform.scale(scale: 1 + 0.08 * desfase.abs(), child: foto),
        ),
        degradado,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: clampDouble(1 - 1.6 * desfase.abs(), 0, 1),
            alwaysIncludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (etiqueta != null) ...[
                  _abanico(desfase, 0, etiqueta),
                  const SizedBox(height: 8),
                ],
                _abanico(desfase, 1, titulo),
                const SizedBox(height: 5),
                _abanico(desfase, 2, subtitulo),
                const SizedBox(height: 14),
                _abanico(desfase, 3, boton),
              ],
            ),
          ),
        ),
      ],
    );

    if (reducido) return armar(0);
    return AnimatedBuilder(
      animation: control,
      builder: (context, _) {
        final desfase = indice - _paginaDe(control, paginaFija);
        // En reposo la página puede quedar a una millonésima del entero:
        // se toma como exacta (sin capas de más).
        return armar(desfase.abs() < 0.001 ? 0 : desfase);
      },
    );
  }
}
