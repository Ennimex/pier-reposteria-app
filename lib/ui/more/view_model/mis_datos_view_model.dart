// lib/ui/more/view_model/mis_datos_view_model.dart
//
// Estado de «Mis datos» (derecho de acceso, #221): lo que el servidor tiene
// de la cuenta, leído de GET /auth/profile, no la copia que la app guardó al
// iniciar sesión. También arma el correo para pedir que se elimine la cuenta
// (#222).
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/config/business_info.dart';
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
  Map<String, dynamic> _usuario = const {};
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
      _usuario = Map<String, dynamic>.from(usuario);
      _datos = datosDeCuenta(_usuario);
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
      return valor == null ? 'Sin dato' : fechaConHora(valor);
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

  /// El correo para pedir que se elimine esta cuenta (#222).
  Uri get correoParaEliminarCuenta => correoDeBaja(_usuario);

  static const asuntoBaja = 'Eliminar mi cuenta';

  static const peticionBaja =
      'Quiero que eliminen mi cuenta de la app de Pier Repostería y que '
      'borren mis datos (derecho de cancelación).';

  /// Mientras el backend no tenga cómo borrar la cuenta, la baja se pide por
  /// correo a Pier, como dice el aviso de privacidad. Lleva el correo y el
  /// nombre de la cuenta para que Pier sepa cuál es.
  static Uri correoDeBaja(Map<String, dynamic> usuario) {
    String dato(String clave) => usuario[clave]?.toString().trim() ?? '';
    final nombre = [dato('nombre'), dato('apellido')]
        .where((parte) => parte.isNotEmpty)
        .join(' ');
    final cuerpo = [
      'Hola, Pier:',
      '',
      peticionBaja,
      '',
      if (dato('email').isNotEmpty) 'Correo de la cuenta: ${dato('email')}',
      if (nombre.isNotEmpty) 'Nombre: $nombre',
    ].join('\n').trimRight();
    // Con queryParameters los espacios saldrían como «+», que algunas apps
    // de correo dejan tal cual; así salen como %20.
    String consulta(Map<String, String> partes) => partes.entries
        .map((parte) => '${parte.key}=${Uri.encodeComponent(parte.value)}')
        .join('&');
    return Uri(
      scheme: 'mailto',
      path: BusinessInfo.email,
      query: consulta({'subject': asuntoBaja, 'body': cuerpo}),
    );
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
