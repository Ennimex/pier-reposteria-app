// test/unit/repositories_remote_test.dart — implementaciones Remote que no
// tenían pruebas propias (MVVM, Fase 3.5): cada método pega al endpoint con
// el método y body correctos y devuelve la respuesta del ApiClient tal cual.
// Sin red: FakeApiClient registra cada llamada.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';
import '../fakes/fake_google_sign_in.dart';

const _ok = {'success': true};

/// Fake que contesta `{success: true}` en todos los [endpoints].
FakeApiClient _apiOk(List<String> endpoints) =>
    FakeApiClient(respuestas: {for (final e in endpoints) e: _ok});

void main() {
  group('DemandaRepositoryRemote', () {
    Future<void> esperar() => Future<void>.delayed(Duration.zero);

    test('recorta la búsqueda a 120 caracteres e ignora las muy cortas',
        () async {
      final api = _apiOk([ApiConstants.busquedas]);
      DemandaRepositoryRemote(api: api)
        ..registrarBusqueda(' x ', 0)
        ..registrarBusqueda('a' * 130, 0);
      await esperar();

      final llamadas =
          api.llamadas.where((l) => l.endpoint == ApiConstants.busquedas);
      expect(llamadas, hasLength(1));
      expect((llamadas.single.body!['texto'] as String).length, 120);
    });

    test('el clic en agotado manda el id numérico e ignora los demás',
        () async {
      final api = _apiOk([ApiConstants.clicsAgotados]);
      DemandaRepositoryRemote(api: api)
        ..registrarClicAgotado('abc')
        ..registrarClicAgotado('12');
      await esperar();

      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 12});
      expect(api.llamadas, hasLength(1));
    });

    test('si el envío truena no se propaga el error', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.busquedas: (LlamadaApi _) => throw StateError('sin red'),
      });
      DemandaRepositoryRemote(api: api).registrarBusqueda('fresa', 2);
      await esperar();
      expect(api.llamo(ApiConstants.busquedas), isTrue);
    });
  });

  group('DireccionesRepositoryRemote', () {
    test('listar, crear, actualizar y eliminar van autenticados', () async {
      final api = _apiOk([
        ApiConstants.direcciones,
        ApiConstants.direccionById('3'),
      ]);
      final repo = DireccionesRepositoryRemote(api: api);
      final body = {'calle': 'Hidalgo 12', 'colonia': 'Centro'};

      expect((await repo.listar())['success'], isTrue);
      await repo.crear(body);
      await repo.actualizar('3', body);
      await repo.eliminar('3');

      expect(api.llamo(ApiConstants.direcciones, metodo: 'GET-Auth'), isTrue);
      expect(api.llamo(ApiConstants.direcciones, metodo: 'POST-Auth'), isTrue);
      expect(api.ultima(ApiConstants.direcciones)!.body, body);
      expect(
        api.llamo(ApiConstants.direccionById('3'), metodo: 'PUT-Auth'),
        isTrue,
      );
      expect(
        api.llamo(ApiConstants.direccionById('3'), metodo: 'DELETE-Auth'),
        isTrue,
      );
    });

    test('colonias es pública', () async {
      final api = _apiOk([ApiConstants.zonasColonias]);
      await DireccionesRepositoryRemote(api: api).colonias();
      expect(api.llamo(ApiConstants.zonasColonias, metodo: 'GET'), isTrue);
    });
  });

  group('EntregasRepositoryRemote', () {
    test('consultas del repartidor van con GET autenticado', () async {
      final api = _apiOk([
        ApiConstants.misEntregas,
        ApiConstants.disponibilidad,
        ApiConstants.entregasDisponibles,
      ]);
      final repo = EntregasRepositoryRemote(api: api);

      await repo.misEntregas();
      await repo.disponibilidad();
      await repo.disponibles();

      for (final e in [
        ApiConstants.misEntregas,
        ApiConstants.disponibilidad,
        ApiConstants.entregasDisponibles,
      ]) {
        expect(api.llamo(e, metodo: 'GET-Auth'), isTrue, reason: e);
      }
    });

    test('cambiar disponibilidad, aceptar, estado y llegada mandan su body',
        () async {
      final api = _apiOk([
        ApiConstants.disponibilidad,
        ApiConstants.entregasAceptar,
        ApiConstants.entregaEstado('9'),
        ApiConstants.entregaLlegue('9'),
      ]);
      final repo = EntregasRepositoryRemote(api: api);

      await repo.cambiarDisponibilidad(disponible: true);
      await repo.aceptar('41');
      await repo.cambiarEstado('9', EstadoEntrega.enCamino);
      await repo.avisarLlegada('9');

      final disp = api.ultima(ApiConstants.disponibilidad)!;
      expect(disp.metodo, 'PUT-Auth');
      expect(disp.body, {'disponible': true});
      expect(api.ultima(ApiConstants.entregasAceptar)!.body, {'pedido_id': '41'});
      expect(
        api.ultima(ApiConstants.entregaEstado('9'))!.body,
        {'estado': 'en_camino'},
      );
      expect(
        api.llamo(ApiConstants.entregaLlegue('9'), metodo: 'POST-Auth'),
        isTrue,
      );
    });

    test('subirEvidencia sube la foto marcada como entrega', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.uploadImagen: {
          'success': true,
          'imagen': {'url': 'https://cdn/foto.jpg'},
        },
      });
      await EntregasRepositoryRemote(api: api).subirEvidencia('/tmp/foto.jpg');

      final subida = api.ultima(ApiConstants.uploadImagen)!;
      expect(subida.metodo, 'UPLOAD');
      expect(subida.body, {'filePath': '/tmp/foto.jpg', 'tipo': 'entrega'});
    });
  });

  group('PagosRepositoryRemote', () {
    test('config es pública; intent y confirmación van autenticados',
        () async {
      final api = _apiOk([
        ApiConstants.stripeConfig,
        ApiConstants.crearPaymentIntent,
        ApiConstants.confirmarPago,
      ]);
      final repo = PagosRepositoryRemote(api: api);

      await repo.config();
      await repo.crearIntent({'monto': 350});
      await repo.confirmar({'payment_intent_id': 'pi_1'});

      expect(api.llamo(ApiConstants.stripeConfig, metodo: 'GET'), isTrue);
      expect(api.ultima(ApiConstants.crearPaymentIntent)!.body, {'monto': 350});
      expect(
        api.ultima(ApiConstants.confirmarPago)!.body,
        {'payment_intent_id': 'pi_1'},
      );
    });
  });

  group('NotificacionesRepositoryRemote', () {
    test('listar y marcar leídas', () async {
      final api = _apiOk([
        ApiConstants.notificaciones,
        ApiConstants.marcarNotificacionLeida('5'),
        ApiConstants.notificacionesLeerTodas,
      ]);
      final repo = NotificacionesRepositoryRemote(api: api);

      await repo.listar();
      await repo.marcarLeida('5');
      await repo.marcarTodasLeidas();

      expect(api.llamo(ApiConstants.notificaciones, metodo: 'GET-Auth'), isTrue);
      expect(
        api.llamo(ApiConstants.marcarNotificacionLeida('5'), metodo: 'PUT-Auth'),
        isTrue,
      );
      expect(
        api.llamo(ApiConstants.notificacionesLeerTodas, metodo: 'PUT-Auth'),
        isTrue,
      );
    });
  });

  group('ProductosRepositoryRemote', () {
    test('detalle, recomendaciones y promociones son públicas',
        () async {
      final endpoints = [
        ApiConstants.productoById('8'),
        ApiConstants.recomendaciones('8'),
        ApiConstants.promocionesActivas,
      ];
      final api = _apiOk(endpoints);
      final repo = ProductosRepositoryRemote(api: api);

      await repo.detalle('8');
      await repo.recomendaciones('8');
      await repo.promocionesActivas();

      for (final e in endpoints) {
        expect(api.llamo(e, metodo: 'GET'), isTrue, reason: e);
      }
    });
  });

  group('PedidosRepositoryRemote', () {
    test('detalle y productos comprados van autenticados', () async {
      final api = _apiOk([
        ApiConstants.pedidoById('7'),
        ApiConstants.productosComprados,
      ]);
      final repo = PedidosRepositoryRemote(api: api);

      await repo.detalle('7');
      await repo.productosComprados();

      expect(api.llamo(ApiConstants.pedidoById('7'), metodo: 'GET-Auth'), isTrue);
      expect(
        api.llamo(ApiConstants.productosComprados, metodo: 'GET-Auth'),
        isTrue,
      );
    });
  });

  group('AuthRepositoryRemote', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const usuario = {'id': 1, 'nombre': 'Ana', 'rol': 'cliente'};

    test('login exitoso guarda token y usuario', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.login: {'success': true, 'token': 'jwt', 'user': usuario},
      });
      final repo = AuthRepositoryRemote(api: api);

      final u = await repo.iniciarSesion(email: 'ana@pier.mx', password: 'secreta');

      expect(u, usuario);
      expect(api.ultima(ApiConstants.login)!.body,
          {'email': 'ana@pier.mx', 'password': 'secreta'});
      expect(await repo.isAuthenticated(), isTrue);
      expect(await repo.getCurrentUser(), usuario);
    });

    test('login rechazado lanza ApiException y no guarda sesión', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      final repo = AuthRepositoryRemote(api: api);

      await expectLater(
        repo.iniciarSesion(email: 'ana@pier.mx', password: 'mala'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Credenciales inválidas')),
      );
      expect(await repo.isAuthenticated(), isFalse);
    });

    test('sin mensaje ni usuario, usa el mensaje genérico', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.login: {'success': false},
        ApiConstants.verifyEmail: {'success': true},
      });
      final repo = AuthRepositoryRemote(api: api);

      await expectLater(
        repo.iniciarSesion(email: 'ana@pier.mx', password: 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Error al iniciar sesión')),
      );
      await expectLater(
        repo.verificarEmail(email: 'ana@pier.mx', codigo: '123456'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Código inválido o expirado')),
      );
    });

    test('registrar manda los datos y verificar abre sesión', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.register: _ok,
        ApiConstants.verifyEmail: {
          'success': true,
          'token': 'jwt',
          'user': usuario,
        },
      });
      final repo = AuthRepositoryRemote(api: api);

      await repo.registrar(
        nombre: 'Ana',
        apellido: 'López',
        email: 'ana@pier.mx',
        telefono: '7711234567',
        password: 'pastel123',
      );
      expect(api.ultima(ApiConstants.register)!.body?['telefono'],
          '7711234567');
      expect(await repo.isAuthenticated(), isFalse);

      final u = await repo.verificarEmail(email: 'ana@pier.mx', codigo: '123456');
      expect(u, usuario);
      expect(await repo.isAuthenticated(), isTrue);
    });

    test('registro rechazado lanza el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.register, 'El correo ya está registrado');
      final repo = AuthRepositoryRemote(api: api);

      await expectLater(
        repo.registrar(
          nombre: 'Ana',
          apellido: 'López',
          email: 'ana@pier.mx',
          telefono: '7711234567',
          password: 'pastel123',
        ),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'El correo ya está registrado')),
      );
    });

    test('sin sesión guardada no hay usuario actual', () async {
      final repo = AuthRepositoryRemote(api: FakeApiClient());
      expect(await repo.isAuthenticated(), isFalse);
      expect(await repo.getCurrentUser(), isNull);
    });

    test('getProfile y updateProfile refrescan el usuario guardado', () async {
      final actualizado = {...usuario, 'nombre': 'Ana María'};
      final api = FakeApiClient(respuestas: {
        ApiConstants.profile: {'success': true, 'user': usuario},
        ApiConstants.updateProfile: {'success': true, 'user': actualizado},
      });
      final repo = AuthRepositoryRemote(api: api);

      await repo.getProfile();
      expect(await repo.getCurrentUser(), usuario);

      await repo.updateProfile({'nombre': 'Ana María'});
      expect(api.ultima(ApiConstants.updateProfile)!.metodo, 'PUT-Auth');
      expect(await repo.getCurrentUser(), actualizado);
    });

    test('un perfil fallido no toca el usuario guardado', () async {
      SharedPreferences.setMockInitialValues({
        'pierreposteria_current_user': jsonEncode(usuario),
      });
      final api = FakeApiClient()..fallar(ApiConstants.profile, 'Token expirado');
      final repo = AuthRepositoryRemote(api: api);

      final r = await repo.getProfile();

      expect(r['message'], 'Token expirado');
      expect(await repo.getCurrentUser(), usuario);
    });

    test('reenviar código y restablecer contraseña mandan su body', () async {
      final api = _apiOk([
        ApiConstants.resendVerification,
        ApiConstants.requestPasswordReset,
        ApiConstants.resetPassword,
      ]);
      final repo = AuthRepositoryRemote(api: api);

      expect(await repo.reenviarCodigo('ana@pier.mx'), 'Código reenviado');
      await repo.solicitarRestablecimiento('ana@pier.mx');
      await repo.restablecerPassword(
        email: 'ana@pier.mx',
        codigo: '123456',
        nuevaPassword: 'nueva',
      );

      expect(api.ultima(ApiConstants.resendVerification)!.body,
          {'email': 'ana@pier.mx'});
      expect(api.ultima(ApiConstants.requestPasswordReset)!.body,
          {'email': 'ana@pier.mx'});
      final reset = api.ultima(ApiConstants.resetPassword)!;
      expect(reset.metodo, 'POST');
      expect(reset.body, {
        'email': 'ana@pier.mx',
        'codigo': '123456',
        'nuevaPassword': 'nueva',
      });
    });

    group('con Google', () {
      AuthRepositoryRemote repoGoogle(FakeApiClient api, FakeGoogleSignIn g) =>
          AuthRepositoryRemote(api: api, google: g);

      test('manda el idToken al backend y guarda la sesión', () async {
        final api = FakeApiClient(respuestas: {
          ApiConstants.googleMobile: {
            'success': true,
            'token': 'jwt',
            'user': usuario,
          },
        });
        final repo =
            repoGoogle(api, FakeGoogleSignIn(idToken: 'id-token'));

        final u = await repo.iniciarSesionConGoogle();

        expect(u, usuario);
        expect(api.ultima(ApiConstants.googleMobile)!.body,
            {'idToken': 'id-token'});
        expect(await repo.isAuthenticated(), isTrue);
      });

      test('si el usuario cierra el selector devuelve null', () async {
        final api = FakeApiClient();
        final repo = repoGoogle(api, FakeGoogleSignIn());

        expect(await repo.iniciarSesionConGoogle(), isNull);
        expect(api.llamo(ApiConstants.googleMobile), isFalse);
      });

      test('sin idToken o con error del plugin lanza ApiException', () async {
        final sinToken =
            repoGoogle(FakeApiClient(), FakeGoogleSignIn(conCuenta: true));
        final conError = repoGoogle(
            FakeApiClient(), FakeGoogleSignIn(error: Exception('sin red')));

        await expectLater(
          sinToken.iniciarSesionConGoogle(),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              'No se pudo obtener el token de Google')),
        );
        await expectLater(
          conError.iniciarSesionConGoogle(),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              contains('Error al iniciar sesión con Google'))),
        );
      });

      test('si el backend rechaza el token lanza su mensaje', () async {
        final api = FakeApiClient()
          ..fallar(ApiConstants.googleMobile, 'Cuenta deshabilitada');
        final repo =
            repoGoogle(api, FakeGoogleSignIn(idToken: 'id-token'));

        await expectLater(
          repo.iniciarSesionConGoogle(),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', 'Cuenta deshabilitada')),
        );
        expect(await repo.isAuthenticated(), isFalse);
      });
    });

    test('reenviar y restablecer fallidos lanzan ApiException', () async {
      final api = FakeApiClient(respuestas: {
        ApiConstants.resendVerification: {'success': false},
        ApiConstants.requestPasswordReset: {'success': false},
        ApiConstants.resetPassword: {
          'success': false,
          'message': 'Código expirado',
        },
      });
      final repo = AuthRepositoryRemote(api: api);

      Matcher conMensaje(String m) =>
          throwsA(isA<ApiException>().having((e) => e.message, 'message', m));
      await expectLater(repo.reenviarCodigo('ana@pier.mx'),
          conMensaje('No se pudo reenviar el código'));
      await expectLater(repo.solicitarRestablecimiento('ana@pier.mx'),
          conMensaje('No se pudo enviar el correo'));
      await expectLater(
        repo.restablecerPassword(
            email: 'ana@pier.mx', codigo: '000000', nuevaPassword: 'nueva1'),
        conMensaje('Código expirado'),
      );
    });
  });
}
