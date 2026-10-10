// lib/ui/home/widgets/home_carrusel.dart
//
// Carrusel del inicio: avanza solo cada 5 s, con puntos de página. La página
// visible y el temporizador son estado de la interfaz; los slides llegan del
// HomeViewModel (los del panel o los de respaldo).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/slide_hero.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:provider/provider.dart';

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
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.intervalo, (_) {
      if (!mounted || widget.slides.isEmpty) return;
      final siguiente = (_pagina + 1) % widget.slides.length;
      setState(() => _pagina = siguiente);
      if (_pageController.hasClients) {
        _pageController.animateToPage(siguiente,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  void didUpdateWidget(HomeCarrusel anterior) {
    super.didUpdateWidget(anterior);
    // Si la lista se acorta con el carrusel avanzado, volver al inicio.
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
    if (slide.ruta == RutaSlide.catalogo) {
      context.read<NavigationProvider>().goCatalogo();
    } else {
      Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const ContactScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    return Container(
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
            PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _pagina = i),
              itemBuilder: (context, i) => _slide(slides[i]),
            ),
            Positioned(
              bottom: 12, right: 16,
              child: Row(
                children: List.generate(slides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: _pagina == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _pagina == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slide(SlideHero slide) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(slide.imagen, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.pierVerdeOscuro,
              child: const Icon(LucideIcons.cake, color: Colors.white, size: 60),
            )),
        DecoratedBox(
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
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Los slides del panel no traen etiqueta: sin badge
              if (slide.etiqueta.isNotEmpty) ...[
                Container(
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
                ),
                const SizedBox(height: 8),
              ],
              // maxLines: los textos del panel pueden ser largos
              Text(slide.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.3)),
              const SizedBox(height: 5),
              Text(slide.subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _abrir(slide),
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
            ],
          ),
        ),
      ],
    );
  }
}
