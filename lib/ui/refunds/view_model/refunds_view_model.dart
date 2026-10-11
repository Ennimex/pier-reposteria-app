// lib/ui/refunds/view_model/refunds_view_model.dart
//
// Estado de «Reembolsos» (MVVM, Fase 3): el historial de solicitudes y el
// formulario de nueva solicitud (pedido, motivo, fotos y envío). Solo se
// ofrecen los pedidos 'completado', igual que valida el backend. Si una
// carga falla la lista se queda como estaba (la pantalla no muestra error).
//
// Fotos de evidencia (#117): hasta [maxFotos], opcionales. Se suben al
// enviar; si una falla no se manda la solicitud a medias, y las que ya
// subieron no se vuelven a subir al reintentar.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/reembolso.dart';

class RefundsViewModel extends ChangeNotifier {
  RefundsViewModel({
    required ReembolsosRepository reembolsosRepo,
    required PedidosRepository pedidosRepo,
  })  : _reembolsosRepo = reembolsosRepo,
        _pedidosRepo = pedidosRepo;

  /// Código → texto; se envía el código ([Reembolso.motivos]).
  static const Map<String, String> motivos = Reembolso.motivos;

  static const int maxFotos = 3;

  final ReembolsosRepository _reembolsosRepo;
  final PedidosRepository _pedidosRepo;
  bool _cerrado = false;

  List<Reembolso> _reembolsos = const [];
  bool _cargandoReembolsos = true;
  List<Order> _pedidos = const [];
  Order? _pedidoElegido;
  String? _motivo;
  bool _enviando = false;
  List<String> _fotos = const [];
  final Map<String, String> _subidas = {}; // ruta local -> URL

  List<Reembolso> get reembolsos => _reembolsos;
  bool get cargandoReembolsos => _cargandoReembolsos;

  /// Pedidos que se pueden reembolsar (estado 'completado').
  List<Order> get pedidos => _pedidos;

  /// El elegido o, si no se ha elegido, el primero (el que ya muestra el
  /// selector cerrado).
  Order? get pedidoSeleccionado =>
      _pedidoElegido ?? (_pedidos.isEmpty ? null : _pedidos.first);
  String? get motivo => _motivo;
  bool get enviando => _enviando;

  /// Rutas locales de las fotos elegidas, en orden.
  List<String> get fotos => _fotos;
  bool get puedeAgregarFoto => _fotos.length < maxFotos;

  /// Carga el historial y los pedidos a la vez.
  Future<void> cargar() =>
      Future.wait([cargarReembolsos(), _cargarPedidos()]);

  Future<void> cargarReembolsos() async {
    _cargandoReembolsos = true;
    notifyListeners();
    try {
      _reembolsos = await _reembolsosRepo.listarMisReembolsos();
    } on ApiException {
      // Se queda la lista anterior.
    }
    if (_cerrado) return;
    _cargandoReembolsos = false;
    notifyListeners();
  }

  Future<void> _cargarPedidos() async {
    try {
      final todos = await _pedidosRepo.listarMisPedidos();
      _pedidos = todos
          .where((p) => p.status == OrderStatus.completed)
          .toList();
    } on ApiException {
      // Sin pedidos para elegir.
    }
    if (_cerrado) return;
    notifyListeners();
  }

  void seleccionarPedido(Order? pedido) {
    _pedidoElegido = pedido;
    notifyListeners();
  }

  void seleccionarMotivo(String? motivo) {
    _motivo = motivo;
    notifyListeners();
  }

  void agregarFoto(String ruta) {
    if (!puedeAgregarFoto || _fotos.contains(ruta)) return;
    _fotos = [..._fotos, ruta];
    notifyListeners();
  }

  void quitarFoto(String ruta) {
    _fotos = [..._fotos]..remove(ruta);
    notifyListeners();
  }

  /// Envía la solicitud por el total del pedido. Devuelve null si se envió
  /// (limpia el formulario y recarga el historial) o el mensaje de error.
  Future<String?> enviar({required String descripcion}) async {
    final pedido = pedidoSeleccionado;
    if (pedido == null) return 'Selecciona un pedido';
    final motivo = _motivo;
    if (motivo == null) return 'Selecciona un motivo';
    if (_enviando) return null;

    _enviando = true;
    notifyListeners();
    String? error;
    final urls = await _subirFotos();
    if (urls == null) {
      error = 'No se pudo subir una de las fotos. Intenta de nuevo.';
    } else {
      try {
        await _reembolsosRepo.solicitar(
          pedidoId: pedido.id,
          monto: pedido.total,
          motivo: motivo,
          descripcion: descripcion.trim(),
          fotos: urls,
        );
      } on ApiException catch (e) {
        error = e.message;
      }
    }
    if (_cerrado) return error;

    _enviando = false;
    if (error == null) {
      _pedidoElegido = null;
      _motivo = null;
      _fotos = const [];
      _subidas.clear();
    }
    notifyListeners();
    // El historial se recarga sin hacer esperar la confirmación.
    if (error == null) unawaited(cargarReembolsos());
    return error;
  }

  /// URLs de las fotos en orden, subiendo solo las que falten; null si
  /// alguna no se pudo subir.
  Future<List<String>?> _subirFotos() async {
    for (final ruta in _fotos) {
      if (_subidas.containsKey(ruta)) continue;
      try {
        _subidas[ruta] = await _reembolsosRepo.subirEvidencia(ruta);
      } on ApiException {
        return null;
      }
    }
    return [for (final ruta in _fotos) _subidas[ruta]!];
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
