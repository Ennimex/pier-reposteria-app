// lib/data/api_exception.dart
//
// Error que lanzan los repositorios tipados (MVVM, Fase 3 en adelante) cuando
// el backend responde {success: false} o falta un dato obligatorio. Lleva el
// mensaje listo para mostrarse al usuario; el ViewModel lo atrapa y lo expone.
class ApiException implements Exception {
  const ApiException(this.message, {this.codigo});

  final String message;

  /// El `codigo` que mandó el backend con el error, si mandó uno (p. ej.
  /// `PEDIDOS_EN_CURSO` al dar de baja la cuenta, #222).
  final String? codigo;

  @override
  String toString() => 'ApiException: $message';
}

/// El backend rechazó la sesión (`codigo: 'SESION_INVALIDA'`): la cuenta se
/// desactivó o cambió de rol. Comandas y publicaciones releen al usuario en
/// cada petición; la vista debe cerrar la sesión y volver al login.
class SesionInvalidaException extends ApiException {
  const SesionInvalidaException(super.message)
      : super(codigo: 'SESION_INVALIDA');
}

/// 409 al confirmar «Enterado» de una comanda: [cambio] si otra persona la
/// editó mientras se leía (`VERSION_DESACTUALIZADA`, con [versionActual]);
/// si no, otra persona del área ya confirmó esa versión (`YA_CONFIRMADA`).
class ConflictoComandaException extends ApiException {
  const ConflictoComandaException(
    super.message, {
    required this.cambio,
    this.versionActual,
  });

  final bool cambio;
  final int? versionActual;
}

/// La publicación ya no está (la repostería la eliminó): 404
/// «Publicación no encontrada» del backend.
class PublicacionNoDisponibleException extends ApiException {
  const PublicacionNoDisponibleException(super.message);
}

/// La entrega ya estaba entregada al confirmarla (desde otro teléfono, o un
/// reintento cuyo primer envío sí llegó): el backend rechaza el paso
/// repetido con «No se puede pasar de "entregada" a "entregada"» (#270).
class EntregaYaConfirmadaException extends ApiException {
  const EntregaYaConfirmadaException(super.message);
}
