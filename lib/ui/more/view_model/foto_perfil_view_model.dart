// lib/ui/more/view_model/foto_perfil_view_model.dart
//
// Foto de perfil del cliente (#345), igual que en la web (FotoPerfil.tsx): la
// sube a Cloudinary (POST /upload/imagen, tipo perfil) y la pone en el perfil
// (PUT /usuarios/perfil/actualizar); quitarla manda `avatar_url: null`.
// Devuelve el usuario que respondió el backend para que la vista lo mezcle en
// la sesión (AuthProvider).
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/utils/logger.dart';

/// Qué se está haciendo con la foto.
enum TrabajoFoto { ninguno, subiendo, quitando }

class FotoPerfilViewModel extends ChangeNotifier {
  FotoPerfilViewModel({required CuentaRepository repo}) : _repo = repo;

  final CuentaRepository _repo;
  bool _cerrado = false;
  TrabajoFoto _trabajo = TrabajoFoto.ninguno;
  String? _error;

  TrabajoFoto get trabajo => _trabajo;
  bool get ocupado => _trabajo != TrabajoFoto.ninguno;

  /// Por qué falló lo último que se intentó, para mostrárselo al cliente.
  String? get error => _error;

  /// Sube la foto de [rutaArchivo] y la pone en el perfil. Devuelve el usuario
  /// del backend, o null si falló (el mensaje queda en [error]) o si ya había
  /// otra subida en curso. Si falla, la foto anterior se queda.
  Future<Map<String, dynamic>?> cambiar(String rutaArchivo) =>
      _hacer(TrabajoFoto.subiendo, () async {
        final url = await _repo.subirFotoPerfil(rutaArchivo);
        return _repo.actualizarFotoPerfil(url);
      });

  /// Quita la foto del perfil (vuelven las iniciales).
  Future<Map<String, dynamic>?> quitar() =>
      _hacer(TrabajoFoto.quitando, () => _repo.actualizarFotoPerfil(null));

  Future<Map<String, dynamic>?> _hacer(
    TrabajoFoto trabajo,
    Future<Map<String, dynamic>> Function() accion,
  ) async {
    if (ocupado) return null;
    _trabajo = trabajo;
    _error = null;
    _avisar();
    try {
      return await accion();
    } on ApiException catch (e) {
      PierLog.error('Foto de perfil (${trabajo.name}): ${e.message}');
      _error = e.message;
      return null;
    } finally {
      _trabajo = TrabajoFoto.ninguno;
      _avisar();
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
