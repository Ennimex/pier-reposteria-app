// lib/ui/feed/widgets/video_publicacion.dart
//
// Videos de las publicaciones (#134), como MediosPublicacion.tsx de la web:
// antes de reproducir se ve la portada con su duración; cuando el video
// queda visible en su mayor parte (60 %) se reproduce en silencio y se pausa
// al salir de la pantalla (o al deslizar a otra foto); si la persona lo
// pausó, no vuelve a arrancar solo, y con «reducir animaciones» nunca
// arranca solo. Tocarlo pausa o reanuda; el botón de la bocina activa el
// sonido. El reproductor (video_player) se crea hasta que hace falta y se
// libera al salir de la tarjeta.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Lo que la tarjeta necesita de un reproductor de video.
abstract class ReproductorVideo implements Listenable {
  Future<void> iniciar();
  Future<void> reproducir();
  Future<void> pausar();
  Future<void> ponerVolumen(double volumen);
  bool get listo;
  bool get reproduciendo;

  /// Ancho / alto del video (1 mientras no está listo).
  double get proporcion;
  Widget vista();
  Future<void> liberar();
}

/// El reproductor de la app: video_player desde la red, en bucle.
class ReproductorDeRed implements ReproductorVideo {
  ReproductorDeRed(String url)
      : _c = VideoPlayerController.networkUrl(Uri.parse(url));

  final VideoPlayerController _c;

  @override
  Future<void> iniciar() async {
    await _c.initialize();
    await _c.setLooping(true);
  }

  @override
  Future<void> reproducir() => _c.play();
  @override
  Future<void> pausar() => _c.pause();
  @override
  Future<void> ponerVolumen(double volumen) => _c.setVolume(volumen);
  @override
  bool get listo => _c.value.isInitialized;
  @override
  bool get reproduciendo => _c.value.isPlaying;
  @override
  double get proporcion => listo ? _c.value.aspectRatio : 1;
  @override
  Widget vista() => VideoPlayer(_c);
  @override
  Future<void> liberar() => _c.dispose();
  @override
  void addListener(VoidCallback listener) => _c.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _c.removeListener(listener);
}

/// Crea el reproductor de cada video; las pruebas lo cambian por uno falso.
@visibleForTesting
ReproductorVideo Function(String url) crearReproductor = ReproductorDeRed.new;

/// Fracción visible desde la que el video arranca solo (como la web).
const double umbralVisible = 0.6;

/// Un video de la publicación: [portada] (la portada de red con su
/// duración) hasta que arranca.
class VideoPublicacion extends StatefulWidget {
  const VideoPublicacion({
    required this.medio,
    required this.portada,
    super.key,
  });

  final MedioPublicacion medio;
  final Widget portada;

  @override
  State<VideoPublicacion> createState() => _VideoPublicacionState();
}

class _VideoPublicacionState extends State<VideoPublicacion> {
  ReproductorVideo? _reproductor;
  bool _visible = false;
  bool _pausadoPorPersona = false;
  bool _conSonido = false;
  bool _error = false;

  @override
  void dispose() {
    final r = _reproductor;
    if (r != null) {
      r.removeListener(_repintar);
      unawaited(_liberar(r));
    }
    super.dispose();
  }

  /// Libera el reproductor; si nunca llegó a crearse en la plataforma, no
  /// hay nada que liberar.
  static Future<void> _liberar(ReproductorVideo r) async {
    try {
      await r.liberar();
    } on Object {
      // Ya no hay video que soltar.
    }
  }

  void _repintar() {
    if (mounted) setState(() {});
  }

  /// Crea e inicia el reproductor la primera vez; null si falló.
  Future<ReproductorVideo?> _preparar() async {
    final actual = _reproductor;
    if (actual != null) return actual.listo ? actual : null;
    final r = crearReproductor(widget.medio.url)..addListener(_repintar);
    _reproductor = r;
    try {
      await r.iniciar();
      await r.ponerVolumen(_conSonido ? 1 : 0);
    } on Object {
      if (mounted) setState(() => _error = true);
      return null;
    }
    return mounted ? r : null;
  }

  Future<void> _alCambiarVisibilidad(VisibilityInfo info) async {
    if (!mounted) return;
    final visible = info.visibleFraction >= umbralVisible;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      await _reproductor?.pausar();
      return;
    }
    if (_pausadoPorPersona || AppMovimiento.reducido(context)) return;
    final r = await _preparar();
    if (r != null && _visible) await r.reproducir();
  }

  Future<void> _alTocar() async {
    final r = _reproductor;
    if (r != null && r.reproduciendo) {
      _pausadoPorPersona = true;
      await r.pausar();
      return;
    }
    _pausadoPorPersona = false;
    final listo = await _preparar();
    await listo?.reproducir();
  }

  Future<void> _alternarSonido() async {
    setState(() => _conSonido = !_conSonido);
    await _reproductor?.ponerVolumen(_conSonido ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reproductor;
    final listo = r != null && r.listo;
    final reproduciendo = listo && r.reproduciendo;
    return VisibilityDetector(
      key: ValueKey('video-${widget.medio.url}'),
      onVisibilityChanged: (info) => unawaited(_alCambiarVisibilidad(info)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_alTocar()),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (listo)
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: r.proporcion,
                    child: r.vista(),
                  ),
                ),
              )
            else
              widget.portada,
            if (!reproduciendo)
              Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.black54,
                  child: Icon(
                    _error ? LucideIcons.videoOff : LucideIcons.play,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            if (listo)
              Positioned(
                bottom: 6,
                left: 6,
                child: IconButton(
                  tooltip: _conSonido ? 'Silenciar' : 'Activar sonido',
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  color: Colors.white,
                  icon: Icon(
                    _conSonido ? LucideIcons.volume2 : LucideIcons.volumeX,
                    size: 18,
                  ),
                  onPressed: () => unawaited(_alternarSonido()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
