// test/unit/auth_provider_test.dart — sesión del usuario (#16) sin red: el
// backend es un FakeApiClient y SharedPreferences está simulado.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';

const _token = 'pierreposteria_token';
const _usuario = 'pierreposteria_current_user';

Map<String, dynamic> _user({String rol = 'cliente'}) => {
      'id': 9,
      'nombre': 'Ana',
      'email': 'ana@example.com',
      'rol': rol,
    };

AuthProvider _auth(FakeApiClient api) =>
    AuthProvider(auth: AuthRepositoryRemote(api: api));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthProvider: sesión guardada', () {
    test('sin token guardado no hay sesión', () async {
      final auth = _auth(FakeApiClient());

      await auth.checkSession();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('con token y usuario guardados recupera la sesión', () async {
      SharedPreferences.setMockInitialValues({
        _token: 'jwt-de-prueba',
        _usuario: jsonEncode(_user(rol: 'repartidor')),
      });
      final auth = _auth(FakeApiClient());

      await auth.checkSession();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?['nombre'], 'Ana');
      expect(auth.isRepartidor, isTrue);
    });
  });

  group('AuthProvider: login', () {
    test('login exitoso abre sesión y guarda el token', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, {
          'success': true,
          'token': 'jwt-de-prueba',
          'user': _user(),
        });
      final auth = _auth(api);

      final ok = await auth.login('ana@example.com', 'pastel123');

      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.rol, 'cliente');
      expect(api.ultima(ApiConstants.login)?.body,
          {'email': 'ana@example.com', 'password': 'pastel123'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_token), 'jwt-de-prueba');
    });

    test('credenciales inválidas dejan el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      final auth = _auth(api);

      final ok = await auth.login('ana@example.com', 'incorrecta');

      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, 'Credenciales inválidas');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_token), isNull);
    });

    test('si el backend no explica el error, usa un mensaje genérico',
        () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, {'success': false});
      final auth = _auth(api);

      await auth.login('ana@example.com', 'pastel123');

      expect(auth.errorMessage, 'Error al iniciar sesión');
    });

    test('clearError borra el mensaje y avisa a la UI', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      final auth = _auth(api);
      await auth.login('ana@example.com', 'incorrecta');
      var avisos = 0;
      auth.addListener(() => avisos++);

      auth.clearError();

      expect(auth.errorMessage, isNull);
      expect(avisos, 1);
    });
  });

  group('AuthProvider: logout', () {
    test('cierra sesión en el backend y borra lo guardado', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, {
          'success': true,
          'token': 'jwt-de-prueba',
          'user': _user(),
        })
        ..responder(ApiConstants.logout, {'success': true});
      final auth = _auth(api);
      await auth.login('ana@example.com', 'pastel123');

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(api.llamo(ApiConstants.logout, metodo: 'POST-Auth'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_token), isNull);
      expect(prefs.getString(_usuario), isNull);
    });
  });

  group('AuthProvider: roles', () {
    Future<AuthProvider> conRol(String rol) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, {
          'success': true,
          'token': 'jwt',
          'user': _user(rol: rol),
        });
      final auth = _auth(api);
      await auth.login('ana@example.com', 'pastel123');
      return auth;
    }

    test('cliente no es repartidor ni rol interno', () async {
      final auth = await conRol('cliente');
      expect(auth.isRepartidor, isFalse);
      expect(auth.isRolInterno, isFalse);
    });

    test('repartidor se reconoce como tal', () async {
      final auth = await conRol('repartidor');
      expect(auth.isRepartidor, isTrue);
      expect(auth.isRolInterno, isFalse);
    });

    test('empleado, gerencia y dirección son roles internos', () async {
      expect((await conRol('empleado')).isEmpleado, isTrue);
      expect((await conRol('gerencia')).isGerencia, isTrue);
      expect((await conRol('direccion_general')).isDireccion, isTrue);
      for (final rol in ['empleado', 'gerencia', 'direccion_general']) {
        expect((await conRol(rol)).isRolInterno, isTrue, reason: rol);
      }
    });
  });

  group('AuthProvider: registro y verificación', () {
    test('registrarse no abre sesión: devuelve la respuesta del backend',
        () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.register,
            {'success': true, 'message': 'Revisa tu correo'});
      final auth = _auth(api);

      final r = await auth.register(
        nombre: 'Ana',
        apellido: 'López',
        email: 'ana@example.com',
        telefono: '7711234567',
        password: 'pastel123',
      );

      expect(r['success'], isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isLoading, isFalse);
    });

    test('verificar el email con el código correcto abre sesión', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.verifyEmail, {
          'success': true,
          'token': 'jwt',
          'user': _user(),
        });
      final auth = _auth(api);

      final ok = await auth.verifyEmail('ana@example.com', '123456');

      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(api.ultima(ApiConstants.verifyEmail)?.body,
          {'email': 'ana@example.com', 'codigo': '123456'});
    });

    test('un código incorrecto deja el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.verifyEmail, 'Código inválido');
      final auth = _auth(api);

      final ok = await auth.verifyEmail('ana@example.com', '000000');

      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, 'Código inválido');
    });
  });

  group('AuthProvider: perfil en memoria', () {
    test('updateCurrentUser mezcla los campos editados', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, {
          'success': true,
          'token': 'jwt',
          'user': _user(),
        });
      final auth = _auth(api);
      await auth.login('ana@example.com', 'pastel123');

      auth.updateCurrentUser({'nombre': 'Ana María'});

      expect(auth.currentUser?['nombre'], 'Ana María');
      expect(auth.currentUser?['email'], 'ana@example.com');
    });

    test('sin sesión, updateCurrentUser no hace nada', () {
      final auth = _auth(FakeApiClient());

      auth.updateCurrentUser({'nombre': 'Ana María'});

      expect(auth.currentUser, isNull);
    });
  });
}
