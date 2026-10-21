// test/aceptacion/inicio/publicaciones_primero_test.dart — escenarios Gherkin
// del Inicio con las publicaciones primero (historia #175), sin red: la
// pantalla real de Inicio, Novedades, sus ViewModels y repositorios sobre
// FakeApiClient. El escenario del encabezado va con el rediseño de estilo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/feed/widgets/comentarios_sheet.dart';
import 'package:pier_reposteria/ui/feed/widgets/novedades_screen.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';
import '../../helpers/pump_app.dart';

const _feed = '/publicaciones/feed?limite=8';
const _siguiente =
    '/publicaciones/feed?limite=8'
    '&antes=2026-10-10T12%3A00%3A00.123456Z&antes_id=5';

/// Tienda del Inicio (promoción del mes, categorías y productos destacados)
/// y 6 publicaciones con otra página, promociones y sugerencias.
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
    ApiConstants.categorias: {
      'success': true,
      'categorias': [
        {'id': 1, 'nombre': 'Pasteles'},
        {'id': 2, 'nombre': 'Galletas'},
      ],
    },
    ApiConstants.productos: {
      'success': true,
      'productos': [
        {
          'id': 1,
          'nombre': 'Chocoflan',
          'descripcion': 'Rico Chocoflan',
          'precio_chico': 300,
          'categoria': 'Pasteles',
          'imagen_url': '',
          'popular': true,
          'activo': true,
          'rating': 4.5,
          'reviews': 3,
        },
      ],
    },
    ApiConstants.promocionesActivas: {
      'success': true,
      'promociones': [
        {
          'tipo': 'banner',
          'titulo_banner': 'Gran venta',
          'subtitulo_banner': 'Todo el mes',
          'fecha_fin': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
        },
      ],
    },
    ApiConstants.carrito: {'success': true, 'items': <dynamic>[]},
    ApiConstants.publicacionesPromociones: promocionesFeedJson([
      promocionFeedJson(),
    ]),
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
      for (var id = 2; id <= 6; id++)
        publicacionJson(id: id, texto: 'Publicación $id'),
    ], siguiente: cursorJson()),
    _siguiente: feedJson([publicacionJson(id: 7, texto: 'La última')]),
    ApiConstants.publicacionesSugerencias(1): sugerenciasJson([
      sugeridoJson(motivo: 'Porque te gustó Chocoflan'),
    ]),
    ApiConstants.publicacionCorazon(1): {
      'success': true,
      'me_encanta': true,
      'corazones': 4,
    },
    ApiConstants.publicacionComentarios(1): {
      'success': true,
      'comentarios': [comentarioJson()],
      'hay_mas': false,
    },
  },
);

/// Cuando abro Inicio (con o sin sesión de cliente). La vista es alta para
/// que todas las secciones existan y se puedan comparar sus posiciones.
Future<FakeApiClient> _abrirInicio(
  WidgetTester tester, {
  bool conSesion = true,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 9000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  await tester.pumpApp(const HomeScreen(), api: api);
  if (conSesion) await tester.iniciarSesion(find.byType(HomeScreen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return api;
}

double _altura(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

/// Desmonta para cancelar el carrusel y el sondeo de notificaciones.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('#175 Inicio del cliente: publicaciones primero y «Ver todo»', () {
    // Escenario: publicaciones primero
    //   Dado que inicié sesión como cliente
    //   Cuando abro Inicio
    //   Entonces veo las publicaciones justo después del carrusel y las
    //   categorías
    //   Y antes de las promociones y los productos
    testWidgets('Escenario: publicaciones primero', (tester) async {
      // Dado que inicié sesión como cliente / Cuando abro Inicio
      await _abrirInicio(tester);

      // Entonces veo las publicaciones justo después del carrusel y las
      // categorías
      final publicaciones = _altura(tester, find.text('Novedades de Pier'));
      expect(_altura(tester, find.text('Tradición en cada\nRebanada')),
          lessThan(publicaciones));
      expect(_altura(tester, find.text('Galletas')), lessThan(publicaciones));
      // Y antes de las promociones y los productos
      expect(publicaciones, lessThan(_altura(tester, find.text('Gran venta'))));
      expect(publicaciones, lessThan(_altura(tester, find.text('Destacados'))));
      await _desmontar(tester);
    });

    // Escenario: solo las más recientes
    //   Dado que hay más de 3 publicaciones
    //   Cuando abro Inicio
    //   Entonces veo las 3 más recientes y el enlace «Ver todo»
    testWidgets('Escenario: solo las más recientes', (tester) async {
      // Dado que hay más de 3 publicaciones / Cuando abro Inicio
      await _abrirInicio(tester);

      // Entonces veo las 3 más recientes y el enlace «Ver todo»
      expect(find.text('Pastel de chocolate recién salido del horno'),
          findsOneWidget);
      expect(find.text('Publicación 2'), findsOneWidget);
      expect(find.text('Publicación 3'), findsOneWidget);
      expect(find.text('Publicación 4'), findsNothing);
      expect(find.text('Ver todo'), findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: ver todas las publicaciones
    //   Cuando toco «Ver todo»
    //   Entonces se abre Novedades con todas las publicaciones, las
    //   promociones intercaladas y las sugerencias al final
    //   Y al bajar se cargan más
    testWidgets('Escenario: ver todas las publicaciones', (tester) async {
      final api = await _abrirInicio(tester);

      // Cuando toco «Ver todo»
      await tester.tap(find.text('Ver todo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Entonces se abre Novedades con todas las publicaciones, las
      // promociones intercaladas y las sugerencias al final
      expect(find.byType(NovedadesScreen), findsOneWidget);
      expect(find.text('Publicación 6'), findsOneWidget);
      expect(find.text(r'$200.00'), findsOneWidget);
      // Y al bajar se cargan más
      await tester.scrollUntilVisible(
        find.text('Te podría gustar'),
        600,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      expect(api.llamo(_siguiente), isTrue);
      expect(find.text('La última'), findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: Me encanta y comentarios desde Inicio
    //   Dado una de las 3 publicaciones de Inicio
    //   Cuando le doy «Me encanta» o abro sus comentarios
    //   Entonces funciona igual que en Novedades
    testWidgets('Escenario: Me encanta y comentarios desde Inicio', (
      tester,
    ) async {
      // Dado una de las 3 publicaciones de Inicio
      final api = await _abrirInicio(tester);

      // Cuando le doy «Me encanta»
      await tester.tap(find.byTooltip('Me encanta').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Entonces funciona igual que en Novedades
      expect(api.llamo(ApiConstants.publicacionCorazon(1), metodo: 'PUT-Auth'),
          isTrue);
      expect(find.byTooltip('Quitar me encanta'), findsOneWidget);
      expect(find.text('4'), findsWidgets);

      // Cuando abro sus comentarios / Entonces se abre la hoja de comentarios
      await tester.tap(find.text('Ver los 2 comentarios'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ComentariosSheet), findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: sin sesión
    //   Dado que no inicié sesión
    //   Cuando abro Inicio
    //   Entonces veo una invitación a entrar para ver las publicaciones
    //   Y la tienda sigue debajo
    testWidgets('Escenario: sin sesión', (tester) async {
      // Dado que no inicié sesión / Cuando abro Inicio
      final api = await _abrirInicio(tester, conSesion: false);

      // Entonces veo una invitación a entrar para ver las publicaciones
      final invitacion = _altura(tester, find.text('Lo nuevo de Pier'));
      expect(find.widgetWithText(FilledButton, 'Iniciar sesión'),
          findsOneWidget);
      expect(
        api.llamadas.any((l) => l.endpoint.startsWith('/publicaciones')),
        isFalse,
      );
      // Y la tienda sigue debajo
      expect(invitacion, lessThan(_altura(tester, find.text('Destacados'))));
      await _desmontar(tester);
    });
  });
}
