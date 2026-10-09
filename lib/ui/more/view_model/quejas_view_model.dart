// lib/ui/more/view_model/quejas_view_model.dart
//
// Estado de «Mis Quejas» (MVVM, Fase 3): la lista (con la tarjeta abierta),
// los pedidos para asociar y el formulario de la hoja «Nueva». Si una carga
// falla la lista se queda como estaba (la pantalla no muestra error, como
// antes). Los textos del asunto y la descripción viven en la vista.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/queja.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Resultado de enviar: el ticket creado o el mensaje de error.
typedef EnvioQueja = ({String? ticket, String? error});

class QuejasViewModel extends ChangeNotifier {
  QuejasViewModel({
    required QuejasRepository quejasRepo,
    required PedidosRepository pedidosRepo,
  })  : _quejasRepo = quejasRepo,
        _pedidosRepo = pedidosRepo;

  final QuejasRepository _quejasRepo;
  final PedidosRepository _pedidosRepo;
  bool _cerrado = false;

  List<Queja> _quejas = const [];
  List<Order> _pedidos = const [];
  bool _cargando = true;
  String? _expandidaId;

  TipoQueja _tipo = TipoQueja.queja;
  CategoriaQueja _categoria = CategoriaQueja.producto;
  String? _pedidoId;
  bool _enviando = false;

  List<Queja> get quejas => _quejas;
  List<Order> get pedidos => _pedidos;
  bool get cargando => _cargando;
  String? get expandidaId => _expandidaId;

  TipoQueja get tipo => _tipo;
  CategoriaQueja get categoria => _categoria;
  String? get pedidoId => _pedidoId;
  bool get enviando => _enviando;

  /// Carga quejas y pedidos a la vez (también al jalar para recargar).
  Future<void> cargar() async {
    _cargando = true;
    notifyListeners();
    await Future.wait([_cargarQuejas(), _cargarPedidos()]);
    if (_cerrado) return;
    _cargando = false;
    notifyListeners();
  }

  Future<void> _cargarQuejas() async {
    try {
      _quejas = await _quejasRepo.listarMisQuejas();
      PierLog.info('✅ Quejas cargadas: ${_quejas.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar quejas: ${e.message}');
    }
  }

  Future<void> _cargarPedidos() async {
    try {
      _pedidos = await _pedidosRepo.listarMisPedidos();
    } on ApiException {
      // Sin pedidos para asociar.
    }
  }

  /// Abre la tarjeta [id] o la cierra si ya estaba abierta.
  void alternar(String id) {
    _expandidaId = _expandidaId == id ? null : id;
    notifyListeners();
  }

  /// Número del pedido para mostrar (el backend solo manda su id); si no
  /// está entre los pedidos cargados, el id.
  String numeroDePedido(String id) {
    for (final p in _pedidos) {
      if (p.id == id) return p.numero;
    }
    return id;
  }

  /// Deja el formulario como nuevo (al abrir la hoja).
  void nuevaQueja() {
    _tipo = TipoQueja.queja;
    _categoria = CategoriaQueja.producto;
    _pedidoId = null;
    notifyListeners();
  }

  void seleccionarTipo(TipoQueja tipo) {
    _tipo = tipo;
    notifyListeners();
  }

  void seleccionarCategoria(CategoriaQueja categoria) {
    _categoria = categoria;
    notifyListeners();
  }

  void seleccionarPedido(String? pedidoId) {
    _pedidoId = pedidoId;
    notifyListeners();
  }

  /// Envía el formulario. Si se creó, recarga la lista sin hacer esperar la
  /// confirmación.
  Future<EnvioQueja> enviar({
    required String asunto,
    required String descripcion,
  }) async {
    final a = asunto.trim();
    final d = descripcion.trim();
    if (a.isEmpty || d.isEmpty) {
      return (ticket: null, error: 'Completa todos los campos obligatorios');
    }
    if (_enviando) return (ticket: null, error: null);

    _enviando = true;
    notifyListeners();
    EnvioQueja resultado;
    try {
      final ticket = await _quejasRepo.crearQueja(
        tipo: _tipo,
        categoria: _categoria,
        asunto: a,
        descripcion: d,
        pedidoId: _pedidoId,
      );
      PierLog.info('✅ Queja enviada — ticket: $ticket');
      resultado = (ticket: ticket, error: null);
    } on ApiException catch (e) {
      PierLog.error('Error al enviar queja: ${e.message}');
      resultado = (ticket: null, error: e.message);
    }
    if (_cerrado) return resultado;

    _enviando = false;
    notifyListeners();
    if (resultado.error == null) unawaited(_recargarQuejas());
    return resultado;
  }

  Future<void> _recargarQuejas() async {
    await _cargarQuejas();
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
