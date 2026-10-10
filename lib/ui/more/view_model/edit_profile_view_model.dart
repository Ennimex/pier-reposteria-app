// lib/ui/more/view_model/edit_profile_view_model.dart
//
// Estado de «Editar Perfil» (MVVM, Fase 3). Parte de los datos de la sesión,
// lleva lo que el usuario va escribiendo (para las iniciales y para saber si
// hay cambios) y guarda en el backend. Los TextEditingController y la
// validación del formulario se quedan en la vista.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';

class EditProfileViewModel extends ChangeNotifier {
  /// [usuario] es la sesión actual (AuthProvider.currentUser).
  EditProfileViewModel({
    required CuentaRepository repo,
    Map<String, dynamic>? usuario,
  })  : _repo = repo,
        email = _texto(usuario, 'email'),
        _nombreGuardado = _texto(usuario, 'nombre'),
        _apellidoGuardado = _texto(usuario, 'apellido'),
        _telefonoGuardado = _texto(usuario, 'telefono') {
    _nombre = _nombreGuardado;
    _apellido = _apellidoGuardado;
    _telefono = _telefonoGuardado;
  }

  final CuentaRepository _repo;
  bool _cerrado = false;

  /// Solo lectura: el correo no se puede modificar.
  final String email;

  String _nombreGuardado;
  String _apellidoGuardado;
  String _telefonoGuardado;
  late String _nombre;
  late String _apellido;
  late String _telefono;
  bool _guardando = false;
  String? _error;

  /// Valores con los que la vista inicializa sus campos.
  String get nombre => _nombre;
  String get apellido => _apellido;
  String get telefono => _telefono;

  bool get guardando => _guardando;

  /// Mensaje del último intento fallido de guardar (null si no hubo).
  String? get error => _error;

  /// true si lo escrito difiere de lo guardado (ignora espacios de sobra).
  bool get hayCambios =>
      _nombre.trim() != _nombreGuardado.trim() ||
      _apellido.trim() != _apellidoGuardado.trim() ||
      _telefono.trim() != _telefonoGuardado.trim();

  /// Iniciales del avatar; 'U' si aún no hay nombre ni apellido.
  String get iniciales {
    final n = _nombre.trim();
    final a = _apellido.trim();
    final i = '${n.isNotEmpty ? n[0].toUpperCase() : ''}'
        '${a.isNotEmpty ? a[0].toUpperCase() : ''}';
    return i.isEmpty ? 'U' : i;
  }

  /// La vista lo llama cada vez que cambia un campo.
  void editar({
    required String nombre,
    required String apellido,
    required String telefono,
  }) {
    _nombre = nombre;
    _apellido = apellido;
    _telefono = telefono;
    notifyListeners();
  }

  /// Guarda en el backend. Devuelve el usuario actualizado (para refrescar la
  /// sesión) o null si falló; el motivo queda en [error]. Teléfono vacío se
  /// manda como null.
  Future<Map<String, dynamic>?> guardar() async {
    if (_guardando) return null;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      final tel = _telefono.trim();
      final usuario = await _repo.actualizarPerfil(
        nombre: _nombre.trim(),
        apellido: _apellido.trim(),
        telefono: tel.isEmpty ? null : tel,
      );
      if (_cerrado) return null;
      _nombreGuardado = _nombre;
      _apellidoGuardado = _apellido;
      _telefonoGuardado = _telefono;
      return usuario;
    } on ApiException catch (e) {
      if (_cerrado) return null;
      _error = e.message;
      return null;
    } finally {
      if (!_cerrado) {
        _guardando = false;
        notifyListeners();
      }
    }
  }

  static String _texto(Map<String, dynamic>? u, String clave) =>
      u?[clave]?.toString() ?? '';

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
