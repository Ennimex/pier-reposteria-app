// test/widget/feed/reproductor_de_red_test.dart — el reproductor real de la
// app (#134): ReproductorDeRed sobre video_player, con una plataforma de video
// falsa en lugar de la nativa. Carga el video de la URL en bucle, reproduce,
// pausa, cambia el volumen, avisa a sus oyentes, muestra la vista de la
// plataforma y se libera.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/feed/widgets/video_publicacion.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const _url = 'https://res.cloudinary.com/demo/video/upload/v.mp4';

/// La plataforma nativa de video, falsa: anota cada llamada y, al crear el
/// reproductor, avisa que el video (1280 × 720, 12 s) está listo.
class _PlataformaFalsa extends VideoPlayerPlatform {
  final llamadas = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    llamadas.add('crear ${options.dataSource.uri}');
    return 1;
  }

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 12),
          size: const Size(1280, 720),
        ),
      );

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      llamadas.add('bucle $looping');

  @override
  Future<void> play(int playerId) async => llamadas.add('reproducir');

  @override
  Future<void> pause(int playerId) async => llamadas.add('pausar');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      llamadas.add('volumen $volume');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const Text('video de la plataforma');

  @override
  Future<void> dispose(int playerId) async => llamadas.add('liberar');
}

void main() {
  // VideoPlayerController se registra en el ciclo de vida de la app.
  TestWidgetsFlutterBinding.ensureInitialized();
  late VideoPlayerPlatform original;
  late _PlataformaFalsa plataforma;

  setUp(() {
    original = VideoPlayerPlatform.instance;
    plataforma = _PlataformaFalsa();
    VideoPlayerPlatform.instance = plataforma;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = original;
  });

  // Sin tiempo simulado: el reproductor espera respuestas de la plataforma
  // que en testWidgets no llegan sin pump.
  test('carga el video de la URL, listo y en bucle', () async {
    final reproductor = ReproductorDeRed(_url);
    expect(reproductor.listo, isFalse);
    expect(reproductor.proporcion, 1);

    await reproductor.iniciar();

    expect(reproductor.listo, isTrue);
    expect(reproductor.reproduciendo, isFalse);
    expect(reproductor.proporcion, closeTo(1280 / 720, 0.001));
    expect(
      plataforma.llamadas,
      containsAllInOrder(['crear $_url', 'bucle true']),
    );
    await reproductor.liberar();
  });

  test('reproduce, pausa, cambia el volumen y se libera', () async {
    final reproductor = ReproductorDeRed(_url);
    await reproductor.iniciar();
    plataforma.llamadas.clear();

    await reproductor.ponerVolumen(0);
    await reproductor.reproducir();
    expect(reproductor.reproduciendo, isTrue);
    await reproductor.pausar();
    expect(reproductor.reproduciendo, isFalse);
    await reproductor.liberar();

    expect(
      plataforma.llamadas,
      containsAllInOrder(['volumen 0.0', 'reproducir', 'pausar', 'liberar']),
    );
  });

  test('avisa a sus oyentes hasta que se quitan', () async {
    final reproductor = ReproductorDeRed(_url);
    await reproductor.iniciar();
    var avisos = 0;
    void oyente() => avisos++;

    reproductor.addListener(oyente);
    await reproductor.ponerVolumen(0.5);
    expect(avisos, greaterThan(0));

    final antes = avisos;
    reproductor.removeListener(oyente);
    await reproductor.ponerVolumen(1);
    expect(avisos, antes);
    await reproductor.liberar();
  });

  testWidgets('la vista muestra el video de la plataforma', (tester) async {
    final reproductor = ReproductorDeRed(_url);
    await tester.runAsync(reproductor.iniciar);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: reproductor.vista(),
      ),
    );
    expect(find.text('video de la plataforma'), findsOneWidget);

    // Primero se quita la vista (deja de escuchar al reproductor) y luego se
    // libera, como hace la tarjeta.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(reproductor.liberar);
  });
}
