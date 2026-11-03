// lib/ui/more/view_model/more_view_model.dart
//
// Estado de la pestaña «Más» (MVVM, Fase 3): los datos de «Encuéntranos» y
// los contadores del cliente (pedidos, favoritos, reseñas). Si el contacto no
// llega se muestra el último que llegó (#312) o lo de BusinessInfo; si falla
// un contador, 0, como antes. La sesión, la navegación y el
// cierre de sesión siguen en la vista (usan los providers globales).
import 'package:flutter/foundation.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository.dart';
import 'package:pier_reposteria/domain/models/info_contacto.dart';

class MoreViewModel extends ChangeNotifier {
  MoreViewModel({
    required ConfiguracionRepository configRepo,
    required PedidosRepository pedidosRepo,
    required FavoritosRepository favoritosRepo,
    required ResenasRepository resenasRepo,
  })  : _configRepo = configRepo,
        _pedidosRepo = pedidosRepo,
        _favoritosRepo = favoritosRepo,
        _resenasRepo = resenasRepo;

  final ConfiguracionRepository _configRepo;
  final PedidosRepository _pedidosRepo;
  final FavoritosRepository _favoritosRepo;
  final ResenasRepository _resenasRepo;
  bool _cerrado = false;

  InfoContacto _contacto = const InfoContacto();
  bool _cargandoContacto = true;
  bool _pidiendoContacto = false;

  /// El contacto que se ve llegó del servidor (si no, es el guardado o el de
  /// BusinessInfo y se vuelve a pedir al regresar a la pestaña).
  bool _contactoAlDia = false;

  int _totalPedidos = 0;
  int _totalFavoritos = 0;
  int _totalResenas = 0;
  bool _cargandoStats = true;

  /// Correo de la sesión de la que son los contadores (para no recargar si
  /// la sesión no cambió). null = invitado.
  String? _emailStats;
  bool _statsIniciados = false;

  /// Campos vacíos (null) si el backend no los manda o falla.
  InfoContacto get contacto => _contacto;
  bool get cargandoContacto => _cargandoContacto;

  int get totalPedidos => _totalPedidos;
  int get totalFavoritos => _totalFavoritos;
  int get totalResenas => _totalResenas;
  bool get cargandoStats => _cargandoStats;

  Future<void> cargarContacto() async {
    if (_pidiendoContacto) return;
    _pidiendoContacto = true;
    try {
      _contacto = await _configRepo.contacto();
      _contactoAlDia = true;
    } on ApiException {
      // Sin red: el último que llegó; si nunca llegó, se queda vacío y la
      // vista usa BusinessInfo.
      _contactoAlDia = false;
      final guardado = await _configRepo.contactoGuardado();
      if (guardado != null) _contacto = guardado;
    } finally {
      _pidiendoContacto = false;
    }
    if (_cerrado) return;
    _cargandoContacto = false;
    notifyListeners();
  }

  /// Al volver a la pestaña: si el contacto no llegó del servidor (sin red al
  /// abrir la app), se vuelve a pedir (#312).
  Future<void> reintentarContacto() async {
    if (_contactoAlDia) return;
    await cargarContacto();
  }

  /// Avisa quién tiene la sesión. Si cambió, recarga los contadores (con
  /// sesión) o los deja en 0 (invitado).
  Future<void> actualizarSesion({
    required bool autenticado,
    required String? email,
  }) async {
    if (_statsIniciados && email == _emailStats) return;
    _statsIniciados = true;
    _emailStats = email;

    if (!autenticado || email == null) {
      _totalPedidos = 0;
      _totalFavoritos = 0;
      _totalResenas = 0;
      _cargandoStats = false;
      notifyListeners();
      return;
    }

    _cargandoStats = true;
    notifyListeners();
    final conteos = await Future.wait([
      _contar(() async => (await _pedidosRepo.listarMisPedidos()).length),
      _contar(() async => (await _favoritosRepo.listarIds()).length),
      _contar(() async => (await _resenasRepo.listarMisResenas()).length),
    ]);
    // Si mientras tanto cambió la sesión, estos números ya no aplican.
    if (_cerrado || email != _emailStats) return;
    _totalPedidos = conteos[0];
    _totalFavoritos = conteos[1];
    _totalResenas = conteos[2];
    _cargandoStats = false;
    notifyListeners();
  }

  /// 0 si el backend falla.
  Future<int> _contar(Future<int> Function() contar) async {
    try {
      return await contar();
    } on ApiException {
      return 0;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
