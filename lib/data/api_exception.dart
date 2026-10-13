// lib/data/api_exception.dart
//
// Error que lanzan los repositorios tipados (MVVM, Fase 3 en adelante) cuando
// el backend responde {success: false} o falta un dato obligatorio. Lleva el
// mensaje listo para mostrarse al usuario; el ViewModel lo atrapa y lo expone.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// El backend rechazó la sesión (`codigo: 'SESION_INVALIDA'`): la cuenta se
/// desactivó o cambió de rol. Comandas y publicaciones releen al usuario en
/// cada petición; la vista debe cerrar la sesión y volver al login.
class SesionInvalidaException extends ApiException {
  const SesionInvalidaException(super.message);
}
