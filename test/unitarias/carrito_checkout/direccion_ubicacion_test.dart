// test/unitarias/carrito_checkout/direccion_ubicacion_test.dart — #227:
// «Usar mi ubicación» en el formulario de dirección. Un Ubicador falso hace
// de teléfono; la dirección se guarda con lat y lng solo si se consiguieron.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_reposteria/data/services/ubicacion_service.dart';
import 'package:pier_reposteria/ui/checkout/view_model/direccion_form_view_model.dart';

import '../../fakes/fake_api_client.dart';

class _UbicadorFalso implements Ubicador {
  _UbicadorFalso(this.resultado);

  ResultadoUbicacion resultado;
  int lecturas = 0;
  int ajustes = 0;

  @override
  Future<ResultadoUbicacion> ubicacionActual() async {
    lecturas++;
    return resultado;
  }

  @override
  Future<bool> abrirAjustes() async {
    ajustes++;
    return true;
  }
}

FakeApiClient _api() => FakeApiClient()
  ..responder(ApiConstants.zonasColonias, {
    'success': true,
    'colonias': [
      {'colonia': 'Centro', 'tarifa': '40.00'},
    ],
  })
  ..responder(ApiConstants.direcciones, {
    'success': true,
    'direccion': {'id': 5, 'alias': 'Casa', 'colonia': 'Centro'},
  });

Future<Map<String, dynamic>?> _guardar(
  DireccionFormViewModel form,
  FakeApiClient api,
) async {
  await form.cargarColonias();
  form.elegirColonia('Centro');
  await form.guardar(
      alias: 'Casa', calle: 'Hidalgo 1', referencias: '', telefono: '');
  return api.ultima(ApiConstants.direcciones)?.body;
}

void main() {
  test('con la ubicación lista la dirección se guarda con lat y lng',
      () async {
    final api = _api();
    final ubicador = _UbicadorFalso(const ResultadoUbicacion(
        EstadoUbicacion.lista,
        lat: 21.14,
        lng: -98.42));
    final form = DireccionFormViewModel(
        repo: DireccionesRepositoryRemote(api: api), ubicador: ubicador);

    await form.usarMiUbicacion();
    final cuerpo = await _guardar(form, api);

    expect(form.conUbicacion, isTrue);
    expect(form.avisoUbicacion, contains('Ubicación agregada'));
    expect(cuerpo?['lat'], 21.14);
    expect(cuerpo?['lng'], -98.42);
  });

  test('sin usar la ubicación se guarda igual, sin coordenadas', () async {
    final api = _api();
    final form = DireccionFormViewModel(
        repo: DireccionesRepositoryRemote(api: api),
        ubicador: _UbicadorFalso(
            const ResultadoUbicacion(EstadoUbicacion.lista, lat: 1, lng: 2)));

    final cuerpo = await _guardar(form, api);

    expect(form.avisoUbicacion, isNull);
    expect(cuerpo!.containsKey('lat'), isFalse);
    expect(cuerpo.containsKey('lng'), isFalse);
  });

  test('cada desenlace sin ubicación tiene su aviso y no manda coordenadas',
      () async {
    final avisos = {
      EstadoUbicacion.servicioApagado: 'Activa la ubicación',
      EstadoUbicacion.sinPermiso: 'Sin permiso de ubicación',
      EstadoUbicacion.sinPermisoParaSiempre: 'Puedes darlo en Ajustes',
      EstadoUbicacion.fallo: 'No pudimos leer tu ubicación',
    };
    for (final MapEntry(key: estado, value: aviso) in avisos.entries) {
      final api = _api();
      final form = DireccionFormViewModel(
          repo: DireccionesRepositoryRemote(api: api),
          ubicador: _UbicadorFalso(ResultadoUbicacion(estado)));

      await form.usarMiUbicacion();
      final cuerpo = await _guardar(form, api);

      expect(form.estadoUbicacion, estado);
      expect(form.avisoUbicacion, contains(aviso), reason: '$estado');
      expect(cuerpo!.containsKey('lat'), isFalse, reason: '$estado');
    }
  });

  test('mientras lee no vuelve a pedirla, y abre los Ajustes', () async {
    final ubicador = _UbicadorFalso(
        const ResultadoUbicacion(EstadoUbicacion.sinPermisoParaSiempre));
    final form = DireccionFormViewModel(
        repo: DireccionesRepositoryRemote(api: _api()), ubicador: ubicador);

    final primera = form.usarMiUbicacion();
    expect(form.ubicando, isTrue);
    await form.usarMiUbicacion();
    await primera;
    await form.abrirAjustes();

    expect(ubicador.lecturas, 1);
    expect(form.ubicando, isFalse);
    expect(ubicador.ajustes, 1);
  });

  test('si el formulario se cierra mientras lee, no avisa', () async {
    final form = DireccionFormViewModel(
        repo: DireccionesRepositoryRemote(api: _api()),
        ubicador: _UbicadorFalso(
            const ResultadoUbicacion(EstadoUbicacion.lista, lat: 1, lng: 2)));
    var avisos = 0;
    form.addListener(() => avisos++);

    final lectura = form.usarMiUbicacion();
    form.dispose();
    await lectura;

    expect(avisos, 1, reason: 'solo el aviso de que empezó a leer');
  });
}
