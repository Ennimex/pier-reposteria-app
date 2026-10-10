// test/unit/more_view_model_test.dart — pestaña «Más» (MVVM, Fase 3) sin
// red: contacto de «Encuéntranos» y contadores según la sesión.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/info_contacto.dart';
import 'package:pier_pasteleria/ui/more/view_model/more_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _contacto = ApiConstants.configuracionSeccion('contacto');
const String _pedidos = ApiConstants.misPedidos;
const String _favIds = ApiConstants.favoritosIds;
const String _resenas = ApiConstants.misResenas;

Map<String, dynamic> _conDatos() => {
      _contacto: {
        'success': true,
        'config': {
          'telefono': '921 000 0000',
          'direccion': 'Av. Siempre Viva 742',
        },
      },
      _pedidos: {
        'success': true,
        'pedidos': [
          {'id': 1},
          {'id': 2},
        ],
      },
      _favIds: {
        'success': true,
        'ids': [36, 40, 41],
      },
      _resenas: {
        'success': true,
        'resenas': [
          {'id': 5},
        ],
      },
    };

MoreViewModel _vm(FakeApiClient api) => MoreViewModel(
      configRepo: ConfiguracionRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
      favoritosRepo: FavoritosRepositoryRemote(api: api),
      resenasRepo: ResenasRepositoryRemote(api: api),
    );

void main() {
  group('Repositorios y modelo', () {
    test('InfoContacto lee la dirección; vacía = null', () {
      expect(
        InfoContacto.fromConfig({'direccion': 'Calle 5'}).direccion,
        'Calle 5',
      );
      expect(InfoContacto.fromConfig({}).direccion, isNull);
    });

    test('listarIds tipa los ids como texto', () async {
      final api = FakeApiClient(respuestas: _conDatos());

      expect(await FavoritosRepositoryRemote(api: api).listarIds(),
          ['36', '40', '41']);
      expect(api.llamo(_favIds, metodo: 'GET-Auth'), isTrue);
    });
  });

  group('MoreViewModel', () {
    test('carga el contacto', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos()));
      expect(vm.cargandoContacto, isTrue);

      await vm.cargarContacto();

      expect(vm.cargandoContacto, isFalse);
      expect(vm.contacto.telefono, '921 000 0000');
      expect(vm.contacto.direccion, 'Av. Siempre Viva 742');
      expect(vm.contacto.email, isNull); // la vista usa BusinessInfo
    });

    test('si el contacto falla queda vacío', () async {
      final api = FakeApiClient()..fallar(_contacto, 'Caído');
      final vm = _vm(api);

      await vm.cargarContacto();

      expect(vm.cargandoContacto, isFalse);
      expect(vm.contacto.telefono, isNull);
    });

    test('con sesión cuenta pedidos, favoritos y reseñas', () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);

      await vm.actualizarSesion(autenticado: true, email: 'ana@pier.mx');

      expect(vm.cargandoStats, isFalse);
      expect(vm.totalPedidos, 2);
      expect(vm.totalFavoritos, 3);
      expect(vm.totalResenas, 1);
    });

    test('un contador que falla queda en 0 sin afectar a los demás',
        () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..fallar(_favIds, 'Token expirado');
      final vm = _vm(api);

      await vm.actualizarSesion(autenticado: true, email: 'ana@pier.mx');

      expect(vm.totalPedidos, 2);
      expect(vm.totalFavoritos, 0);
      expect(vm.totalResenas, 1);
    });

    test('la misma sesión no vuelve a pedir; al salir quedan en 0', () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);
      await vm.actualizarSesion(autenticado: true, email: 'ana@pier.mx');
      final llamadas = api.llamadas.length;

      await vm.actualizarSesion(autenticado: true, email: 'ana@pier.mx');
      expect(api.llamadas.length, llamadas);

      await vm.actualizarSesion(autenticado: false, email: null);
      expect(vm.totalPedidos, 0);
      expect(vm.totalFavoritos, 0);
      expect(vm.totalResenas, 0);
      expect(vm.cargandoStats, isFalse);
      expect(api.llamadas.length, llamadas);
    });

    test('si la sesión cambia a media carga, no pisa los números nuevos',
        () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..demorar(_pedidos, const Duration(milliseconds: 30));
      final vm = _vm(api);

      final primera =
          vm.actualizarSesion(autenticado: true, email: 'ana@pier.mx');
      await vm.actualizarSesion(autenticado: false, email: null);
      await primera;

      expect(vm.totalPedidos, 0);
      expect(vm.cargandoStats, isFalse);
    });

    test('como invitado no pide nada', () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);

      await vm.actualizarSesion(autenticado: false, email: null);

      expect(vm.cargandoStats, isFalse);
      expect(api.llamadas, isEmpty);
    });
  });
}
