// lib/ui/checkout/view_model/direccion_form_view_model.dart
//
// Estado del formulario "Nueva / Editar dirección" del checkout (MVVM, Fase
// 4): colonias con cobertura y su tarifa, la elegida y el guardado. Los
// textos viven en los controladores de la vista. «Usar mi ubicación» (#227)
// agrega las coordenadas, que el repartidor usa para llegar.
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository.dart';
import 'package:pier_reposteria/data/services/ubicacion_service.dart';
import 'package:pier_reposteria/domain/models/direccion_model.dart';
import 'package:pier_reposteria/domain/models/zona_colonia.dart';

class DireccionFormViewModel extends ChangeNotifier {
  DireccionFormViewModel({
    required DireccionesRepository repo,
    this.editar,
    Ubicador ubicador = const UbicadorDelTelefono(),
  })  : _repo = repo,
        _ubicador = ubicador;

  final DireccionesRepository _repo;
  final Ubicador _ubicador;

  /// La dirección que se edita (null = nueva).
  final DireccionCliente? editar;
  bool _cerrado = false;

  List<ZonaColonia> _colonias = const [];
  String? _colonia;
  bool _cargandoColonias = true;
  bool _guardando = false;
  bool _ubicando = false;
  EstadoUbicacion? _estadoUbicacion;
  double? _lat;
  double? _lng;

  bool get esEdicion => editar != null;
  List<ZonaColonia> get colonias => _colonias;
  String? get colonia => _colonia;
  bool get cargandoColonias => _cargandoColonias;
  bool get guardando => _guardando;
  bool get ubicando => _ubicando;

  /// Cómo terminó el último «Usar mi ubicación» (null si no se ha usado).
  EstadoUbicacion? get estadoUbicacion => _estadoUbicacion;

  /// ¿Ya se agregaron las coordenadas del teléfono?
  bool get conUbicacion => _lat != null && _lng != null;

  /// El texto bajo el botón, según cómo terminó.
  String? get avisoUbicacion => switch (_estadoUbicacion) {
        null => null,
        EstadoUbicacion.lista => 'Ubicación agregada: el repartidor llegará '
            'a este punto.',
        EstadoUbicacion.servicioApagado =>
          'Activa la ubicación del teléfono e intenta de nuevo.',
        EstadoUbicacion.sinPermiso =>
          'Sin permiso de ubicación: puedes guardar la dirección así.',
        EstadoUbicacion.sinPermisoParaSiempre =>
          'El permiso de ubicación está apagado. Puedes darlo en Ajustes.',
        EstadoUbicacion.fallo =>
          'No pudimos leer tu ubicación. Puedes guardar la dirección así.',
      };

  /// Pide el permiso (si hace falta) y agrega las coordenadas del teléfono.
  /// La vista ya explicó para qué se piden.
  Future<void> usarMiUbicacion() async {
    if (_ubicando) return;
    _ubicando = true;
    notifyListeners();
    final resultado = await _ubicador.ubicacionActual();
    if (_cerrado) return;
    _estadoUbicacion = resultado.estado;
    if (resultado.estado == EstadoUbicacion.lista) {
      _lat = resultado.lat;
      _lng = resultado.lng;
    }
    _ubicando = false;
    notifyListeners();
  }

  /// Abre los ajustes de la app para dar el permiso.
  Future<bool> abrirAjustes() => _ubicador.abrirAjustes();

  /// Tarifa de envío de la colonia elegida.
  double? get tarifa =>
      _colonias.where((c) => c.colonia == _colonia).firstOrNull?.tarifa;

  /// En edición preselecciona la colonia actual si sigue con cobertura.
  Future<void> cargarColonias() async {
    try {
      _colonias = await _repo.listarColonias();
      final actual = editar?.colonia;
      if (actual != null && _colonias.any((c) => c.colonia == actual)) {
        _colonia = actual;
      }
    } on ApiException {
      // Sin colonias: la vista avisa que no hay cobertura.
    }
    if (_cerrado) return;
    _cargandoColonias = false;
    notifyListeners();
  }

  void elegirColonia(String? colonia) {
    _colonia = colonia;
    notifyListeners();
  }

  /// Guarda la dirección. En edición la colonia puede quedar sin tocar (el
  /// backend conserva la actual); al crear es obligatoria. Devuelve la
  /// dirección guardada o el mensaje de error.
  Future<(DireccionCliente?, String?)> guardar({
    required String alias,
    required String calle,
    required String referencias,
    required String telefono,
  }) async {
    if (alias.trim().isEmpty ||
        calle.trim().isEmpty ||
        (_colonia == null && !esEdicion)) {
      return (null, 'Completa alias, calle y número, y colonia');
    }
    _guardando = true;
    notifyListeners();
    try {
      final guardada = await _repo.guardarDireccion({
        'alias': alias.trim(),
        'calle_numero': calle.trim(),
        if (_colonia != null) 'colonia': _colonia,
        'referencias': referencias.trim(),
        'telefono_contacto': telefono.trim(),
        if (conUbicacion) ...{'lat': _lat, 'lng': _lng},
      }, id: editar?.id);
      return (guardada, null);
    } on ApiException catch (e) {
      return (null, e.message);
    } finally {
      if (!_cerrado) {
        _guardando = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
