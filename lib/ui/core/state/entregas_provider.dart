// lib/ui/core/state/entregas_provider.dart
//
// Estado del módulo Repartidor. Consume /api/entregas (mis-entregas,
// disponibilidad, :id/estado) y /api/upload/imagen para la evidencia.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

class EntregasProvider with ChangeNotifier {
  final EntregasRepository _repo;

  EntregasProvider({EntregasRepository? repo})
      : _repo = repo ?? EntregasRepository();

  List<EntregaRepartidor> _entregas = [];
  List<PedidoDisponible> _disponibles = [];
  bool _disponible = false;
  bool _isLoading = false;
  String? _error;

  List<EntregaRepartidor> get entregas => _entregas;
  List<PedidoDisponible> get disponibles => _disponibles;
  bool get disponible => _disponible;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Entregas en curso (asignada / en camino), en orden del backend.
  List<EntregaRepartidor> get activas =>
      _entregas.where((e) => e.isActiva).toList();

  /// Entregas finalizadas hoy (entregada / fallida).
  List<EntregaRepartidor> get historial =>
      _entregas.where((e) => !e.isActiva).toList();

  int get entregadasCount =>
      _entregas.where((e) => e.estado == EstadoEntrega.entregada).length;

  int get fallidasCount =>
      _entregas.where((e) => e.estado == EstadoEntrega.fallida).length;

  /// Suma cobrada de las entregas completadas hoy.
  double get totalDia => _entregas
      .where((e) => e.estado == EstadoEntrega.entregada)
      .fold(0.0, (sum, e) => sum + e.total);

  /// Carga entregas + disponibilidad. `silent` para pull-to-refresh.
  Future<void> cargar({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    final results = await Future.wait([
      _repo.misEntregas(),
      _repo.disponibilidad(),
      _repo.disponibles(),
    ]);

    final entregasRes = results[0];
    if (entregasRes['success'] == true) {
      final data = entregasRes['entregas'] ?? [];
      _entregas = (data as List)
          .map((j) => EntregaRepartidor.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      _error = entregasRes['message']?.toString();
    }

    final dispRes = results[1];
    if (dispRes['success'] == true) {
      _disponible = dispRes['disponible'] == true;
    }

    final poolRes = results[2];
    if (poolRes['success'] == true) {
      final data = poolRes['pedidos'] ?? [];
      _disponibles = (data as List)
          .map((j) => PedidoDisponible.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Toma un pedido del pool. Devuelve el mapa de respuesta del backend
  /// ({success, message, ...}). En éxito recarga para moverlo a "activas".
  Future<Map<String, dynamic>> aceptar(String pedidoId) async {
    final res = await _repo.aceptar(pedidoId);
    if (res['success'] == true) {
      await cargar(silent: true);
    }
    return res;
  }

  /// Cambia mi disponibilidad. Optimista con reversión si falla.
  Future<bool> setDisponible(bool value) async {
    final previo = _disponible;
    _disponible = value;
    notifyListeners();

    final res = await _repo.cambiarDisponibilidad(value);

    if (res['success'] == true) {
      _disponible = res['disponible'] == true;
      notifyListeners();
      return true;
    }

    _disponible = previo;
    _error = res['message']?.toString();
    notifyListeners();
    return false;
  }

  /// Sube una foto de evidencia y devuelve su URL (o null si falla).
  Future<String?> subirEvidencia(String filePath) async {
    final res = await _repo.subirEvidencia(filePath);
    if (res['success'] == true && res['imagen'] is Map) {
      return (res['imagen'] as Map)['url']?.toString();
    }
    return null;
  }

  /// Aviso "llegué al domicilio": el backend notifica al cliente (push +
  /// email) SIN cambiar el estado. Solo válido estando en camino.
  Future<Map<String, dynamic>> avisarLlegada(String entregaId) {
    return _repo.avisarLlegada(entregaId);
  }

  /// Transición de estado de una entrega. Devuelve el mapa de respuesta del
  /// backend ({success, message, ...}). Al terminar recarga la lista.
  Future<Map<String, dynamic>> cambiarEstado(
    String entregaId,
    EstadoEntrega nuevo, {
    String? evidenciaUrl,
    String? recibioNombre,
    String? motivoFallo,
  }) async {
    final body = <String, dynamic>{'estado': nuevo.apiValue};
    if (evidenciaUrl != null) body['evidencia_url'] = evidenciaUrl;
    if (recibioNombre != null) body['recibio_nombre'] = recibioNombre;
    if (motivoFallo != null) body['motivo_fallo'] = motivoFallo;

    final res = await _repo.cambiarEstado(entregaId, body);

    if (res['success'] == true) {
      await cargar(silent: true);
    }
    return res;
  }

  void clear() {
    _entregas = [];
    _disponibles = [];
    _disponible = false;
    _error = null;
    notifyListeners();
  }
}
