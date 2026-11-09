// test/unitarias/auth/mis_datos_view_model_test.dart — «Mis datos» (#221):
// lo que el servidor tiene de la cuenta, leído de GET /auth/profile; la baja
// de la cuenta con DELETE /usuarios/perfil y, de respaldo, el correo para
// pedirla (#222).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/auth_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/more/view_model/mis_datos_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/fake_google_sign_in.dart';

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

MisDatosViewModel _vm(FakeApiClient api) => MisDatosViewModel(
      repo: AuthRepositoryRemote(api: api),
      cuenta: CuentaRepositoryRemote(api: api),
    );

const _enCurso =
    'Tienes pedidos en curso; espera a que se entreguen o cancélalos';

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
      final vm = _vm(api);

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
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.error, 'Usuario no encontrado');
      expect(vm.datos, isEmpty);
    });

    test('sin mensaje del servidor usa el aviso genérico', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': false});
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.error, MisDatosViewModel.sinConexion);
    });

    test('si la pantalla se cierra durante la carga no avisa', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario})
        ..demorar(ApiConstants.profile, const Duration(milliseconds: 10));
      final vm = _vm(api);
      var avisos = 0;
      vm.addListener(() => avisos++);

      final carga = vm.cargar();
      vm.dispose();
      await carga;

      expect(avisos, 1, reason: 'solo el aviso de que empezó a cargar');
    });
  });

  group('correoDeBaja (#222)', () {
    test('escribe a Pier con el asunto, la petición y los datos de la cuenta',
        () {
      final correo = MisDatosViewModel.correoDeBaja(_usuario);

      expect(correo.scheme, 'mailto');
      expect(correo.path, BusinessInfo.email);
      expect(correo.queryParameters['subject'], 'Eliminar mi cuenta');
      final cuerpo = correo.queryParameters['body']!;
      expect(cuerpo, startsWith('Hola, Pier:'));
      expect(cuerpo, contains(MisDatosViewModel.peticionBaja));
      expect(cuerpo, contains('Correo de la cuenta: ana@pier.mx'));
      expect(cuerpo, contains('Nombre: Ana López'));
    });

    test('los espacios van como %20, no como «+»', () {
      final texto = MisDatosViewModel.correoDeBaja(_usuario).toString();

      expect(texto, contains('subject=Eliminar%20mi%20cuenta'));
      expect(texto, isNot(contains('+')));
    });

    test('sin datos de la cuenta solo lleva la petición', () {
      final cuerpo = MisDatosViewModel.correoDeBaja(const {})
          .queryParameters['body']!;

      expect(cuerpo, endsWith(MisDatosViewModel.peticionBaja));
      expect(cuerpo, isNot(contains('Correo de la cuenta')));
      expect(cuerpo, isNot(contains('Nombre:')));
    });

    test('después de cargar usa los datos del servidor', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': _usuario});
      final vm = _vm(api);
      expect(vm.correoParaEliminarCuenta.queryParameters['body'],
          isNot(contains('ana@pier.mx')));

      await vm.cargar();

      expect(vm.correoParaEliminarCuenta.queryParameters['body'],
          contains('Correo de la cuenta: ana@pier.mx'));
    });
  });

  group('eliminarCuenta (#222)', () {
    late int cierres;
    Future<void> contarCierre() async {
      cierres++;
    }

    setUp(() {
      cierres = 0;
      // La sesión del cliente guardada en el teléfono, como tras entrar.
      SharedPreferences.setMockInitialValues({
        'pierreposteria_token': 'jwt',
        'pierreposteria_current_user': jsonEncode(_usuario),
      });
    });

    /// ViewModel con los datos de [usuario] ya cargados y [baja] como
    /// respuesta de DELETE /usuarios/perfil.
    Future<(MisDatosViewModel, FakeApiClient)> cargado(
      Map<String, dynamic> baja, {
      Map<String, dynamic> usuario = _usuario,
    }) async {
      final api = FakeApiClient()
        ..responder(ApiConstants.profile, {'success': true, 'user': usuario})
        ..responder(ApiConstants.eliminarCuenta, baja);
      final vm = _vm(api);
      await vm.cargar();
      return (vm, api);
    }

    test('si se elimina, cierra la sesión solo en el teléfono', () async {
      final (vm, api) =
          await cargado({'success': true, 'message': 'Tu cuenta se eliminó'});
      final auth = AuthProvider(
        auth: AuthRepositoryRemote(api: api, google: FakeGoogleSignIn()),
      )..abrirSesion(_usuario);

      final resultado =
          await vm.eliminarCuenta(cerrarSesion: auth.cerrarSesionLocal);

      expect(resultado, ResultadoBaja.eliminada);
      expect(api.llamo(ApiConstants.eliminarCuenta, metodo: 'DELETE-Auth'),
          isTrue);
      expect(api.llamo(ApiConstants.logout), isFalse,
          reason: 'el token ya no sirve: no se avisa al servidor');
      expect(auth.isAuthenticated, isFalse);
      expect(auth.sesionExpiro, isFalse);
      expect(await AuthRepositoryRemote(api: api).isAuthenticated(), isFalse);
      expect(vm.eliminando, isFalse);
      expect(vm.avisoBaja, isNull);
    });

    test('con pedidos en curso deja el mensaje y no cierra la sesión',
        () async {
      final (vm, _) = await cargado({
        'success': false,
        'codigo': 'PEDIDOS_EN_CURSO',
        'message': _enCurso,
      });

      final resultado = await vm.eliminarCuenta(cerrarSesion: contarCierre);

      expect(resultado, ResultadoBaja.pedidosEnCurso);
      expect(vm.avisoBaja, _enCurso);
      expect(cierres, 0);
      expect(vm.eliminando, isFalse);
    });

    test('sin red o con error del servidor ofrece pedirla por correo',
        () async {
      for (final mensaje in [
        ApiService.mensajeSinConexion,
        'No se pudo eliminar tu cuenta',
      ]) {
        final (vm, _) = await cargado({'success': false, 'message': mensaje});

        final resultado = await vm.eliminarCuenta(cerrarSesion: contarCierre);

        expect(resultado, ResultadoBaja.error, reason: mensaje);
        expect(vm.avisoBaja, mensaje);
        // El respaldo: el correo a Pier con los datos de esta cuenta.
        expect(vm.correoParaEliminarCuenta.queryParameters['body'],
            contains('Correo de la cuenta: ana@pier.mx'));
      }
      expect(cierres, 0);
    });

    test('una cuenta del personal recibe el mensaje del backend', () async {
      const mensaje = 'Las cuentas del personal no se dan de baja desde aquí';
      final (vm, _) = await cargado(
        {'success': false, 'message': mensaje},
        usuario: {..._usuario, 'rol': 'empleado'},
      );

      final resultado = await vm.eliminarCuenta(cerrarSesion: contarCierre);

      expect(resultado, ResultadoBaja.personal);
      expect(vm.avisoBaja, mensaje);
      expect(cierres, 0);
    });

    test('con un 401 deja que la app cierre la sesión y avise', () async {
      // ApiService ya borró la sesión del teléfono al recibir el 401.
      SharedPreferences.setMockInitialValues({});
      final (vm, _) =
          await cargado({'success': false, 'message': 'Token expirado'});

      final resultado = await vm.eliminarCuenta(cerrarSesion: contarCierre);

      expect(resultado, ResultadoBaja.sesionVencida);
      expect(cierres, 0);
    });

    test('la cuenta inactiva (SESION_INVALIDA) también es sesión vencida',
        () async {
      final (vm, _) = await cargado({
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu sesión ya no es válida',
      });

      final resultado = await vm.eliminarCuenta(cerrarSesion: contarCierre);

      expect(resultado, ResultadoBaja.sesionVencida);
      expect(cierres, 0);
    });

    test('no manda la baja dos veces', () async {
      final (vm, api) = await cargado({'success': true});
      api.demorar(ApiConstants.eliminarCuenta, const Duration(milliseconds: 10));
      var avisos = 0;
      vm.addListener(() => avisos++);

      final primera = vm.eliminarCuenta(cerrarSesion: contarCierre);
      expect(vm.eliminando, isTrue);
      final segunda = await vm.eliminarCuenta(cerrarSesion: contarCierre);

      expect(segunda, ResultadoBaja.ocupado);
      expect(await primera, ResultadoBaja.eliminada);
      expect(
        api.llamadas.where((l) => l.endpoint == ApiConstants.eliminarCuenta),
        hasLength(1),
      );
      expect(cierres, 1);
      expect(vm.eliminando, isFalse);
      expect(avisos, 2, reason: 'al empezar y al terminar');
    });

    test('si la pantalla se cierra durante la baja, igual cierra la sesión',
        () async {
      final (vm, api) = await cargado({'success': true});
      api.demorar(ApiConstants.eliminarCuenta, const Duration(milliseconds: 10));
      var avisos = 0;
      vm.addListener(() => avisos++);

      final baja = vm.eliminarCuenta(cerrarSesion: contarCierre);
      vm.dispose();

      expect(await baja, ResultadoBaja.eliminada);
      expect(cierres, 1);
      expect(avisos, 1, reason: 'solo el aviso de que empezó');
    });
  });
}
