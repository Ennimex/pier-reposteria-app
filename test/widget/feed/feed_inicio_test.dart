// test/widget/feed/feed_inicio_test.dart — publicaciones del cliente sin red
// (#132, #133 y #175): en el Inicio, solo las 3 más recientes con «Ver todo»;
// en Novedades, todas con una promoción cada 5, sugerencias al acabarse y
// «Ya viste todo por hoy», agregar al carrito y errores; el invitado ve una
// invitación a entrar en lugar de las publicaciones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/feed/widgets/novedades_screen.dart';
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

/// Baja hasta que se vea [buscado] en la pantalla de arriba (Novedades carga
/// más al acercarse al final).
Future<void> _bajarHasta(WidgetTester tester, Finder buscado) =>
    tester.scrollUntilVisible(
      buscado,
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );

/// Toca «Ver todo» en el Inicio y espera a que se abra Novedades.
Future<void> _abrirNovedades(WidgetTester tester) async {
  await _bajarHasta(tester, find.text('Ver todo'));
  await tester.tap(find.text('Ver todo'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Desmonta para cancelar el carrusel y el sondeo de notificaciones.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Publicaciones en el inicio (#175)', () {
    testWidgets('solo las 3 más recientes, con contadores, comentarios y '
        '«Ver todo»', (tester) async {
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
      await _bajarHasta(tester, find.text('Publicación 3'));
      expect(find.text('Publicación 4'), findsNothing);
      expect(find.text('Ver todo'), findsOneWidget);
      expect(api.llamo(_feed, metodo: 'GET-Auth'), isTrue);

      // El Inicio ya no pide más publicaciones al bajar: eso es de Novedades
      await _bajarHasta(tester, find.text('¿Por qué elegirnos?'));
      expect(api.llamo(_siguiente), isFalse);
      await _desmontar(tester);
    });

    testWidgets('el invitado ve una invitación a entrar y no se piden '
        'publicaciones', (tester) async {
      final api = await _montar(tester, conSesion: false);

      await _bajarHasta(tester, find.text('Lo nuevo de Pier'));
      expect(find.widgetWithText(FilledButton, 'Iniciar sesión'),
          findsOneWidget);
      expect(find.text('Novedades de Pier'), findsNothing);
      await _bajarHasta(tester, find.text('¿Por qué elegirnos?'));
      expect(
        api.llamadas.any((l) => l.endpoint.startsWith('/publicaciones')),
        isFalse,
      );
      await _desmontar(tester);
    });

    testWidgets('sin publicaciones: lo dice y no ofrece «Ver todo»', (
      tester,
    ) async {
      final api = _backend()
        ..responder(_feed, feedJson(const []))
        ..responder(_sugerencias, sugerenciasJson(const []));
      await _montar(tester, api: api);

      await _bajarHasta(tester, find.text('Aún no hay publicaciones'));
      expect(find.text('Ver todo'), findsNothing);
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
  });

  group('Novedades (#175)', () {
    testWidgets('«Ver todo» abre todas, con una promoción después de 5', (
      tester,
    ) async {
      await _montar(tester);
      await _abrirNovedades(tester);

      expect(find.byType(NovedadesScreen), findsOneWidget);
      await _bajarHasta(tester, find.text('Publicación 5'));
      await _bajarHasta(tester, find.text(r'$200.00'));
      expect(find.text(r'$250.00'), findsOneWidget);
      expect(find.text('-20 %'), findsOneWidget);
      expect(find.text('Solo esta semana'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('el video muestra su portada y duración', (tester) async {
      await _montar(tester);
      await _abrirNovedades(tester);

      await _bajarHasta(tester, find.text('Mira cómo decoramos'));
      await _bajarHasta(tester, find.text('0:12'));
      expect(find.text('1/2'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('al final carga más, luego sugerencias y «Ya viste todo»', (
      tester,
    ) async {
      final api = await _montar(tester);
      await _abrirNovedades(tester);

      await _bajarHasta(tester, find.text('La última'));
      await _bajarHasta(tester, find.text('Ya viste todo por hoy'));
      expect(api.llamo(_siguiente), isTrue);
      expect(find.text('Te podría gustar'), findsOneWidget);
      expect(find.text('Porque te gustó Chocoflan'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('agregar una sugerencia al carrito', (tester) async {
      final api = await _montar(tester);
      await _abrirNovedades(tester);

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
      await _abrirNovedades(tester);

      await _bajarHasta(tester, find.text(r'$200.00'));
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Ya no hay existencias'), findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('si falla al cargar más, deja reintentar', (tester) async {
      final api = _backend()..fallar(_siguiente, 'Sin conexión');
      await _montar(tester, api: api);
      await _abrirNovedades(tester);

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

    testWidgets('«Me encanta» en Novedades también se ve en el Inicio', (
      tester,
    ) async {
      final api = _backend()
        ..responder(ApiConstants.publicacionCorazon(1), {
          'success': true,
          'me_encanta': true,
          'corazones': 4,
        });
      await _montar(tester, api: api);
      await _abrirNovedades(tester);

      await _bajarHasta(tester, find.byTooltip('Me encanta').first);
      await tester.tap(find.byTooltip('Me encanta').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(api.llamo(ApiConstants.publicacionCorazon(1), metodo: 'PUT-Auth'),
          isTrue);

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _bajarHasta(tester, find.byTooltip('Quitar me encanta'));
      expect(find.byTooltip('Quitar me encanta'), findsOneWidget);
      await _desmontar(tester);
    });
  });
}
