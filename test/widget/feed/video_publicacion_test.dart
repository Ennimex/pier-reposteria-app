// test/widget/feed/video_publicacion_test.dart — videos de las publicaciones
// (#134) con un reproductor falso: portada antes de reproducir, arranque en
// silencio al quedar visible, pausa al salir, tocar para pausar (y que no
// vuelva solo), activar el sonido, sin arranque con animaciones reducidas y
// el video que no carga.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/feed/widgets/video_publicacion.dart';

import '../../fakes/reproductor_falso.dart';

final _medio = MedioPublicacion.fromJson({
  'tipo': 'video',
  'url': 'https://res.cloudinary.com/demo/video/upload/v.mp4',
  'poster_url': 'https://res.cloudinary.com/demo/video/upload/v.jpg',
  'duracion': 12,
});

/// Un espacio, el video y otro espacio: el video empieza fuera de la
/// pantalla de pruebas (600 de alto), pero cerca, así que la lista no lo
/// destruye al ir y venir; se trae con [_ver] y se aleja con [_salir].
Future<void> _montar(WidgetTester tester, {bool reducido = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reducido,
        ),
        child: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 700),
              SizedBox(
                height: 300,
                child: VideoPublicacion(
                  medio: _medio,
                  portada: const Center(child: Text('Portada 0:12')),
                ),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _ver(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();
}

Future<void> _salir(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 500));
  await tester.pumpAndSettle();
}

void main() {
  late List<ReproductorFalso> creados;

  setUp(() {
    creados = [];
    crearReproductor = (_) {
      final r = ReproductorFalso();
      creados.add(r);
      return r;
    };
  });

  testWidgets('fuera de la pantalla se ve la portada y no se carga',
      (tester) async {
    await _montar(tester);
    expect(creados, isEmpty);
  });

  testWidgets('al quedar visible se reproduce en silencio y al salir se pausa',
      (tester) async {
    await _montar(tester);
    await _ver(tester);

    final r = creados.single;
    expect(r.reproduciendo, isTrue);
    expect(r.volumen, 0);
    expect(find.byKey(const Key('video-reproduciendo')), findsOneWidget);
    expect(find.text('Portada 0:12'), findsNothing);

    await _salir(tester);
    expect(r.reproduciendo, isFalse);
    await _ver(tester);
    expect(r.reproduciendo, isTrue);
    expect(creados, hasLength(1));
  });

  testWidgets('si la persona lo pausó, no vuelve a arrancar solo',
      (tester) async {
    await _montar(tester);
    await _ver(tester);
    final r = creados.single;

    await tester.tap(find.byType(VideoPublicacion));
    await tester.pump();
    expect(r.reproduciendo, isFalse);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);

    await _salir(tester);
    await _ver(tester);
    expect(r.reproduciendo, isFalse);

    await tester.tap(find.byType(VideoPublicacion));
    await tester.pump();
    expect(r.reproduciendo, isTrue);
  });

  testWidgets('el botón de la bocina activa y quita el sonido',
      (tester) async {
    await _montar(tester);
    await _ver(tester);
    final r = creados.single;

    await tester.tap(find.byTooltip('Activar sonido'));
    await tester.pump();
    expect(r.volumen, 1);
    expect(find.byIcon(LucideIcons.volume2), findsOneWidget);

    await tester.tap(find.byTooltip('Silenciar'));
    await tester.pump();
    expect(r.volumen, 0);
  });

  testWidgets('con animaciones reducidas no arranca solo; al tocar sí',
      (tester) async {
    await _montar(tester, reducido: true);
    await _ver(tester);
    expect(creados, isEmpty);
    expect(find.text('Portada 0:12'), findsOneWidget);

    await tester.tap(find.byType(VideoPublicacion));
    await tester.pump();
    expect(creados.single.reproduciendo, isTrue);
  });

  testWidgets('si el video no carga se queda la portada con su aviso',
      (tester) async {
    crearReproductor = (_) => ReproductorFalso(falla: true);
    await _montar(tester);
    await _ver(tester);

    expect(find.text('Portada 0:12'), findsOneWidget);
    expect(find.byIcon(LucideIcons.videoOff), findsOneWidget);
  });

  testWidgets('al salir de la tarjeta libera el reproductor', (tester) async {
    await _montar(tester);
    await _ver(tester);
    final r = creados.single;

    await tester.pumpWidget(const SizedBox());
    expect(r.liberado, isTrue);
  });
}
