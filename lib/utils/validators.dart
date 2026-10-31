// lib/utils/validators.dart
//
// Reglas de los formularios de login y registro, en un solo lugar. Cada una
// devuelve el mensaje que ve el usuario, o null si el valor es válido, para
// usarse directo como `validator:` de un TextFormField.
class Validators {
  Validators._();

  static String? email(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu email';
    if (!v.contains('@')) return 'Email inválido';
    return null;
  }

  /// Contraseña al iniciar sesión: solo se exige longitud mínima.
  static String? passwordLogin(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  /// Contraseña nueva (registro): longitud mínima, una letra y un número.
  static String? passwordNueva(String? v) {
    if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
      return 'Debe contener al menos 1 letra';
    }
    if (!RegExp(r'\d').hasMatch(v)) return 'Debe contener al menos 1 número';
    return null;
  }

  static String? confirmarPassword(String? v, String original) =>
      v != original ? 'Las contraseñas no coinciden' : null;

  static String? telefono(String? v) =>
      (v == null || v.length != 10) ? 'Debe tener 10 dígitos' : null;

  /// Teléfono que se puede dejar vacío (editar el perfil, #221): vacío borra
  /// el guardado; si trae algo, 10 dígitos como pide el backend (ignora
  /// espacios y guiones, y la lada +52).
  static String? telefonoOpcional(String? v) {
    final texto = v?.trim() ?? '';
    if (texto.isEmpty) return null;
    var digitos = texto.replaceAll(RegExp(r'\D'), '');
    if (digitos.length == 12 && digitos.startsWith('52')) {
      digitos = digitos.substring(2);
    }
    return digitos.length == 10 ? null : 'Debe tener 10 dígitos';
  }

  static String? nombre(String? v) =>
      (v == null || v.length < 2) ? 'Mínimo 2 caracteres' : null;
}
