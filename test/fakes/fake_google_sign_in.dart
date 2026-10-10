// test/fakes/fake_google_sign_in.dart — doble del selector de cuentas de
// Google para AuthRepositoryRemote(google: ...): en pruebas no hay plugin.
//
//   FakeGoogleSignIn(idToken: 'id-token') // eligió una cuenta
//   FakeGoogleSignIn()                    // cerró el selector
//   FakeGoogleSignIn(error: Exception())  // el plugin falló
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  /// Sin [idToken] ni [conCuenta], simula que el usuario cerró el selector.
  /// [conCuenta] sin [idToken] simula una cuenta que no entregó token.
  FakeGoogleSignIn({this.idToken, bool conCuenta = false, this.error})
      : _conCuenta = conCuenta || idToken != null;

  final String? idToken;
  final bool _conCuenta;
  final Exception? error;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (error != null) throw error!;
    return _conCuenta ? _CuentaFalsa(idToken) : null;
  }
}

class _CuentaFalsa extends Fake implements GoogleSignInAccount {
  _CuentaFalsa(this._idToken);

  final String? _idToken;

  @override
  Future<GoogleSignInAuthentication> get authentication async =>
      _TokensFalsos(_idToken);
}

class _TokensFalsos extends Fake implements GoogleSignInAuthentication {
  _TokensFalsos(this.idToken);

  @override
  final String? idToken;
}
