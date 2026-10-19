// test/widget/feed/interaccion_screen_test.dart — «Me encanta» y comentarios
// desde el inicio (#133) sin red: el corazón al instante (revierte si falla,
// la publicación sale si ya no está) y la hoja de comentarios (ver más,
// respuesta de Pier, comentar, antispam, borrar los propios).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/feed_sliver.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';
import '../../helpers/pump_app.dart';

const _feed = '/publicaciones/feed?limite=8';
const _corazon = '/publicaciones/1/corazon';
const _comentarios = '/publicaciones/1/comentarios?limite=20';
const _comentar = '/publicaciones/1/comentarios';

FakeApiClient _backend({int totalComentarios = 2}) => FakeApiClient()
  ..responder('/publicaciones/promociones', promocionesFeedJson(const []))
  ..responder(
    _feed,
    feedJson([
      publicacionJson(
        totalComentarios: totalComentarios,
        comentarios: [
          if (totalComentarios > 0) comentarioJson(id: 10),
        ],
      ),
    ]),
  )
  ..responder('/publicaciones/sugerencias?pagina=1', sugerenciasJson(const []))
  ..responder(_comentarios, {
    'success': true,
    'comentarios': [
      comentarioJson(id: 10),
      comentarioJson(id: 11, texto: 'Mío', autor: 'Ana G.', tuyo: true),
      comentarioJson(
        id: 12,
        texto: '¡Gracias!',
        autor: 'Pier Repostería',
        oficial: true,
      ),
    ],
    'hay_mas': true,
  })
  ..responder('/publicaciones/1/comentarios?limite=20&despues_id=12', {
    'success': true,
    'comentarios': [comentarioJson(id: 13, texto: 'El último')],
    'hay_mas': false,
  });

/// Monta solo el feed (el inicio completo se prueba en feed_inicio_test).
Future<FakeApiClient> _montar(WidgetTester tester, {FakeApiClient? api}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = api ?? _backend();
  final vm = FeedViewModel(repo: PublicacionesRepositoryRemote(api: backend));
  addTearDown(vm.dispose);
  await vm.cargar();
  await tester.pumpApp(
    Scaffold(
      body: CustomScrollView(
        slivers: [FeedSliver(viewModel: vm, alAgregar: (_, _) async {})],
      ),
    ),
    api: backend,
  );
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _abrirComentarios(WidgetTester tester) async {
  await tester.tap(find.text('Ver los 2 comentarios'));
  await tester.pumpAndSettle();
}

void main() {
  group('Me encanta', () {
    testWidgets('se marca al instante y queda lo del servidor', (tester) async {
      final api = await _montar(tester);
      api.responder(_corazon, {
        'success': true,
        'me_encanta': true,
        'corazones': 4,
      });

      await tester.tap(find.byTooltip('Me encanta'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Quitar me encanta'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(api.ultima(_corazon)!.metodo, 'PUT-Auth');
    });

    testWidgets('si falla vuelve a como estaba y avisa', (tester) async {
      final api = await _montar(tester);
      api.fallar(_corazon, 'No se pudo guardar tu reacción');

      await tester.tap(find.byTooltip('Me encanta'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo guardar tu reacción'), findsOneWidget);
      expect(find.byTooltip('Me encanta'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('publicación eliminada: sale del inicio', (tester) async {
      final api = await _montar(tester);
      api.responder(_corazon, {
        'success': false,
        'message': 'Publicación no encontrada',
      });

      await tester.tap(find.byTooltip('Me encanta'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta publicación ya no está disponible'),
        findsOneWidget,
      );
      expect(
        find.text('Pastel de chocolate recién salido del horno'),
        findsNothing,
      );
    });
  });

  group('Comentarios', () {
    testWidgets('la hoja muestra los comentarios, la respuesta de Pier y '
        'carga más', (tester) async {
      await _montar(tester);

      await _abrirComentarios(tester);
      expect(find.text('Comentarios'), findsOneWidget);
      expect(find.text('Mío'), findsOneWidget);
      expect(find.text('Respuesta de Pier'), findsOneWidget);

      await tester.tap(find.text('Ver más comentarios'));
      await tester.pumpAndSettle();
      expect(find.text('El último'), findsOneWidget);
      expect(find.text('Ver más comentarios'), findsNothing);
    });

    testWidgets('comentar: aparece y al cerrar sube el contador', (
      tester,
    ) async {
      final api = await _montar(tester);
      api.responder(_comentar, {
        'success': true,
        'comentario': comentarioJson(
          id: 20,
          texto: 'Se ve rico',
          autor: 'Ana G.',
          tuyo: true,
        ),
      });
      await _abrirComentarios(tester);

      final publicar = find.byTooltip('Publicar');
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: publicar, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Se ve rico');
      await tester.pump();
      expect(find.text('10/1000'), findsOneWidget);
      await tester.tap(publicar);
      await tester.pumpAndSettle();

      expect(api.ultima(_comentar)!.body, {'texto': 'Se ve rico'});
      expect(find.text('Se ve rico'), findsWidgets);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Ver los 3 comentarios'), findsOneWidget);
    });

    testWidgets('comentar de más: muestra el aviso del backend', (
      tester,
    ) async {
      final api = await _montar(tester);
      api.fallar(
        _comentar,
        'Escribiste varios comentarios seguidos. Espera un minuto y vuelve a intentarlo.',
      );
      await _abrirComentarios(tester);

      await tester.enterText(find.byType(TextField), 'Otro');
      await tester.pump();
      await tester.tap(find.byTooltip('Publicar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Espera un minuto'), findsOneWidget);
      expect(find.text('Otro'), findsOneWidget, reason: 'el texto se conserva');
    });

    testWidgets('borrar un comentario propio con confirmación', (tester) async {
      final api = await _montar(tester);
      api.responder('/publicaciones/comentarios/11', {'success': true});
      await _abrirComentarios(tester);

      expect(
        find.byTooltip('Eliminar comentario'),
        findsOneWidget,
        reason: 'solo el propio',
      );
      await tester.tap(find.byTooltip('Eliminar comentario'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar tu comentario?'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Mío'), findsNothing);
      expect(
        api.ultima('/publicaciones/comentarios/11')!.metodo,
        'DELETE-Auth',
      );
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Ver el comentario'), findsOneWidget);
    });

    testWidgets('sin comentarios: invita a comentar', (tester) async {
      final api = _backend(totalComentarios: 0)
        ..responder(_comentarios, {
          'success': true,
          'comentarios': <dynamic>[],
          'hay_mas': false,
        });
      await _montar(tester, api: api);

      await tester.tap(find.byTooltip('Comentar'));
      await tester.pumpAndSettle();

      expect(find.text('Sé el primero en comentar'), findsOneWidget);
    });

    testWidgets('error al cargar los comentarios', (tester) async {
      final api = _backend()
        ..fallar(_comentarios, 'Error al obtener los comentarios');
      await _montar(tester, api: api);

      await _abrirComentarios(tester);

      expect(find.text('Error al obtener los comentarios'), findsOneWidget);
    });

    testWidgets('la publicación ya no está: al cerrar sale del inicio', (
      tester,
    ) async {
      final api = _backend()
        ..responder(_comentarios, {
          'success': false,
          'message': 'Publicación no encontrada',
        });
      await _montar(tester, api: api);

      await _abrirComentarios(tester);
      expect(
        find.text('Esta publicación ya no está disponible'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Pastel de chocolate recién salido del horno'),
        findsNothing,
      );
    });
  });
}
