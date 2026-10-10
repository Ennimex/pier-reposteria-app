// lib/data/repositories/cuenta_repository.dart
//
// Única puerta a los datos de la cuenta del cliente (perfil, Alexa, contacto). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es CuentaRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos que ya tienen ViewModel devuelven modelos tipados y
// lanzan ApiException si el backend falla (generarCodigoAlexa,
// actualizarPerfil, enviarContacto).
import 'package:pier_pasteleria/domain/models/codigo_alexa.dart';

abstract class CuentaRepository {
  /// PUT /usuarios/perfil/actualizar -> {user: {id, nombre, apellido, email,
  /// telefono, avatar_url, rol}}. Devuelve ese `user` crudo porque
  /// AuthProvider guarda la sesión como Map (se tipa al adelgazar providers,
  /// Fase 5). Ojo: el backend usa COALESCE, así que `telefono: null` conserva
  /// el teléfono anterior (no lo borra).
  Future<Map<String, dynamic>> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  });

  /// POST /auth/alexa/generar-codigo -> {codigo, expira_en_segundos}
  Future<CodigoAlexa> generarCodigoAlexa();

  /// POST /contacto: con sesión va autenticado (queda ligado al usuario).
  /// [telefono] vacío se manda como null. Lanza ApiException con el mensaje
  /// del backend si no se envió.
  Future<void> enviarContacto({
    required String nombre,
    required String email,
    required String telefono,
    required String tipoProducto,
    required String mensaje,
    required bool conSesion,
  });
}
