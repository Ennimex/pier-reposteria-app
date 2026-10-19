// test/unitarias/comun/storage_service_test.dart — StorageService (#25): el
// JWT vive en almacenamiento cifrado (flutter_secure_storage simulado con
// setMockInitialValues) y el token viejo de SharedPreferences se migra.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _token = 'pierreposteria_token';
const _usuario = 'pierreposteria_current_user';

/// Almacenamiento seguro que no se puede leer (p. ej. la llave del Keystore
/// se perdió): solo permite borrar.
class _SeguroIlegible extends Fake implements FlutterSecureStorage {
  final borradas = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw PlatformException(code: 'Exception', message: 'Llave perdida');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      borradas.add(key);
}

Future<String?> _enPrefs(String llave) async =>
    (await SharedPreferences.getInstance()).getString(llave);

Future<String?> _enSeguro(String llave) =>
    const FlutterSecureStorage().read(key: llave);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('StorageService: token', () {
    test('saveToken lo guarda cifrado y nunca en SharedPreferences', () async {
      final storage = StorageService();

      await storage.saveToken('jwt');

      expect(await _enSeguro(_token), 'jwt');
      expect(await _enPrefs(_token), isNull);
      expect(await storage.getToken(), 'jwt');
      expect(await storage.isAuthenticated(), isTrue);
    });

    test('sin token no hay sesión', () async {
      final storage = StorageService();

      expect(await storage.getToken(), isNull);
      expect(await storage.isAuthenticated(), isFalse);
    });

    test('un token de la versión anterior se migra y se borra del XML',
        () async {
      SharedPreferences.setMockInitialValues({_token: 'jwt-viejo'});
      final storage = StorageService();

      expect(await storage.getToken(), 'jwt-viejo');

      expect(await _enSeguro(_token), 'jwt-viejo');
      expect(await _enPrefs(_token), isNull);
      expect(await storage.getToken(), 'jwt-viejo');
    });

    test('el token cifrado gana sobre uno viejo que quedara en el XML',
        () async {
      SharedPreferences.setMockInitialValues({_token: 'jwt-viejo'});
      FlutterSecureStorage.setMockInitialValues({_token: 'jwt-nuevo'});

      expect(await StorageService().getToken(), 'jwt-nuevo');
    });

    test('si no se puede descifrar, lo descarta y pide iniciar sesión',
        () async {
      final seguro = _SeguroIlegible();
      final storage = StorageService(seguro: seguro);

      expect(await storage.getToken(), isNull);
      expect(seguro.borradas, [_token]);
    });

    test('removeToken lo borra de ambos lados', () async {
      SharedPreferences.setMockInitialValues({_token: 'jwt-viejo'});
      FlutterSecureStorage.setMockInitialValues({_token: 'jwt'});

      await StorageService().removeToken();

      expect(await _enSeguro(_token), isNull);
      expect(await _enPrefs(_token), isNull);
    });
  });

  group('StorageService: usuario y cierre de sesión', () {
    test('el usuario se guarda, se lee y se borra', () async {
      final storage = StorageService();

      await storage.saveUser('{"id":1}');
      expect(await storage.getUser(), '{"id":1}');

      await storage.removeUser();
      expect(await storage.getUser(), isNull);
    });

    test('clearAll borra token y usuario', () async {
      final storage = StorageService();
      await storage.saveToken('jwt');
      await storage.saveUser('{"id":1}');

      await storage.clearAll();

      expect(await storage.getToken(), isNull);
      expect(await _enPrefs(_usuario), isNull);
    });
  });
}
