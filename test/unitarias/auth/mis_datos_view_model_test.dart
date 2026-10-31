// test/unitarias/auth/mis_datos_view_model_test.dart — «Mis datos» (#221):
// lo que el servidor tiene de la cuenta, leído de GET /auth/profile.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/auth_repository_remote.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

const Map<String, dynamic> _usuario = {
  'id': 9,
  'nombre': 'Ana',
  'apellido': 'López',
  'email': 'ana@pier.mx',
  'telefono': '7711234567',
  'rol': 'cliente',
  'activo': true,
  'emailVerificado': true,
  'googleId': null,
  'fechaRegistro': '2026-10-27T11:03:00.000Z',
  'ultimoAcceso': null,
};

Map<String, String> _comoMapa(List<DatoDeCuenta> datos) =>
    {for (final d in datos) d.etiqueta: d.valor};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('datosDeCuenta', () {
    test('muestra cada dato con su etiqueta, en orden', () {
      final datos = MisDatosViewModel.datosDeCuenta(_usuario);

      expect(datos.map((d) => d.etiqueta), [
        'Nombre',
        'Apellido',
        'Correo',
        'Teléfono',
        'Tipo de cuenta',
        'Entras con Google',
        'Correo verificado',
        'Cuenta creada',
        'Último acceso',
      ]);
      final mapa = _comoMapa(datos);
      expect(mapa['Correo'], 'ana@pier.mx');
      expect(mapa['Tipo de cuenta'], 'Cliente');
      expect(mapa['Entras con Google'], 'No');
      expect(mapa['Correo verificado'], 'Sí');
    });

    test('la fecha de registro se muestra en la hora de México', () {
      final mapa = _comoMapa(MisDatosViewModel.datosDeCuenta(_usuario));

      // 11:03 UTC son las 05:03 en México (UTC-6), sin importar la zona del
      // teléfono ni la del runner de CI, como el resto de las fechas (#216).
      expect(mapa['Cuenta creada'], '27 Oct 2026 · 05:03 hrs');
    });

    test('lo que falta dice «Sin dato»', () {
      final mapa = _comoMapa(MisDatosViewModel.datosDeCuenta({
        'nombre': 'Ana',
        'telefono': '',
        'googleId': 'g-123',
      }));

      expect(mapa['Teléfono'], 'Sin dato');
      expect(mapa['Tipo de cuenta'], 'Sin dato');
      expect(mapa['Entras con Google'], 'Sí');
      expect(mapa['Cuenta creada'], 'Sin dato');
      expect(mapa['Último acceso'], 'Sin dato');
    });

    test('cada rol tiene su nombre; uno desconocido se muestra tal cual', () {
      String rol(String r) =>
          _comoMapa(MisDatosViewModel.datosDeCuenta({'rol': r}))[
              'Tipo de cuenta']!;

      expect(rol('direccion_general'), 'Dirección general');
      expect(rol('decoracion'), 'Decoración');
      expect(rol('repartidor'), 'Repartidor');
      expect(rol('empleado'), 'Empleado');
      expect(rol('gerencia'), 'Gerencia');
      expect(rol('hornos'), 'Hornos');
      expect(rol('nuevo'), 'nuevo');
    });
  });

  group('cargar', () {
    test('lee GET /auth/profile con el token', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario});
      final vm = MisDatosViewModel(repo: AuthRepositoryRemote(api: api));

      expect(vm.cargando, isTrue);
      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.error, isNull);
      expect(_comoMapa(vm.datos)['Nombre'], 'Ana');
      expect(api.llamo(ApiConstants.profile, metodo: 'GET-Auth'), isTrue);
    });

    test('si el servidor falla deja su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.profile, 'Usuario no encontrado');
      final vm = MisDatosViewModel(repo: AuthRepositoryRemote(api: api));

      await vm.cargar();

      expect(vm.error, 'Usuario no encontrado');
      expect(vm.datos, isEmpty);
    });

    test('sin mensaje del servidor usa el aviso genérico', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': false});
      final vm = MisDatosViewModel(repo: AuthRepositoryRemote(api: api));

      await vm.cargar();

      expect(vm.error, MisDatosViewModel.sinConexion);
    });

    test('si la pantalla se cierra durante la carga no avisa', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario})
        ..demorar(ApiConstants.profile, const Duration(milliseconds: 10));
      final vm = MisDatosViewModel(repo: AuthRepositoryRemote(api: api));
      var avisos = 0;
      vm.addListener(() => avisos++);

      final carga = vm.cargar();
      vm.dispose();
      await carga;

      expect(avisos, 1, reason: 'solo el aviso de que empezó a cargar');
    });
  });
}
