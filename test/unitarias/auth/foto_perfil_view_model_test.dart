// test/unitarias/auth/foto_perfil_view_model_test.dart — la foto de perfil
// (#345) sin red: se sube con tipo perfil y se guarda con avatar_url; si algo
// falla, el mensaje queda en `error` y el perfil no se toca.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_reposteria/ui/more/view_model/foto_perfil_view_model.dart';

import '../../fakes/fake_api_client.dart';

const _url = 'https://res.cloudinary.com/pier/image/upload/perfil/ana.webp';

/// Sube cualquier foto a [_url] y devuelve el usuario con el avatar que llegó.
FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.uploadImagen: {
        'success': true,
        'imagen': {'url': _url, 'public_id': 'perfil/ana'},
      },
      ApiConstants.updateProfileData: (LlamadaApi llamada) => <String, dynamic>{
            'success': true,
            'user': {
              'id': 9,
              'nombre': 'Ana',
              'avatar_url': llamada.body?['avatar_url'],
            },
          },
    });

FotoPerfilViewModel _vm(FakeApiClient api) =>
    FotoPerfilViewModel(repo: CuentaRepositoryRemote(api: api));

void main() {
  group('FotoPerfilViewModel (#345)', () {
    test('cambiar sube la foto con tipo perfil y la pone en el perfil',
        () async {
      final api = _backend();
      final vm = _vm(api);

      final usuario = await vm.cambiar('/fotos/ana.jpg');

      expect(usuario?['avatar_url'], _url);
      expect(vm.error, isNull);
      expect(vm.ocupado, isFalse);
      expect(api.llamadas.map((l) => '${l.metodo} ${l.endpoint}'), [
        'UPLOAD ${ApiConstants.uploadImagen}',
        'PUT-Auth ${ApiConstants.updateProfileData}',
      ]);
      expect(api.llamadas.first.body,
          {'filePath': '/fotos/ana.jpg', 'tipo': 'perfil'});
      expect(api.llamadas.last.body, {'avatar_url': _url});
    });

    test('mientras sube está ocupado y no acepta otra foto', () async {
      final api = _backend()
        ..demorar(ApiConstants.uploadImagen, const Duration(milliseconds: 50));
      final vm = _vm(api);

      final primera = vm.cambiar('/fotos/1.jpg');
      expect(vm.trabajo, TrabajoFoto.subiendo);
      expect(await vm.cambiar('/fotos/2.jpg'), isNull);

      expect(await primera, isNotNull);
      expect(api.llamadas.where((l) => l.metodo == 'UPLOAD'), hasLength(1));
      expect(vm.trabajo, TrabajoFoto.ninguno);
    });

    test('si la subida falla queda el mensaje y el perfil no se toca',
        () async {
      final api = _backend()
        ..fallar(ApiConstants.uploadImagen, 'La foto pesa más de 5 MB');
      final vm = _vm(api);

      expect(await vm.cambiar('/fotos/grande.jpg'), isNull);

      expect(vm.error, 'La foto pesa más de 5 MB');
      expect(vm.ocupado, isFalse);
      expect(api.llamo(ApiConstants.updateProfileData), isFalse);
    });

    test('quitar manda avatar_url en null', () async {
      final api = _backend();
      final vm = _vm(api);

      final usuario = await vm.quitar();

      expect(usuario, isNotNull);
      expect(usuario!['avatar_url'], isNull);
      expect(api.llamadas.single.body, {'avatar_url': null});
    });

    test('si no se pudo quitar, el error queda para la vista y se limpia al '
        'intentar otra vez', () async {
      final api = _backend()
        ..fallar(ApiConstants.updateProfileData, 'Error al actualizar perfil');
      final vm = _vm(api);

      expect(await vm.quitar(), isNull);
      expect(vm.error, 'Error al actualizar perfil');

      api.responder(ApiConstants.updateProfileData, {
        'success': true,
        'user': {'id': 9, 'avatar_url': null},
      });
      expect(await vm.quitar(), isNotNull);
      expect(vm.error, isNull);
    });
  });
}
