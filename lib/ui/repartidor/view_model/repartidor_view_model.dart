// lib/ui/repartidor/view_model/repartidor_view_model.dart
//
// Estado del panel del repartidor (MVVM, Fase 5): sus entregas, el pool de
// pedidos que puede tomar y su disponibilidad. Lo crea RepartidorMainScreen
// y lo comparten sus tres pestañas (Entregas, Historial y Perfil), que
// muestran cortes distintos de los mismos datos. El detalle, la confirmación
// y el reporte de fallo avisan con [recargar] cuando cambian una entrega.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/accion_entrega_view_model.dart';

class RepartidorViewModel extends ChangeNotifier {
  RepartidorViewModel({required EntregasRepository repo}) : _repo = repo;

  final EntregasRepository _repo;
  final Set<String> _aceptando = {};
  bool _cerrado = false;

  List<EntregaRepartidor> _entregas = [];
  List<PedidoDisponible> _disponibles = [];
  bool _disponible = false;
  bool _cargando = false;
  String? _errorCarga;

  List<PedidoDisponible> get disponibles => _disponibles;
  bool get disponible => _disponible;
  bool get cargando => _cargando;

  /// Por qué no se pudieron traer las entregas en la última carga (se
  /// conservan las que había).
  String? get errorCarga => _errorCarga;

  /// Entregas en curso (asignada / en camino), en orden del backend.
  List<EntregaRepartidor> get activas =>
      _entregas.where((e) => e.isActiva).toList();

  /// Entregas finalizadas hoy (entregada / fallida).
  List<EntregaRepartidor> get historial =>
      _entregas.where((e) => !e.isActiva).toList();

  int get entregadasCount => _entregadas.length;

  int get fallidasCount =>
      _entregas.where((e) => e.estado == EstadoEntrega.fallida).length;

  /// Suma cobrada de las entregas completadas hoy.
  double get totalDia => _entregadas.fold(0, (suma, e) => suma + e.total);

  Iterable<EntregaRepartidor> get _entregadas =>
      _entregas.where((e) => e.estado == EstadoEntrega.entregada);

  /// El pedido del pool espera la respuesta de «Tomar entrega».
  bool aceptando(PedidoDisponible pedido) =>
      _aceptando.contains(pedido.pedidoId);

  /// Primera carga, con indicador.
  Future<void> cargar() async {
    _cargando = true;
    notifyListeners();
    await recargar();
  }

  /// Trae entregas, disponibilidad y pool sin indicador (jalar para
  /// refrescar, o tras cambiar una entrega). Si la disponibilidad o el pool
  /// fallan se queda lo que había, como antes.
  Future<void> recargar() async {
    _errorCarga = null;
    await Future.wait([
      _intentar(_repo.misEntregas(), (v) => _entregas = v,
          alFallar: (m) => _errorCarga = m),
      _intentar(_repo.disponibilidad(), (v) => _disponible = v),
      _intentar(_repo.disponibles(), (v) => _disponibles = v),
    ]);
    _cargando = false;
    _avisar();
  }

  /// Toma un pedido del pool; si lo consigue, recarga para moverlo a «En
  /// curso». Devuelve el mensaje para el repartidor.
  Future<ResultadoEntrega> aceptar(PedidoDisponible pedido) async {
    if (!_aceptando.add(pedido.pedidoId)) {
      return (ok: false, mensaje: 'Ya estás tomando este pedido');
    }
    notifyListeners();
    ResultadoEntrega resultado;
    try {
      final mensaje = await _repo.aceptar(pedido.pedidoId);
      await recargar();
      resultado = (ok: true, mensaje: mensaje);
    } on ApiException catch (e) {
      resultado = (ok: false, mensaje: e.message);
    }
    _aceptando.remove(pedido.pedidoId);
    _avisar();
    return resultado;
  }

  /// Cambia la disponibilidad al instante y la revierte si el backend la
  /// rechaza. Devuelve si quedó guardada.
  Future<bool> cambiarDisponible({required bool valor}) async {
    final previo = _disponible;
    _disponible = valor;
    notifyListeners();
    try {
      _disponible = await _repo.cambiarDisponibilidad(disponible: valor);
      _avisar();
      return true;
    } on ApiException {
      _disponible = previo;
      _avisar();
      return false;
    }
  }

  Future<void> _intentar<T>(
    Future<T> llamada,
    ValueSetter<T> guardar, {
    ValueSetter<String>? alFallar,
  }) async {
    try {
      guardar(await llamada);
    } on ApiException catch (e) {
      alFallar?.call(e.message);
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
