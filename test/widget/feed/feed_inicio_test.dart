// test/widget/feed/feed_inicio_test.dart — publicaciones al final del inicio
// del cliente (#132) sin red: «Novedades de Pier» con publicaciones, una
// promoción cada 5, sugerencias al acabarse y «Ya viste todo por hoy»,
// agregar al carrito, invitados sin publicaciones, vacío y errores.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';
import '../../helpers/pump_app.dart';

const _feed = '/publicaciones/feed?limite=8';
const _siguiente =
    '/publicaciones/feed?limite=8'
    '&antes=2026-10-10T12%3A00%3A00.123456Z&antes_id=5';
const _promociones = '/publicaciones/promociones';
const _sugerencias = '/publicaciones/sugerencias?pagina=1';

FakeApiClient _backend() => FakeApiClient(
  respuestas: {
    ApiConstants.login: {
      'success': true,
      'token': 'jwt',
      'user': {
        'id': 1,
        'nombre': 'Ana',
        'email': 'ana@pier.mx',
        'rol': 'cliente',
      },
    },
    ApiConstants.carrito: {'success': true, 'items': <dynamic>[]},
    _promociones: promocionesFeedJson([promocionFeedJson()]),
    _feed: feedJson([
      publicacionJson(
        totalComentarios: 2,
        comentarios: [
          comentarioJson(),
          comentarioJson(
            id: 2,
            texto: '¡Gracias por tu pedido!',
            autor: 'Pier Repostería',
            oficial: true,
          ),
        ],
      ),
      for (var id = 2; id <= 5; id++)
        publicacionJson(id: id, texto: 'Publicación $id'),
      publicacionJson(
        id: 6,
        texto: 'Mira cómo decoramos',
        medios: [
          medioJson(
            tipo: 'video',
            url: 'https://res.cloudinary.com/v.mp4',
            poster: 'https://res.cloudinary.com/v.jpg',
            duracion: 12,
          ),
          medioJson(id: 2),
        ],
      ),
    ], siguiente: cursorJson()),
    _siguiente: feedJson([publicacionJson(id: 7, texto: 'La última')]),
    _sugerencias: sugerenciasJson([
      sugeridoJson(motivo: 'Porque te gustó Chocoflan'),
    ]),
  },
);

Future<FakeApiClient> _montar(
  WidgetTester tester, {
  FakeApiClient? api,
  bool conSesion = true,
}) async {
  // Ancha como las demás pruebas del inicio: sus secciones no caben en un
  // celular con la fuente de pruebas.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = api ?? _backend();
  await tester.pumpApp(const HomeScreen(), api: backend);
  if (conSesion) await tester.iniciarSesion(find.byType(HomeScreen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return backend;
}

/// Baja hasta que se vea [buscado] (el feed carga más al acercarse al final).
Future<void> _bajarHasta(WidgetTester tester, Finder buscado) =>
    tester.scrollUntilVisible(
      buscado,
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );

/// Desmonta para cancelar el carrusel y el sondeo de notificaciones.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Publicaciones en el inicio', () {
    testWidgets('el cliente ve publicaciones con contadores y comentarios', (
      tester,
    ) async {
      final api = await _montar(tester);

      await _bajarHasta(tester, find.text('Novedades de Pier'));
      await _bajarHasta(
        tester,
        find.text('Pastel de chocolate recién salido del horno'),
      );
      expect(find.text('Pier Repostería'), findsWidgets);
      expect(find.text('Ver los 2 comentarios'), findsOneWidget);
      expect(find.text('¡Se ve delicioso!'), findsOneWidget);
      expect(find.text('¡Gracias por tu pedido!'), findsOneWidget);
      expect(find.text('Respuesta de Pier'), findsOneWidget);
      expect(api.llamo(_feed, metodo: 'GET-Auth'), isTrue);
      await _desmontar(tester);
    });

    testWidgets('promoción después de 5 publicaciones, con su precio', (
      tester,
    ) async {
      await _montar(tester);

      await _bajarHasta(tester, find.text('Publicación 5'));
      await _bajarHasta(tester, find.text(r'$200.00'));
      expect(find.text(r'$250.00'), findsOneWidget);
      expect(find.text('-20 %'), findsOneWidget);
      expect(find.text('Solo esta semana'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('el video muestra su portada y duración', (tester) async {
      await _montar(tester);

      await _bajarHasta(tester, find.text('Mira cómo decoramos'));
      await _bajarHasta(tester, find.text('0:12'));
      expect(find.text('1/2'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('al final carga más, luego sugerencias y «Ya viste todo»', (
      tester,
    ) async {
      final api = await _montar(tester);

      await _bajarHasta(tester, find.text('La última'));
      await _bajarHasta(tester, find.text('Ya viste todo por hoy'));
      expect(api.llamo(_siguiente), isTrue);
      expect(find.text('Te podría gustar'), findsOneWidget);
      expect(find.text('Porque te gustó Chocoflan'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('agregar una sugerencia al carrito', (tester) async {
      final api = await _montar(tester);

      await _bajarHasta(tester, find.text('Porque te gustó Chocoflan'));
      final agregar = find.widgetWithText(FilledButton, 'Agregar').last;
      await tester.ensureVisible(agregar);
      await tester.pump();
      await tester.tap(agregar);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final llamada = api.llamadas.lastWhere(
        (l) => l.endpoint == ApiConstants.carrito && l.metodo == 'POST-Auth',
      );
      expect(llamada.body, {
        'producto_id': 20,
        'cantidad': 1,
        'tamano': 'chico',
      });
      expect(find.text('Se agregó al carrito'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('si no se pudo agregar lo avisa', (tester) async {
      final api = _backend()
        ..fallar(ApiConstants.carrito, 'Ya no hay existencias');
      await _montar(tester, api: api);

      await _bajarHasta(tester, find.text(r'$200.00'));
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Ya no hay existencias'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('el invitado no ve publicaciones', (tester) async {
      final api = await _montar(tester, conSesion: false);

      await _bajarHasta(tester, find.text('¿Por qué elegirnos?'));
      expect(find.text('Novedades de Pier'), findsNothing);
      expect(
        api.llamadas.any((l) => l.endpoint.startsWith('/publicaciones')),
        isFalse,
      );
      await _desmontar(tester);
    });

    testWidgets('sin publicaciones: lo dice', (tester) async {
      final api = _backend()
        ..responder(_feed, feedJson(const []))
        ..responder(_sugerencias, sugerenciasJson(const []));
      await _montar(tester, api: api);

      await _bajarHasta(tester, find.text('Aún no hay publicaciones'));
      await _desmontar(tester);
    });

    testWidgets('error al cargar: mensaje y Reintentar', (tester) async {
      final api = _backend()..fallar(_feed, 'Error al cargar el inicio');
      await _montar(tester, api: api);

      await _bajarHasta(
        tester,
        find.text('No pudimos cargar las publicaciones'),
      );
      expect(find.text('Error al cargar el inicio'), findsOneWidget);
      api.responder(_feed, feedJson([publicacionJson(texto: 'Ya cargó')]));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _bajarHasta(tester, find.text('Ya cargó'));
      await _desmontar(tester);
    });

    testWidgets('si falla al cargar más, deja reintentar', (tester) async {
      final api = _backend()..fallar(_siguiente, 'Sin conexión');
      await _montar(tester, api: api);

      await _bajarHasta(tester, find.text('No se pudieron cargar más'));
      api.responder(
        _siguiente,
        feedJson([publicacionJson(id: 7, texto: 'La última')]),
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _bajarHasta(tester, find.text('La última'));
      await _desmontar(tester);
    });
  });
}
