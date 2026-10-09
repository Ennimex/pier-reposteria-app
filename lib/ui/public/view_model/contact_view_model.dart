// lib/ui/public/view_model/contact_view_model.dart
//
// Estado de «Contacto» (MVVM, Fase 3): los datos de «Otros medios», el tipo
// de consulta, el contador del mensaje y el envío. Arranca con BusinessInfo y
// lo reemplaza campo por campo con lo que Dirección haya capturado; si el
// backend falla se queda BusinessInfo. Los TextEditingController, la
// validación del Form, el diálogo y abrir WhatsApp se quedan en la vista.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/cuenta_repository.dart';

class ContactViewModel extends ChangeNotifier {
  ContactViewModel({
    required ConfiguracionRepository configRepo,
    required CuentaRepository cuentaRepo,
  })  : _configRepo = configRepo,
        _cuentaRepo = cuentaRepo;

  final ConfiguracionRepository _configRepo;
  final CuentaRepository _cuentaRepo;
  bool _cerrado = false;

  /// Mínimo de caracteres del mensaje (sin espacios de los extremos).
  static const int minimoMensaje = 20;

  static const List<String> tiposProducto = [
    'Información general', 'Pasteles', 'Roscas', 'Pays',
    'Postres', 'Cafetería', 'Pedidos', 'Reembolsos',
    'Sugerencias', 'Quejas', 'Otro',
  ];

  String _telefono = BusinessInfo.telefono;
  String _email = BusinessInfo.email;
  String _horario = BusinessInfo.horario;
  String _whatsapp = BusinessInfo.whatsappNumero;

  String _tipoProducto = tiposProducto.first;
  String _mensaje = '';
  bool _enviando = false;
  String? _error;

  String get telefono => _telefono;
  String get email => _email;
  String get horario => _horario;
  String get tipoProducto => _tipoProducto;
  bool get enviando => _enviando;

  /// Mensaje del último envío fallido.
  String? get error => _error;

  int get largoMensaje => _mensaje.trim().length;
  bool get mensajeValido => largoMensaje >= minimoMensaje;

  /// Solo dígitos para wa.me; si el panel capturó algo sin dígitos se usa el
  /// de BusinessInfo.
  String get numeroWhatsApp {
    final digitos = _whatsapp.replaceAll(RegExp('[^0-9]'), '');
    return digitos.isNotEmpty ? digitos : BusinessInfo.whatsappNumero;
  }

  Future<void> cargar() async {
    try {
      final info = await _configRepo.contacto();
      if (_cerrado) return;
      _telefono = info.telefono ?? _telefono;
      _email = info.email ?? _email;
      _whatsapp = info.whatsapp ?? _whatsapp;
      _horario = info.horario ?? _horario;
      notifyListeners();
    } on ApiException {
      // Se quedan los datos de BusinessInfo.
    }
  }

  void elegirTipo(String tipo) {
    if (tipo == _tipoProducto) return;
    _tipoProducto = tipo;
    notifyListeners();
  }

  /// La vista lo llama en cada cambio del campo (para el contador).
  void editarMensaje(String texto) {
    _mensaje = texto;
    notifyListeners();
  }

  /// Envía (la vista ya validó el Form). Devuelve true si se envió; si no,
  /// el motivo queda en [error].
  Future<bool> enviar({
    required String nombre,
    required String email,
    required String telefono,
    required bool conSesion,
  }) async {
    if (_enviando) return false;
    _enviando = true;
    _error = null;
    notifyListeners();
    var enviado = false;
    try {
      await _cuentaRepo.enviarContacto(
        nombre: nombre.trim(),
        email: email.trim(),
        telefono: telefono.trim(),
        tipoProducto: _tipoProducto,
        mensaje: _mensaje.trim(),
        conSesion: conSesion,
      );
      enviado = true;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (_cerrado) return enviado;
    _enviando = false;
    if (enviado) _mensaje = '';
    notifyListeners();
    return enviado;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
