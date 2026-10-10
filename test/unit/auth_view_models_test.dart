// test/unit/auth_view_models_test.dart — ViewModels de auth (MVVM, Fase 5,
// #99) sin red: el AuthRepositoryRemote habla con un FakeApiClient y
// SharedPreferences está simulado.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository_remote.dart';
import 'package:pier_pasteleria/ui/auth/view_model/forgot_password_view_model.dart';
import 'package:pier_pasteleria/ui/auth/view_model/login_view_model.dart';
import 'package:pier_pasteleria/ui/auth/view_model/register_view_model.dart';
import 'package:pier_pasteleria/ui/auth/view_model/reset_password_view_model.dart';
import 'package:pier_pasteleria/ui/auth/view_model/verify_email_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';
import '../fakes/fake_google_sign_in.dart';

const _email = 'ana@pier.mx';
const Map<String, dynamic> _usuario = {'id': 9, 'nombre': 'Ana', 'rol': 'cliente'};
const Map<String, dynamic> _sesion = {'success': true, 'token': 'jwt', 'user': _usuario};

AuthRepositoryRemote _repo(FakeApiClient api) => AuthRepositoryRemote(api: api);

/// Cuenta los avisos que da [vm] a la vista.
int Function() _contarAvisos(LoginViewModel vm) {
  var avisos = 0;
  vm.addListener(() => avisos++);
  return () => avisos;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LoginViewModel', () {
    test('login correcto devuelve el usuario y apaga «ingresando»', () async {
      final api = FakeApiClient()..responder(ApiConstants.login, _sesion);
      final vm = LoginViewModel(repo: _repo(api));
      final avisos = _contarAvisos(vm);

      final u = await vm.iniciarSesion(_email, 'pastel123');

      expect(u, _usuario);
      expect(vm.error, isNull);
      expect(vm.ingresando, isFalse);
      expect(avisos(), 2); // al empezar y al terminar
    });

    test('credenciales inválidas dejan el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas');
      final vm = LoginViewModel(repo: _repo(api));

      expect(await vm.iniciarSesion(_email, 'mala'), isNull);
      expect(vm.error, 'Credenciales inválidas');
    });

    test('un segundo toque mientras espera no vuelve a llamar', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.login, _sesion)
        ..demorar(ApiConstants.login, const Duration(milliseconds: 10));
      final vm = LoginViewModel(repo: _repo(api));

      final primero = vm.iniciarSesion(_email, 'pastel123');
      expect(vm.ingresando, isTrue);
      expect(await vm.iniciarSesion(_email, 'pastel123'), isNull);
      await primero;

      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.login),
          hasLength(1));
    });

    test('con Google devuelve el usuario, o null si se cancela', () async {
      final api = FakeApiClient()..responder(ApiConstants.googleMobile, _sesion);
      final ok = LoginViewModel(
          repo: AuthRepositoryRemote(
              api: api, google: FakeGoogleSignIn(idToken: 'id-token')));
      final cancelado = LoginViewModel(
          repo: AuthRepositoryRemote(api: api, google: FakeGoogleSignIn()));

      expect(await ok.iniciarSesionConGoogle(), _usuario);
      expect(ok.ingresandoConGoogle, isFalse);
      expect(await cancelado.iniciarSesionConGoogle(), isNull);
      expect(cancelado.error, isNull);
    });

    test('con Google, un error del plugin queda en error', () async {
      final vm = LoginViewModel(
          repo: AuthRepositoryRemote(
              api: FakeApiClient(),
              google: FakeGoogleSignIn(error: Exception('sin red'))));

      expect(await vm.iniciarSesionConGoogle(), isNull);
      expect(vm.error, contains('Google'));
    });

    test('el ojito alterna la visibilidad de la contraseña', () {
      final vm = LoginViewModel(repo: _repo(FakeApiClient()))
        ..alternarPassword();

      expect(vm.verPassword, isTrue);
      vm.alternarPassword();
      expect(vm.verPassword, isFalse);
    });

    test('cerrado a media llamada no avisa ni falla', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.login, 'Credenciales inválidas')
        ..demorar(ApiConstants.login, const Duration(milliseconds: 10));
      final vm = LoginViewModel(repo: _repo(api));

      final pendiente = vm.iniciarSesion(_email, 'mala');
      vm.dispose();

      expect(await pendiente, isNull);
      expect(vm.error, isNull);
    });
  });

  group('RegisterViewModel', () {
    Future<bool> registrar(RegisterViewModel vm) => vm.registrar(
          nombre: 'Ana',
          apellido: 'López',
          email: _email,
          telefono: '7711234567',
          password: 'pastel123',
        );

    test('registro correcto devuelve true sin abrir sesión', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.register, {'success': true});
      final vm = RegisterViewModel(repo: _repo(api));

      expect(await registrar(vm), isTrue);
      expect(vm.registrando, isFalse);
      expect(await _repo(api).isAuthenticated(), isFalse);
    });

    test('registro rechazado devuelve false con el mensaje', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.register, 'El correo ya está registrado');
      final vm = RegisterViewModel(repo: _repo(api));

      expect(await registrar(vm), isFalse);
      expect(vm.error, 'El correo ya está registrado');
    });

    test('términos y ojitos son estado de la pantalla', () {
      final vm = RegisterViewModel(repo: _repo(FakeApiClient()))
        ..aceptaTerminos = true
        ..alternarConfirmacion();

      expect(vm.aceptaTerminos, isTrue);
      expect(vm.verConfirmacion, isTrue);
      expect(vm.verPassword, isFalse);
    });
  });

  group('VerifyEmailViewModel', () {
    test('un código incompleto no llama al backend', () async {
      final api = FakeApiClient();
      final vm = VerifyEmailViewModel(repo: _repo(api), email: _email);

      expect(await vm.verificar('123'), isNull);
      expect(vm.error, VerifyEmailViewModel.codigoIncompleto);
      expect(api.llamo(ApiConstants.verifyEmail), isFalse);
    });

    test('el código correcto devuelve el usuario', () async {
      final api = FakeApiClient()..responder(ApiConstants.verifyEmail, _sesion);
      final vm = VerifyEmailViewModel(repo: _repo(api), email: _email);

      expect(await vm.verificar('123456'), _usuario);
      expect(api.ultima(ApiConstants.verifyEmail)?.body,
          {'email': _email, 'codigo': '123456'});
    });

    test('un código rechazado deja el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.verifyEmail, 'Código inválido');
      final vm = VerifyEmailViewModel(repo: _repo(api), email: _email);

      expect(await vm.verificar('000000'), isNull);
      expect(vm.error, 'Código inválido');
      expect(vm.verificando, isFalse);
    });

    test('reenviar devuelve el mensaje de éxito o deja el error', () async {
      final ok = FakeApiClient()
        ..responder(ApiConstants.resendVerification,
            {'success': true, 'message': 'Te mandamos otro código'});
      final mal = FakeApiClient()
        ..fallar(ApiConstants.resendVerification, 'Espera un minuto');

      final vmOk = VerifyEmailViewModel(repo: _repo(ok), email: _email);
      final vmMal = VerifyEmailViewModel(repo: _repo(mal), email: _email);

      expect(await vmOk.reenviar(), 'Te mandamos otro código');
      expect(vmOk.reenviando, isFalse);
      expect(await vmMal.reenviar(), isNull);
      expect(vmMal.error, 'Espera un minuto');
    });
  });

  group('ForgotPasswordViewModel', () {
    test('un correo vacío o sin @ no llama al backend', () async {
      final api = FakeApiClient();
      final vm = ForgotPasswordViewModel(repo: _repo(api));

      expect(await vm.enviar(''), isFalse);
      expect(await vm.enviar('ana.pier.mx'), isFalse);
      expect(vm.error, ForgotPasswordViewModel.correoInvalido);
      expect(api.llamo(ApiConstants.requestPasswordReset), isFalse);
    });

    test('con un correo válido pide el código', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.requestPasswordReset, {'success': true});
      final vm = ForgotPasswordViewModel(repo: _repo(api));

      expect(await vm.enviar(_email), isTrue);
      expect(vm.enviando, isFalse);
      expect(
          api.ultima(ApiConstants.requestPasswordReset)?.body, {'email': _email});
    });

    test('si el backend falla, deja su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.requestPasswordReset, 'Correo no registrado');
      final vm = ForgotPasswordViewModel(repo: _repo(api));

      expect(await vm.enviar(_email), isFalse);
      expect(vm.error, 'Correo no registrado');
    });
  });

  group('ResetPasswordViewModel', () {
    test('validar revisa código y contraseña en orden', () {
      String? v(String c, String p, [String? conf]) =>
          ResetPasswordViewModel.validar(c, p, conf ?? p);

      expect(v('123', 'pastel1'), VerifyEmailViewModel.codigoIncompleto);
      expect(v('123456', 'pa1'),
          'La contraseña debe tener al menos 6 caracteres');
      expect(v('123456', '1234567'),
          'La contraseña debe contener al menos 1 letra');
      expect(v('123456', 'pastelito'),
          'La contraseña debe contener al menos 1 número');
      expect(v('123456', 'pastel1', 'pastel2'), 'Las contraseñas no coinciden');
      expect(v('123456', 'pastel1'), isNull);
    });

    test('lo capturado inválido no llama al backend', () async {
      final api = FakeApiClient();
      final vm = ResetPasswordViewModel(repo: _repo(api), email: _email);

      expect(await vm.restablecer('123456', 'pastel1', 'pastel2'), isFalse);
      expect(vm.error, 'Las contraseñas no coinciden');
      expect(api.llamo(ApiConstants.resetPassword), isFalse);
    });

    test('con todo válido restablece la contraseña', () async {
      final api = FakeApiClient()
        ..responder(ApiConstants.resetPassword, {'success': true});
      final vm = ResetPasswordViewModel(repo: _repo(api), email: _email);

      expect(await vm.restablecer('123456', 'pastel1', 'pastel1'), isTrue);
      expect(vm.restableciendo, isFalse);
      expect(api.ultima(ApiConstants.resetPassword)?.body, {
        'email': _email,
        'codigo': '123456',
        'nuevaPassword': 'pastel1',
      });
    });

    test('un código rechazado deja el mensaje del backend', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.resetPassword, 'Código expirado');
      final vm = ResetPasswordViewModel(repo: _repo(api), email: _email);

      expect(await vm.restablecer('123456', 'pastel1', 'pastel1'), isFalse);
      expect(vm.error, 'Código expirado');
    });
  });
}
