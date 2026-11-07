// test/unitarias/feed/reporte_comentario_test.dart — «Reportar» el
// comentario de otro cliente en Novedades por correo (#328): a quién va, qué
// dice y en cuáles se ofrece, en la tarjeta (FeedViewModel) y en la hoja de
// comentarios (ComentariosViewModel).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/publicaciones_repository_remote.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/core/view_model/reporte_por_correo.dart';
import 'package:pier_reposteria/ui/feed/view_model/comentarios_view_model.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/view_model/reporte_comentario.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/publicaciones_json.dart';

const _textoPublicacion = 'Pastel de chocolate recién salido del horno';

ComentarioPublicacion _comentario({
  int id = 10,
  String texto = '¡Se ve delicioso!',
  String autor = 'Carla C.',
  bool oficial = false,
  bool tuyo = false,
}) => ComentarioPublicacion.fromJson(
  comentarioJson(
    id: id,
    texto: texto,
    autor: autor,
    oficial: oficial,
    tuyo: tuyo,
  ),
);

Uri _correo({
  ComentarioPublicacion? comentario,
  String? publicacionTexto = _textoPublicacion,
  String? emailContacto,
}) => ReporteComentario.correo(
  comentario: comentario ?? _comentario(),
  publicacionId: 1,
  publicacionTexto: publicacionTexto,
  emailContacto: emailContacto,
);

/// Un renglón del cuerpo del correo que empieza con [inicio].
String _renglon(Uri correo, String inicio) => correo.queryParameters['body']!
    .split('\n')
    .firstWhere((l) => l.startsWith(inicio));

/// La dirección de contacto que ya llegó del servidor, guardada.
void _guardarContacto(String email) => SharedPreferences.setMockInitialValues({
  'pierreposteria_contacto_v1': jsonEncode({'email': email}),
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReporteComentario.correo', () {
    test('va al contacto del negocio con el asunto del comentario', () {
      final correo = _correo(emailContacto: 'hola@pier.mx');

      expect(correo.scheme, 'mailto');
      expect(correo.path, 'hola@pier.mx');
      expect(
        correo.queryParameters['subject'],
        'Reportar comentario #10 de la publicación #1',
      );
    });

    test('sin correo en la configuración usa el de respaldo', () {
      expect(_correo().path, BusinessInfo.email);
      expect(_correo(emailContacto: '   ').path, BusinessInfo.email);
    });

    test('el cuerpo trae la publicación, el comentario y la línea del '
        'motivo', () {
      final cuerpo = _correo().queryParameters['body']!;

      expect(cuerpo, startsWith('Hola, Pier:'));
      expect(cuerpo, contains('Quiero reportar este comentario de la app.'));
      expect(cuerpo, contains('Publicación: #1 «$_textoPublicacion»'));
      expect(cuerpo, contains('Comentario: #10'));
      expect(cuerpo, contains('Autor: Carla C.'));
      expect(cuerpo, contains('Fecha: 12/10/2026'));
      expect(cuerpo, contains('Texto: ¡Se ve delicioso!'));
      expect(cuerpo.trimRight(), endsWith('Motivo:'));
    });

    test('de la publicación va solo el inicio, en un renglón', () {
      final larga = 'Hoy horneamos\n\n${'chocolate ' * 20}';
      final publicacion = _renglon(
        _correo(publicacionTexto: larga),
        'Publicación: ',
      );
      final inicio = publicacion.substring(
        'Publicación: #1 «'.length,
        publicacion.length - '»'.length,
      );

      expect(inicio, startsWith('Hoy horneamos chocolate'));
      expect(inicio, endsWith('…'));
      expect(
        inicio.runes.length,
        lessThanOrEqualTo(ReporteComentario.maxTextoPublicacion + 1),
      );
    });

    test('publicación sin texto (solo fotos): solo su número', () {
      expect(
        _renglon(_correo(publicacionTexto: null), 'Publicación: '),
        'Publicación: #1',
      );
      expect(
        _renglon(_correo(publicacionTexto: '  '), 'Publicación: '),
        'Publicación: #1',
      );
    });

    test('sin autor ni fecha no inventa datos', () {
      final comentario = ComentarioPublicacion.fromJson({
        'id': 5,
        'texto': 'Hola',
      });
      final correo = _correo(comentario: comentario);

      expect(_renglon(correo, 'Autor: '), 'Autor: Sin nombre');
      expect(_renglon(correo, 'Fecha: '), 'Fecha: Sin fecha');
    });

    test('recorta el comentario largo a 500 caracteres con «…»', () {
      final largo = 'a' * 499 + '😀' * 10;
      final texto = _renglon(
        _correo(comentario: _comentario(texto: largo)),
        'Texto: ',
      ).substring('Texto: '.length);

      expect(texto.runes.length, ReportePorCorreo.maxTexto + 1);
      expect(texto, endsWith('😀…'));
    });

    test('los espacios van como %20, no como «+»', () {
      final texto = _correo().toString();

      expect(texto, contains('subject=Reportar%20comentario%20%2310'));
      expect(texto, isNot(contains('+')));
    });

    test('el aviso sin app de correo dice a dónde escribir', () {
      expect(
        ReporteComentario.sinAppDeCorreo('hola@pier.mx'),
        'No encontramos una app de correo. Escribe a hola@pier.mx para '
        'reportar el comentario.',
      );
    });
  });

  group('ReporteComentario.esDeOtroCliente', () {
    test('el de otro cliente sí', () {
      expect(ReporteComentario.esDeOtroCliente(_comentario()), isTrue);
    });

    test('el propio no', () {
      expect(
        ReporteComentario.esDeOtroCliente(_comentario(tuyo: true)),
        isFalse,
      );
    });

    test('la respuesta de Pier no: es de la marca, como la publicación', () {
      expect(
        ReporteComentario.esDeOtroCliente(_comentario(oficial: true)),
        isFalse,
      );
    });

    test('si se puede borrar no (lo borra en lugar de reportarlo)', () {
      final json = comentarioJson()..['puede_borrar'] = true;

      expect(
        ReporteComentario.esDeOtroCliente(ComentarioPublicacion.fromJson(json)),
        isFalse,
      );
    });

    test('si no se sabe de quién es, no se ofrece', () {
      final sinAutor = ComentarioPublicacion.fromJson({'id': 3, 'texto': 'x'});
      final sinDueno = ComentarioPublicacion.fromJson({
        'id': 4,
        'texto': 'x',
        'autor': {'nombre': 'Carla C.'},
      });

      expect(sinAutor.esTuyo, isNull);
      expect(sinDueno.esTuyo, isNull);
      expect(ReporteComentario.esDeOtroCliente(sinAutor), isFalse);
      expect(ReporteComentario.esDeOtroCliente(sinDueno), isFalse);
    });
  });

  group('ReporteComentario.correoConContacto', () {
    test('usa el contacto guardado en el teléfono', () async {
      _guardarContacto('hola@pier.mx');
      final correo = await ReporteComentario.correoConContacto(
        ConfiguracionRepositoryRemote(api: FakeApiClient()),
        comentario: _comentario(),
        publicacionId: 1,
      );

      expect(correo.path, 'hola@pier.mx');
      expect(_renglon(correo, 'Publicación: '), 'Publicación: #1');
    });

    test('sin repositorio, el de respaldo', () async {
      final correo = await ReporteComentario.correoConContacto(
        null,
        comentario: _comentario(),
        publicacionId: 1,
      );

      expect(correo.path, BusinessInfo.email);
    });
  });

  group('ComentariosViewModel: «Reportar»', () {
    late FakeApiClient api;

    setUp(() {
      api = FakeApiClient()
        ..responder('/publicaciones/1/comentarios?limite=20', {
          'success': true,
          'comentarios': [
            comentarioJson(id: 10),
            comentarioJson(id: 11, texto: 'Mío', tuyo: true),
            comentarioJson(id: 12, autor: 'Pier Repostería', oficial: true),
          ],
          'hay_mas': false,
        });
    });

    ComentariosViewModel hoja() => ComentariosViewModel(
      repo: PublicacionesRepositoryRemote(api: api),
      publicacionId: 1,
      publicacionTexto: _textoPublicacion,
      configRepo: ConfiguracionRepositoryRemote(api: api),
    );

    test('solo en los de otros clientes', () async {
      final vm = hoja();
      addTearDown(vm.dispose);
      await vm.cargar();

      expect(vm.comentarios.map(vm.puedeReportar).toList(), [
        true,
        false,
        false,
      ]);
    });

    test('arma el correo con la publicación y el contacto guardado', () async {
      _guardarContacto('hola@pier.mx');
      final vm = hoja();
      addTearDown(vm.dispose);
      await vm.cargar();

      final correo = await vm.correoParaReportar(vm.comentarios.first);

      expect(correo.path, 'hola@pier.mx');
      expect(
        correo.queryParameters['subject'],
        'Reportar comentario #10 de la publicación #1',
      );
      expect(
        _renglon(correo, 'Publicación: '),
        'Publicación: #1 «$_textoPublicacion»',
      );
    });
  });

  group('FeedViewModel: «Reportar»', () {
    late FakeApiClient api;

    setUp(() {
      api = FakeApiClient()
        ..responder('/publicaciones/promociones', promocionesFeedJson(const []))
        ..responder(
          '/publicaciones/feed?limite=8',
          feedJson([
            publicacionJson(
              totalComentarios: 2,
              comentarios: [
                comentarioJson(id: 10),
                comentarioJson(id: 11, texto: 'Mío', tuyo: true),
              ],
            ),
          ]),
        );
    });

    test('solo en los comentarios recientes de otros clientes', () async {
      final vm = FeedViewModel(repo: PublicacionesRepositoryRemote(api: api));
      addTearDown(vm.dispose);
      await vm.cargar();

      final recientes = vm.recientes.single.comentariosRecientes;
      expect(recientes.map(vm.puedeReportar).toList(), [true, false]);
    });

    test('arma el correo con la publicación de la tarjeta', () async {
      _guardarContacto('hola@pier.mx');
      final vm = FeedViewModel(
        repo: PublicacionesRepositoryRemote(api: api),
        configRepo: ConfiguracionRepositoryRemote(api: api),
      );
      addTearDown(vm.dispose);
      await vm.cargar();
      final publicacion = vm.recientes.single;

      final correo = await vm.correoParaReportar(
        publicacion,
        publicacion.comentariosRecientes.first,
      );

      expect(correo.path, 'hola@pier.mx');
      expect(
        correo.queryParameters['subject'],
        'Reportar comentario #10 de la publicación #1',
      );
      expect(
        _renglon(correo, 'Publicación: '),
        'Publicación: #1 «$_textoPublicacion»',
      );
    });

    test('sin repositorio de configuración, al de respaldo', () async {
      final vm = FeedViewModel(repo: PublicacionesRepositoryRemote(api: api));
      addTearDown(vm.dispose);
      await vm.cargar();
      final publicacion = vm.recientes.single;

      final correo = await vm.correoParaReportar(
        publicacion,
        publicacion.comentariosRecientes.first,
      );

      expect(correo.path, BusinessInfo.email);
    });
  });
}
