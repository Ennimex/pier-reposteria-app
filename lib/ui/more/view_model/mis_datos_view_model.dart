// lib/ui/more/view_model/mis_datos_view_model.dart
//
// Estado de «Mis datos» (derecho de acceso, #221): lo que el servidor tiene
// de la cuenta, leído de GET /auth/profile, no la copia que la app guardó al
// iniciar sesión. También da de baja la cuenta (derecho de cancelación,
// #222) con DELETE /usuarios/perfil y, si eso falla por la red o el
// servidor, arma el correo para pedírsela a Pier.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/auth_repository.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/utils/formatters.dart';

/// Un dato de la cuenta tal como se muestra: etiqueta y valor.
typedef DatoDeCuenta = ({String etiqueta, String valor});

/// Cómo terminó «Eliminar mi cuenta» (#222); la vista decide qué mostrar.
enum ResultadoBaja {
  /// La cuenta se eliminó y la sesión ya se cerró en el teléfono.
  eliminada,

  /// Ya había una baja en curso (doble toque): no se mandó otra.
  ocupado,

  /// Tiene pedidos sin entregar (409 `PEDIDOS_EN_CURSO`): se muestra el
  /// mensaje del backend ([MisDatosViewModel.avisoBaja]).
  pedidosEnCurso,

  /// Es una cuenta del personal (403): no se da de baja desde la app; se
  /// muestra el mensaje del backend.
  personal,

  /// El servidor rechazó la sesión (401): la app ya la cerró y avisa que
  /// expiró, como con cualquier otra petición.
  sesionVencida,

  /// Sin red o error del servidor: se ofrece pedir la baja por correo.
  error,
}

class MisDatosViewModel extends ChangeNotifier {
  MisDatosViewModel({
    required AuthRepository repo,
    required CuentaRepository cuenta,
  })  : _repo = repo,
        _cuenta = cuenta;

  static const sinConexion =
      'No pudimos consultar tus datos. Intenta de nuevo.';

  /// `codigo` del 409 de DELETE /usuarios/perfil.
  static const pedidosEnCurso = 'PEDIDOS_EN_CURSO';

  final AuthRepository _repo;
  final CuentaRepository _cuenta;
  bool _cerrado = false;
  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _usuario = const {};
  List<DatoDeCuenta> _datos = const [];
  bool _eliminando = false;
  String? _avisoBaja;

  bool get cargando => _cargando;
  String? get error => _error;
  List<DatoDeCuenta> get datos => _datos;

  /// La baja está en curso: el botón muestra que trabaja y no se vuelve a
  /// mandar.
  bool get eliminando => _eliminando;

  /// El mensaje del backend del último intento de baja que no se hizo.
  String? get avisoBaja => _avisoBaja;

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

  /// Da de baja la cuenta (#222). Si se eliminó, cierra la sesión con
  /// [cerrarSesion] (solo en el teléfono: el token ya no sirve), aunque la
  /// pantalla se haya cerrado mientras tanto.
  Future<ResultadoBaja> eliminarCuenta({
    required Future<void> Function() cerrarSesion,
  }) async {
    if (_eliminando) return ResultadoBaja.ocupado;
    _eliminando = true;
    _avisoBaja = null;
    notifyListeners();
    var resultado = ResultadoBaja.eliminada;
    try {
      await _cuenta.eliminarCuenta();
      await cerrarSesion();
    } on ApiException catch (e) {
      _avisoBaja = e.message;
      resultado = await _porQueNoSeElimino(e);
    } finally {
      _eliminando = false;
      if (!_cerrado) notifyListeners();
    }
    return resultado;
  }

  Future<ResultadoBaja> _porQueNoSeElimino(ApiException e) async {
    if (e.codigo == pedidosEnCurso) return ResultadoBaja.pedidosEnCurso;
    // Con un 401 ApiService ya borró la sesión del teléfono y la app avisa
    // que expiró (SesionInvalidaException es el de una cuenta inactiva).
    if (e is SesionInvalidaException || !await _repo.isAuthenticated()) {
      return ResultadoBaja.sesionVencida;
    }
    // El 403 no trae código: solo lo recibe una cuenta que no es de cliente.
    if ((_usuario['rol'] ?? 'cliente') != 'cliente') {
      return ResultadoBaja.personal;
    }
    return ResultadoBaja.error;
  }

  /// El correo para pedir que se elimine esta cuenta (#222).
  Uri get correoParaEliminarCuenta => correoDeBaja(_usuario);

  static const asuntoBaja = 'Eliminar mi cuenta';

  static const peticionBaja =
      'Quiero que eliminen mi cuenta de la app de Pier Repostería y que '
      'borren mis datos (derecho de cancelación).';

  /// Respaldo de la baja cuando la app no pudo hacerla (sin red o error del
  /// servidor): se pide por correo a Pier, como dice el aviso de privacidad.
  /// Lleva el correo y el nombre de la cuenta para que Pier sepa cuál es.
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
