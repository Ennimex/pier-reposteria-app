// test/widget/feed/reportar_comentario_test.dart — «Reportar» en los
// comentarios de otros clientes de Novedades (#328): en la hoja de
// comentarios y en los recientes de la tarjeta (también en el Inicio), no en
// el propio ni en la respuesta de Pier; abre el correo ya escrito y, sin app
// de correo, dice a dónde escribir dentro de la hoja.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/ui/core/ui/boton_reportar.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/view_model/reporte_comentario.dart';
import 'package:pier_reposteria/ui/feed/widgets/comentarios_sheet.dart';
import 'package:pier_reposteria/ui/feed/widgets/feed_sliver.dart';
import 'package:pier_reposteria/ui/feed/widgets/tarjeta_publicacion.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';
import '../../helpers/montar_comandas.dart' show capturarUrls;
import '../../helpers/pump_app.dart';

const _feed = '/publicaciones/feed?limite=8';
const _deOtro = '¡Se ve delicioso!';
const _textoPublicacion = 'Pastel de chocolate recién salido del horno';

/// La dirección de contacto que ya llegó del servidor, guardada.
final _contactoGuardado = <String, Object>{
  'pierreposteria_contacto_v1': jsonEncode({'email': 'hola@pier.mx'}),
};

/// Una publicación con dos comentarios recientes: el 10 de otro cliente y el
/// 11 del cliente con sesión. En la hoja, además, la respuesta de Pier.
FakeApiClient _backend() => FakeApiClient()
  ..responder(ApiConstants.login, {
    'success': true,
    'token': 'jwt',
    'user': {
      'id': 1,
      'nombre': 'Ana',
      'email': 'ana@pier.mx',
      'rol': 'cliente',
    },
  })
  ..responder(ApiConstants.carrito, {'success': true, 'items': <dynamic>[]})
  ..responder('/publicaciones/promociones', promocionesFeedJson(const []))
  ..responder(
    _feed,
    feedJson([
      publicacionJson(
        totalComentarios: 3,
        comentarios: [
          comentarioJson(id: 10),
          comentarioJson(id: 11, texto: 'Mío', autor: 'Ana G.', tuyo: true),
        ],
      ),
    ]),
  )
  ..responder('/publicaciones/sugerencias?pagina=1', sugerenciasJson(const []))
  ..responder('/publicaciones/1/comentarios?limite=20', {
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
    'hay_mas': false,
  });

/// Monta solo el feed (como interaccion_screen_test), con [preferencias]
/// guardadas en el teléfono.
Future<void> _montar(
  WidgetTester tester, {
  Map<String, Object> preferencias = const {},
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  final vm = FeedViewModel(
    repo: PublicacionesRepositoryRemote(api: api),
    configRepo: ConfiguracionRepositoryRemote(api: api),
  );
  addTearDown(vm.dispose);
  await vm.cargar();
  await tester.pumpApp(
    Scaffold(
      body: CustomScrollView(
        slivers: [FeedSliver(viewModel: vm, alAgregar: (_, _) async {})],
      ),
    ),
    api: api,
    preferencias: preferencias,
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirComentarios(WidgetTester tester) async {
  await tester.tap(find.text('Ver los 3 comentarios'));
  await tester.pumpAndSettle();
}

/// [buscado] dentro de la hoja de comentarios (atrás sigue la tarjeta).
Finder _enLaHoja(Finder buscado) =>
    find.descendant(of: find.byType(ComentariosSheet), matching: buscado);

/// El «Reportar» del comentario donde está [texto].
Finder _reportarDe(Finder texto) => find.descendant(
  of: find.ancestor(of: texto, matching: find.byType(ComentarioBreve)),
  matching: find.text(BotonReportar.etiqueta),
);

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Uri _correoAbierto(List<Object?> urls) => Uri.parse(urls.single! as String);

void main() {
  group('En la hoja de comentarios', () {
    testWidgets('solo en los de otros clientes: no en el propio ni en la '
        'respuesta de Pier', (tester) async {
      await _montar(tester);

      await _abrirComentarios(tester);

      expect(_enLaHoja(find.text(BotonReportar.etiqueta)), findsOneWidget);
      expect(
        _reportarDe(_enLaHoja(find.text(_deOtro))),
        findsOneWidget,
      );
      expect(_reportarDe(_enLaHoja(find.text('Mío'))), findsNothing);
      expect(
        _reportarDe(_enLaHoja(find.text('¡Gracias!'))),
        findsNothing,
      );
      expect(
        _enLaHoja(find.byTooltip('Eliminar comentario')),
        findsOneWidget,
        reason: 'el propio conserva su bote de basura',
      );
    });

    testWidgets('al tocarlo abre el correo ya escrito, al contacto '
        'guardado', (tester) async {
      final urls = capturarUrls(tester);
      await _montar(tester, preferencias: _contactoGuardado);
      await _abrirComentarios(tester);

      await _tocar(tester, _reportarDe(_enLaHoja(find.text(_deOtro))));

      final correo = _correoAbierto(urls);
      expect(correo.scheme, 'mailto');
      expect(correo.path, 'hola@pier.mx');
      expect(
        correo.queryParameters['subject'],
        'Reportar comentario #10 de la publicación #1',
      );
      final cuerpo = correo.queryParameters['body'];
      expect(cuerpo, contains('Publicación: #1 «$_textoPublicacion»'));
      expect(cuerpo, contains('Comentario: #10'));
      expect(cuerpo, contains('Texto: $_deOtro'));
      expect(
        find.text(ReporteComentario.sinAppDeCorreo('hola@pier.mx')),
        findsNothing,
      );
    });

    testWidgets('sin app de correo dice a dónde escribir, dentro de la '
        'hoja', (tester) async {
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      final mensajero = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(canal, (_) async => false);
      addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
      await _montar(tester);
      await _abrirComentarios(tester);

      await _tocar(tester, _reportarDe(_enLaHoja(find.text(_deOtro))));

      // Se puede tocar: no quedó tapado por la hoja
      expect(
        find
            .text(ReporteComentario.sinAppDeCorreo(BusinessInfo.email))
            .hitTestable(),
        findsOneWidget,
      );
    });
  });

  group('En la tarjeta', () {
    testWidgets('solo en el comentario reciente de otro cliente', (
      tester,
    ) async {
      await _montar(tester);

      expect(find.text(BotonReportar.etiqueta), findsOneWidget);
      expect(_reportarDe(find.text(_deOtro)), findsOneWidget);
      expect(_reportarDe(find.text('Mío')), findsNothing);
    });

    testWidgets('al tocarlo abre el correo con la publicación', (
      tester,
    ) async {
      final urls = capturarUrls(tester);
      await _montar(tester, preferencias: _contactoGuardado);

      await _tocar(tester, find.text(BotonReportar.etiqueta));

      final correo = _correoAbierto(urls);
      expect(correo.path, 'hola@pier.mx');
      expect(
        correo.queryParameters['subject'],
        'Reportar comentario #10 de la publicación #1',
      );
      expect(
        correo.queryParameters['body'],
        contains('Publicación: #1 «$_textoPublicacion»'),
      );
    });
  });

  testWidgets('en el Inicio también, al contacto guardado', (tester) async {
    final urls = capturarUrls(tester);
    // Ancha como las demás pruebas del Inicio (feed_inicio_test)
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      const HomeScreen(),
      api: _backend(),
      preferencias: _contactoGuardado,
    );
    await tester.iniciarSesion(find.byType(HomeScreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final reportar = find.text(BotonReportar.etiqueta);
    await tester.scrollUntilVisible(
      reportar,
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    await tester.tap(reportar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(reportar, findsOneWidget);
    expect(_correoAbierto(urls).path, 'hola@pier.mx');

    // Desmonta para cancelar el carrusel y el sondeo de notificaciones
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
