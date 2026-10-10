// test/unit/auth_provider_test.dart — sesión del usuario (#16) sin red: el
// backend es un FakeApiClient y SharedPreferences está simulado. Desde la
// Fase 5 (#99) el provider solo guarda la sesión; entrar, registrarse y
// restablecer la contraseña se prueban en los ViewModels de auth.
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

AuthProvider _conSesion({String rol = 'cliente', FakeApiClient? api}) =>
    _auth(api ?? FakeApiClient())..abrirSesion(_user(rol: rol));

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

  group('AuthProvider: abrir sesión', () {
    test('abrirSesion deja al usuario dentro y avisa al router', () {
      var avisos = 0;
      final auth = _auth(FakeApiClient())
        ..addListener(() => avisos++)
        ..abrirSesion(_user());

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?['email'], 'ana@example.com');
      expect(auth.rol, 'cliente');
      expect(avisos, 1);
    });
  });

  group('AuthProvider: logout', () {
    test('cierra sesión en el backend y borra lo guardado', () async {
      SharedPreferences.setMockInitialValues({
        _token: 'jwt-de-prueba',
        _usuario: jsonEncode(_user()),
      });
      final api = FakeApiClient()
        ..responder(ApiConstants.logout, {'success': true});
      final auth = _conSesion(api: api);

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
    test('cliente no es repartidor ni rol interno', () {
      final auth = _conSesion();
      expect(auth.isRepartidor, isFalse);
      expect(auth.isRolInterno, isFalse);
    });

    test('repartidor se reconoce como tal', () {
      final auth = _conSesion(rol: 'repartidor');
      expect(auth.isRepartidor, isTrue);
      expect(auth.isRolInterno, isFalse);
    });

    test('empleado, gerencia y dirección son roles internos', () {
      expect(_conSesion(rol: 'empleado').isEmpleado, isTrue);
      expect(_conSesion(rol: 'gerencia').isGerencia, isTrue);
      expect(_conSesion(rol: 'direccion_general').isDireccion, isTrue);
      for (final rol in ['empleado', 'gerencia', 'direccion_general']) {
        expect(_conSesion(rol: rol).isRolInterno, isTrue, reason: rol);
      }
    });
  });

  group('AuthProvider: perfil en memoria', () {
    test('updateCurrentUser mezcla los campos editados', () {
      final auth = _conSesion()..updateCurrentUser({'nombre': 'Ana María'});

      expect(auth.currentUser?['nombre'], 'Ana María');
      expect(auth.currentUser?['email'], 'ana@example.com');
    });

    test('sin sesión, updateCurrentUser no hace nada', () {
      final auth = _auth(FakeApiClient())
        ..updateCurrentUser({'nombre': 'Ana María'});

      expect(auth.currentUser, isNull);
    });
  });
}
