// test/unitarias/atencion/atencion_clientes_repository_test.dart —
// «Atención a clientes» (#138) sin red: el texto escapado por el backend
// vuelve a ser el que se escribió, los modelos leen el contrato de la web y
// el repositorio manda a cada PUT exactamente lo que espera el backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository_remote.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/mi_resena.dart';
import 'package:pier_reposteria/domain/models/queja.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/utils/texto_sanitizado.dart';

import '../../fakes/atencion_json.dart';
import '../../fakes/fake_api_client.dart';

void main() {
  group('decodificarSanitizado', () {
    test('deshace las entidades del sanitizador', () {
      expect(
        decodificarSanitizado(
          'Pan &amp; café &quot;Rosa&quot; &lt;3 &gt; O&#x27;Brien &#39;ok&#39;',
        ),
        'Pan & café "Rosa" <3 > O\'Brien \'ok\'',
      );
      expect(decodificarSanitizado('5&#x2F;11 &#x5C; &#96;x&#96;'), r'5/11 \ `x`');
    });

    test('en una sola pasada y sin tocar lo demás', () {
      expect(decodificarSanitizado('&amp;lt;'), '&lt;');
      expect(decodificarSanitizado('a &nbsp; b &copy;'), 'a &nbsp; b &copy;');
      expect(decodificarSanitizado('Sin escapes'), 'Sin escapes');
    });
  });

  group('QuejaPersonal', () {
    test('lee el ticket, el cliente y los textos como se escribieron', () {
      final q = QuejaPersonal.fromJson(
        quejaJson(
          id: 1,
          prioridad: 'alta',
          asunto: 'Pan &amp; café',
          respuesta: 'Lo vemos el 5&#x2F;11',
        ),
      )!;
      expect(q.id, '1');
      expect(q.ticket, 'TKT-001');
      expect(q.asunto, 'Pan & café');
      expect(q.descripcion, 'Llegó con la cobertura corrida');
      expect(q.respuesta, 'Lo vemos el 5/11');
      expect(q.prioridad, PrioridadQueja.alta);
      expect(q.estado, EstadoQueja.pendiente);
      expect(q.tipoTexto, 'Queja');
      expect(q.categoriaTexto, 'Producto');
      expect(q.cliente, 'Ana Ruiz');
      expect(q.email, 'ana@correo.mx');
      expect(q.telefono, '7711234567');
      expect(q.pedidoNumero, 'PIER-12');
      expect(q.resuelta, isFalse);
    });

    test('tolera faltantes y valores que no conoce', () {
      final q = QuejaPersonal.fromJson({
        'id': 9,
        'tipo': 'felicitacion',
        'prioridad': 'urgente',
        'estado': 'resuelto',
        'respuesta': '',
      })!;
      expect(q.ticket, '#9');
      expect(q.tipoTexto, 'felicitacion');
      expect(q.categoriaTexto, '');
      expect(q.prioridad, PrioridadQueja.media);
      expect(q.resuelta, isTrue);
      expect(q.respuesta, isNull);
      expect(q.cliente, 'Cliente');
      expect(q.pedidoNumero, isNull);
      expect(
        QuejaPersonal.fromJson(quejaJson(id: 2, estado: 'en_proceso'))!.estado,
        EstadoQueja.enProceso,
      );
      expect(QuejaPersonal.fromJson({'ticket': 'sin id'}), isNull);
      expect(QuejaPersonal.fromJson('basura'), isNull);
    });
  });

  group('ReembolsoPersonal', () {
    test('lee monto, fotos, mensajes y si es automático', () {
      final r = ReembolsoPersonal.fromJson(
        reembolsoJson(
          id: 4,
          estado: 'rechazado',
          monto: '320.50',
          fotos: ['https://res.cloudinary.com/pier/a.jpg', ' '],
          respuesta: 'Revisamos &amp; no procede',
          justificacion: 'No se ve el da&#x27;o',
          automatico: true,
        ),
      )!;
      expect(r.pedidoNumero, 'PIER-44');
      expect(r.monto, 320.5);
      expect(r.estado, EstadoReembolso.rechazado);
      expect(r.estadoTexto, 'Rechazado');
      expect(r.cliente, 'Luis Pérez');
      expect(r.telefono, '7719876543');
      expect(r.motivoTexto, 'Producto dañado');
      expect(r.descripcion, 'La caja llegó abierta & el pan duro');
      expect(r.fotos, ['https://res.cloudinary.com/pier/a.jpg']);
      expect(r.respuestaAdmin, 'Revisamos & no procede');
      expect(r.justificacionRechazo, "No se ve el da'o");
      expect(r.automatico, isTrue);
    });

    test('cada estado con su texto; «procesado» es «Devuelto»', () {
      String texto(String estado) =>
          ReembolsoPersonal.fromJson(reembolsoJson(id: 1, estado: estado))!
              .estadoTexto;
      expect(texto('pendiente'), 'Pendiente');
      expect(texto('en_revision'), 'En revisión');
      expect(texto('aprobado'), 'Aprobado');
      expect(texto('procesado'), 'Devuelto');
      expect(texto('raro'), 'Pendiente');
    });

    test('el motivo: conocido, desconocido legible o sin motivo', () {
      ReembolsoPersonal con(Map<String, dynamic> j) =>
          ReembolsoPersonal.fromJson(j)!;
      expect(con(reembolsoJson(id: 1, motivo: 'otro')).motivoTexto,
          'Otro motivo');
      expect(con(reembolsoJson(id: 1, motivo: 'caja_rota')).motivoTexto,
          'Caja rota');
      final sinNada = con({'id': 3, 'pedido_id': 77, 'fotos_evidencia': 'x'});
      expect(sinNada.motivoTexto, 'Sin motivo');
      expect(sinNada.pedidoNumero, '77');
      expect(sinNada.monto, 0);
      expect(sinNada.fotos, isEmpty);
      expect(sinNada.cliente, 'Cliente');
      expect(ReembolsoPersonal.fromJson({'monto': '10'}), isNull);
      expect(ReembolsoPersonal.fromJson(null), isNull);
    });
  });

  group('ResenaPersonal', () {
    test('lee producto, autor, estrellas, marcas y textos', () {
      final r = ResenaPersonal.fromJson(
        resenaJson(
          id: 10,
          estado: 'aprobada',
          rating: 4,
          titulo: 'Rico &amp; suave',
          respuesta: 'Gracias &amp; vuelve pronto',
          autoAprobada: true,
        ),
      )!;
      expect(r.productoNombre, 'Chocoflan');
      expect(r.autor, 'Rosa Díaz');
      expect(r.estrellas, 4);
      expect(r.titulo, 'Rico & suave');
      expect(r.comentario, 'El pan estaba duro');
      expect(r.respuestaNegocio, 'Gracias & vuelve pronto');
      expect(r.estado, EstadoResena.aprobada);
      expect(r.estadoTexto, 'Aprobada');
      expect(r.autoAprobada, isTrue);
      expect(r.verificada, isTrue);
    });

    test('pendiente: dice por qué no se publicó sola', () {
      final baja = ResenaPersonal.fromJson(resenaJson(id: 9))!;
      expect(baja.estado, EstadoResena.enRevision);
      expect(baja.estadoTexto, 'En revisión');
      expect(baja.motivoRetencion, 'Calificación baja (menos de 4 estrellas)');
      final alta = ResenaPersonal.fromJson(resenaJson(id: 9, rating: 5))!;
      expect(alta.motivoRetencion, 'Posible lenguaje inapropiado');
    });

    test('rechazada, estrellas acotadas y faltantes', () {
      final r = ResenaPersonal.fromJson({
        'id': '8',
        'estado': 'rechazada',
        'rating': '9',
        'titulo': ' ',
        'motivo_rechazo': 'Groser&#x27;as',
      })!;
      expect(r.estadoTexto, 'Rechazada');
      expect(r.estrellas, 5);
      expect(r.titulo, isNull);
      expect(r.motivoRechazo, "Groser'as");
      expect(r.productoNombre, 'Producto');
      expect(r.autor, 'Cliente');
      expect(r.comentario, '');
      expect(ResenaPersonal.fromJson({'rating': 5}), isNull);
    });
  });

  group('AtencionClientesRepositoryRemote', () {
    late FakeApiClient api;
    late AtencionClientesRepositoryRemote repo;

    setUp(() {
      api = backendAtencion();
      repo = AtencionClientesRepositoryRemote(api: api);
    });

    test('las tres listas, sin los renglones inválidos', () async {
      expect((await repo.quejas()).map((q) => q.id), ['3', '1', '2']);
      expect((await repo.reembolsos()).map((r) => r.id),
          ['5', '1', '2', '3', '4', '6']);
      expect((await repo.resenas()).map((r) => r.id), ['7', '8', '9', '10']);
      expect(api.llamo(ApiConstants.quejasPersonal, metodo: 'GET-Auth'),
          isTrue);
    });

    test('sin la lista en la respuesta devuelve vacío', () async {
      api
        ..responder(ApiConstants.quejasPersonal, {'success': true})
        ..responder(ApiConstants.reembolsosPersonal, {'success': true})
        ..responder(ApiConstants.resenasPersonal, {'success': true});
      expect(await repo.quejas(), isEmpty);
      expect(await repo.reembolsos(), isEmpty);
      expect(await repo.resenas(), isEmpty);
    });

    test('si no cargan lanza el mensaje del backend o uno propio', () async {
      api
        ..fallar(ApiConstants.quejasPersonal, 'Sin permiso')
        ..responder(ApiConstants.reembolsosPersonal, {'success': false})
        ..responder(ApiConstants.resenasPersonal, {'success': false});
      await expectLater(
        repo.quejas(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Sin permiso')),
      );
      await expectLater(
        repo.reembolsos(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'No se pudieron cargar las solicitudes de reembolso.')),
      );
      await expectLater(
        repo.resenas(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'No se pudieron cargar las reseñas.')),
      );
    });

    test('atender una queja: estado y, si la hay, la respuesta', () async {
      api.responder(ApiConstants.atenderQueja('1'), {'success': true});

      expect(
        await repo.atenderQueja('1', estado: 'resuelto', respuesta: 'Listo'),
        'Queja actualizada',
      );
      expect(api.ultima(ApiConstants.atenderQueja('1'))!.body,
          {'estado': 'resuelto', 'respuesta': 'Listo'});

      await repo.atenderQueja('1', estado: 'en_proceso');
      final llamada = api.ultima(ApiConstants.atenderQueja('1'))!;
      expect(llamada.metodo, 'PUT-Auth');
      expect(llamada.body, {'estado': 'en_proceso'});
    });

    test('un paso de reembolso manda solo lo que trae', () async {
      api.responder(ApiConstants.resolverReembolso('4'), {
        'success': true,
        'message': 'Listo',
      });

      expect(
        await repo.resolverReembolso('4',
            estado: 'rechazado', justificacionRechazo: 'No procede así'),
        'Listo',
      );
      expect(api.ultima(ApiConstants.resolverReembolso('4'))!.body,
          {'estado': 'rechazado', 'justificacion_rechazo': 'No procede así'});

      await repo.resolverReembolso('4',
          estado: 'aprobado', respuestaAdmin: 'Reembolso aprobado');
      expect(api.ultima(ApiConstants.resolverReembolso('4'))!.body,
          {'estado': 'aprobado', 'respuesta_admin': 'Reembolso aprobado'});
    });

    test('moderar o solo responder una reseña', () async {
      api.responder(ApiConstants.moderarResena('9'), {'success': true});

      expect(
        await repo.moderarResena('9',
            estado: 'rechazada', motivoRechazo: 'Lenguaje inapropiado'),
        'Reseña actualizada',
      );
      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'estado': 'rechazada', 'motivo_rechazo': 'Lenguaje inapropiado'});

      await repo.moderarResena('9', respuestaNegocio: '¡Gracias!');
      expect(api.ultima(ApiConstants.moderarResena('9'))!.body,
          {'respuesta_negocio': '¡Gracias!'});
    });

    test('si el backend rechaza el cambio lanza su mensaje', () async {
      api
        ..fallar(ApiConstants.resolverReembolso('1'),
            'Esta solicitud ya no está pendiente')
        ..responder(ApiConstants.atenderQueja('1'), {'success': false})
        ..fallar(ApiConstants.moderarResena('9'), 'Reseña no encontrada');

      await expectLater(
        repo.resolverReembolso('1', estado: 'en_revision'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Esta solicitud ya no está pendiente')),
      );
      await expectLater(
        repo.atenderQueja('1', estado: 'resuelto'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'No se pudo guardar el ticket. Intenta de nuevo.')),
      );
      await expectLater(
        repo.moderarResena('9', estado: 'aprobada'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Reseña no encontrada')),
      );
    });
  });

  group('Lo que el cliente lee de Pier, sin escapes', () {
    test('la respuesta a su queja y lo que dice de su reseña', () {
      final q = Queja.fromJson({
        'id': 1,
        'respuesta': 'Te esperamos el 5&#x2F;11 &amp; listo',
      });
      expect(q.respuesta, 'Te esperamos el 5/11 & listo');

      final mia = MiResena.fromJson({
        'id': 2,
        'respuesta_negocio': '&quot;Gracias&quot;',
        'motivo_rechazo': 'Groser&#x27;as',
      });
      expect(mia.respuestaNegocio, '"Gracias"');
      expect(mia.motivoRechazo, "Groser'as");
    });

    test('su reembolso: el mensaje y por qué se rechazó', () {
      final r = Reembolso.fromJson({
        'id': 3,
        'estado': 'rechazado',
        'respuesta_admin': 'Revisamos &amp; no procede',
        'justificacion_rechazo': 'La foto no muestra el da&#x27;o',
      });
      expect(r.respuestaAdmin, 'Revisamos & no procede');
      expect(r.justificacionRechazo, "La foto no muestra el da'o");
      expect(Reembolso.fromJson({'id': 4}).justificacionRechazo, isNull);
    });
  });
}
