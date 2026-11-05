// test/unitarias/resenas/reporte_resena_test.dart — «Reportar» la reseña de
// otro cliente por correo (#328): a quién va, qué dice y en cuáles se ofrece.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';
import 'package:pier_reposteria/ui/reviews/view_model/reporte_resena.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

ResenaProducto _resena({
  String id = '7',
  String comentario = 'Llegó aplastado y nadie respondió',
  String titulo = 'Mala experiencia',
  String usuarioId = '',
}) =>
    ResenaProducto(
      id: id,
      rating: 2,
      titulo: titulo,
      comentario: comentario,
      verificada: false,
      utilCount: 0,
      autorNombre: 'Luis',
      autorApellido: 'Pérez',
      creadaEn: DateTime(2026, 11, 3, 10),
      usuarioId: usuarioId,
    );

Uri _correo({ResenaProducto? resena, String? emailContacto}) =>
    ReporteResena.correo(
      resena: resena ?? _resena(),
      productoId: '36',
      productoNombre: 'Fresa Matcha Bliss',
      emailContacto: emailContacto,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReporteResena.correo', () {
    test('va al contacto del negocio con el asunto de la reseña', () {
      final correo = _correo(emailContacto: 'hola@pier.mx');

      expect(correo.scheme, 'mailto');
      expect(correo.path, 'hola@pier.mx');
      expect(correo.queryParameters['subject'],
          'Reportar reseña #7 de Fresa Matcha Bliss');
    });

    test('sin correo en la configuración usa el de respaldo', () {
      expect(_correo().path, BusinessInfo.email);
      expect(_correo(emailContacto: '   ').path, BusinessInfo.email);
    });

    test('el cuerpo trae el producto, la reseña y la línea del motivo', () {
      final cuerpo = _correo().queryParameters['body']!;

      expect(cuerpo, contains('Producto: Fresa Matcha Bliss (id 36)'));
      expect(cuerpo, contains('Reseña: #7'));
      expect(cuerpo, contains('Autor: Luis P.'));
      expect(cuerpo, contains('Fecha: 03/11/2026'));
      expect(cuerpo, contains('Estrellas: 2 de 5'));
      expect(cuerpo, contains('Título: Mala experiencia'));
      expect(cuerpo, contains('Texto: Llegó aplastado y nadie respondió'));
      expect(cuerpo.trimRight(), endsWith('Motivo:'));
    });

    test('sin título, autor ni fecha no inventa datos', () {
      final resena = ResenaProducto(
        id: '9',
        rating: 5,
        titulo: '',
        comentario: 'Rico',
        verificada: true,
        utilCount: 0,
        autorNombre: '',
        autorApellido: '',
      );
      final cuerpo = _correo(resena: resena).queryParameters['body']!;

      expect(cuerpo, isNot(contains('Título:')));
      expect(cuerpo, contains('Autor: Sin nombre'));
      expect(cuerpo, contains('Fecha: Sin fecha'));
    });

    test('los espacios van como %20, no como «+»', () {
      final texto = _correo().toString();

      expect(texto, contains('subject=Reportar%20rese%C3%B1a%20%237'));
      expect(texto, isNot(contains('+')));
    });

    test('recorta el texto largo a 500 caracteres con «…»', () {
      final largo = 'a' * 499 + '😀' * 10;
      final cuerpo = _correo(resena: _resena(comentario: largo))
          .queryParameters['body']!;
      final texto = cuerpo
          .split('\n')
          .firstWhere((l) => l.startsWith('Texto: '))
          .substring('Texto: '.length);

      expect(texto.runes.length, ReporteResena.maxTexto + 1);
      expect(texto, endsWith('😀…'));
      expect(ReporteResena.recortar('  corto  '), 'corto');
    });

    test('el aviso sin app de correo dice a dónde escribir', () {
      expect(ReporteResena.sinAppDeCorreo('hola@pier.mx'),
          contains('Escribe a hola@pier.mx'));
    });
  });

  group('ReporteResena.esDeOtroCliente', () {
    test('sin sesión todas son de otros', () {
      expect(
          ReporteResena.esDeOtroCliente(autorId: '', conSesion: false), isTrue);
    });

    test('con sesión, solo las de otro autor conocido', () {
      bool deOtro(String autor, String? yo) => ReporteResena.esDeOtroCliente(
          autorId: autor, conSesion: true, usuarioSesion: yo);

      expect(deOtro('8', '7'), isTrue);
      expect(deOtro('7', '7'), isFalse);
      expect(deOtro('', '7'), isFalse);
      expect(deOtro('8', null), isFalse);
    });
  });

  group('ReporteResena.correoConContacto', () {
    test('usa el contacto guardado en el teléfono', () async {
      SharedPreferences.setMockInitialValues({
        'pierreposteria_contacto_v1': jsonEncode({'email': 'hola@pier.mx'}),
      });
      final correo = await ReporteResena.correoConContacto(
        ConfiguracionRepositoryRemote(api: FakeApiClient()),
        resena: _resena(),
        productoId: '36',
        productoNombre: 'Fresa Matcha Bliss',
      );

      expect(correo.path, 'hola@pier.mx');
    });

    test('sin contacto guardado, el de respaldo', () async {
      final correo = await ReporteResena.correoConContacto(
        ConfiguracionRepositoryRemote(api: FakeApiClient()),
        resena: _resena(),
        productoId: '36',
        productoNombre: 'Fresa Matcha Bliss',
      );

      expect(correo.path, BusinessInfo.email);
    });
  });

  group('ProductReviewsViewModel: «Reportar»', () {
    FakeApiClient api() => FakeApiClient(respuestas: {
          ApiConstants.resenasPorProducto('36'): {
            'success': true,
            'resenas': [
              {'id': 1, 'rating': 5, 'comentario': 'Mía'},
              {'id': 2, 'rating': 4, 'comentario': 'De otro'},
            ],
          },
        });

    ProductReviewsViewModel vm(FakeApiClient api) => ProductReviewsViewModel(
          repo: ResenasRepositoryRemote(api: api),
          productoId: '36',
          configRepo: ConfiguracionRepositoryRemote(api: api),
        );

    test('sin sesión se ofrece en todas', () async {
      final modelo = vm(api());
      await modelo.cargar();

      expect(modelo.puedeReportar('1'), isTrue);
      expect(modelo.puedeReportar('2'), isTrue);
    });

    test('con sesión, no en las del cliente', () async {
      final fake = api()
        ..responder(ApiConstants.misResenas, {
          'success': true,
          'resenas': [
            {'id': 1, 'estado': 'aprobada', 'producto_nombre': 'Fresa'},
          ],
        });
      final modelo = vm(fake);
      await modelo.cargar(conSesion: true);

      expect(modelo.puedeReportar('1'), isFalse);
      expect(modelo.puedeReportar('2'), isTrue);
    });

    test('con sesión, si no se supo cuáles son suyas, en ninguna', () async {
      final modelo = vm(api());
      await modelo.cargar(conSesion: true);

      expect(modelo.puedeReportar('1'), isFalse);
      expect(modelo.puedeReportar('2'), isFalse);
    });

    test('arma el correo con el producto', () async {
      final modelo = vm(api());
      await modelo.cargar();
      final correo = await modelo.correoParaReportar(modelo.resenas.last,
          productoNombre: 'Fresa Matcha Bliss');

      expect(correo.queryParameters['subject'],
          'Reportar reseña #2 de Fresa Matcha Bliss');
      expect(correo.path, BusinessInfo.email);
    });
  });

  group('ProductDetailViewModel: «Reportar»', () {
    final pastel = Product(
      id: '36',
      nombre: 'Fresa Matcha Bliss',
      precio: 320,
      imagenUrl: '',
      descripcion: '',
      categoria: 'Pasteles',
    );

    ProductDetailViewModel detalle(FakeApiClient api) => ProductDetailViewModel(
          producto: pastel,
          productosRepo: ProductosRepositoryRemote(api: api),
          favoritosRepo: FavoritosRepositoryRemote(api: api),
          resenasRepo: ResenasRepositoryRemote(api: api),
          demandaRepo: DemandaRepositoryRemote(api: api),
          configRepo: ConfiguracionRepositoryRemote(api: api),
        );

    test('sin sesión se ofrece en todas', () async {
      final vm = detalle(FakeApiClient());
      await vm.cargar(autenticado: false);

      expect(vm.puedeReportar(_resena(usuarioId: '5')), isTrue);
      vm.dispose();
    });

    test('con sesión, no en la propia ni en la de autor desconocido',
        () async {
      final vm = detalle(FakeApiClient());
      await vm.cargar(autenticado: true, usuarioId: '5');

      expect(vm.puedeReportar(_resena(usuarioId: '5')), isFalse);
      expect(vm.puedeReportar(_resena()), isFalse);
      expect(vm.puedeReportar(_resena(usuarioId: '6')), isTrue);
      vm.dispose();
    });

    test('arma el correo con el producto del detalle', () async {
      final vm = detalle(FakeApiClient());
      final correo = await vm.correoParaReportar(_resena());

      expect(correo.queryParameters['subject'],
          'Reportar reseña #7 de Fresa Matcha Bliss');
      expect(correo.queryParameters['body'],
          contains('Producto: Fresa Matcha Bliss (id 36)'));
      vm.dispose();
    });
  });

  test('ResenaProducto lee quién la escribió (detalle del producto)', () {
    final r = ResenaProducto.fromJson({'id': 3, 'usuario_id': 12});

    expect(r.usuarioId, '12');
    expect(r.copyWith(utilCount: 4).usuarioId, '12');
    expect(ResenaProducto.fromJson({'id': 3}).usuarioId, '');
  });
}
