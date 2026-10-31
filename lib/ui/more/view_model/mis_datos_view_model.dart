// lib/ui/more/view_model/mis_datos_view_model.dart
//
// Estado de «Mis datos» (derecho de acceso, #221): lo que el servidor tiene
// de la cuenta, leído de GET /auth/profile, no la copia que la app guardó al
// iniciar sesión.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/utils/formatters.dart';

/// Un dato de la cuenta tal como se muestra: etiqueta y valor.
typedef DatoDeCuenta = ({String etiqueta, String valor});

class MisDatosViewModel extends ChangeNotifier {
  MisDatosViewModel({required AuthRepository repo}) : _repo = repo;

  static const sinConexion =
      'No pudimos consultar tus datos. Intenta de nuevo.';

  final AuthRepository _repo;
  bool _cerrado = false;
  bool _cargando = true;
  String? _error;
  List<DatoDeCuenta> _datos = const [];

  bool get cargando => _cargando;
  String? get error => _error;
  List<DatoDeCuenta> get datos => _datos;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    final resultado = await _repo.getProfile();
    if (_cerrado) return;
    final usuario = resultado['user'];
    if (resultado['success'] == true && usuario is Map) {
      _datos = datosDeCuenta(Map<String, dynamic>.from(usuario));
    } else {
      _error = resultado['message']?.toString() ?? sinConexion;
    }
    _cargando = false;
    notifyListeners();
  }

  /// Los datos que guarda el servidor, en el orden en que se muestran.
  static List<DatoDeCuenta> datosDeCuenta(Map<String, dynamic> usuario) {
    String texto(String clave) {
      final valor = usuario[clave]?.toString().trim() ?? '';
      return valor.isEmpty ? 'Sin dato' : valor;
    }

    String fecha(String clave) {
      final valor = DateTime.tryParse(usuario[clave]?.toString() ?? '');
      return valor == null ? 'Sin dato' : fechaConHora(valor.toLocal());
    }

    String siNo(Object? valor) => valor == true ? 'Sí' : 'No';

    return [
      (etiqueta: 'Nombre', valor: texto('nombre')),
      (etiqueta: 'Apellido', valor: texto('apellido')),
      (etiqueta: 'Correo', valor: texto('email')),
      (etiqueta: 'Teléfono', valor: texto('telefono')),
      (etiqueta: 'Tipo de cuenta', valor: _rolLegible(usuario['rol'])),
      (
        etiqueta: 'Entras con Google',
        valor: siNo((usuario['googleId']?.toString() ?? '').isNotEmpty),
      ),
      (etiqueta: 'Correo verificado', valor: siNo(usuario['emailVerificado'])),
      (etiqueta: 'Cuenta creada', valor: fecha('fechaRegistro')),
      (etiqueta: 'Último acceso', valor: fecha('ultimoAcceso')),
    ];
  }

  static String _rolLegible(Object? rol) => switch (rol?.toString()) {
        'cliente' => 'Cliente',
        'repartidor' => 'Repartidor',
        'empleado' => 'Empleado',
        'gerencia' => 'Gerencia',
        'direccion_general' => 'Dirección general',
        'hornos' => 'Hornos',
        'decoracion' => 'Decoración',
        final otro? when otro.isNotEmpty => otro,
        _ => 'Sin dato',
      };

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
