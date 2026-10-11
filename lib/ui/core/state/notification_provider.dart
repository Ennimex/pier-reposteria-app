// lib/ui/core/state/notification_provider.dart
//
// Notificaciones compartidas de la app: la campana de inicio muestra cuántas
// faltan por leer y «Notificaciones» las lista. Con sesión se consultan cada
// 2 minutos (startPolling); al cerrar sesión se deja de consultar y se
// vacían la lista y el badge (stopPolling). Marcar como leída se ve al
// instante y se confirma con el backend vía NotificacionesRepository; si lo
// rechaza se revierte y la acción devuelve el motivo para que la vista lo
// muestre (null si salió bien).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository.dart';
import 'package:pier_pasteleria/domain/models/notificacion.dart';
import 'package:pier_pasteleria/utils/logger.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required NotificacionesRepository repo}) : _repo = repo;

  /// Cada cuánto se consultan mientras hay sesión.
  static const Duration intervalo = Duration(minutes: 2);

  final NotificacionesRepository _repo;
  List<Notificacion> _notificaciones = const [];
  Timer? _pollingTimer;
  bool _isAuthenticated = false;
  bool _cerrado = false;

  /// Cambia al cerrar sesión: una respuesta que llegue después ya no es del
  /// usuario actual y se descarta.
  int _sesion = 0;

  /// La más nueva primero.
  List<Notificacion> get notificaciones => _notificaciones;
  int get noLeidas => _notificaciones.where((n) => !n.leida).length;

  // ── Iniciar polling cuando el usuario está autenticado ───────────
  /// Consulta ya y luego cada [intervalo]; si ya estaba consultando no hace
  /// nada.
  void startPolling() {
    if (_isAuthenticated) return;
    _isAuthenticated = true;
    PierLog.info('🔔 Polling de notificaciones iniciado');
    unawaited(_sondear());
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(intervalo, (_) {
      PierLog.debug('🔔 Polling tick — verificando notificaciones');
      unawaited(_sondear());
    });
  }

  // ── Detener polling al cerrar sesión ─────────────────────────────
  /// Deja de consultar y vacía la lista (y con ella el badge).
  void stopPolling() {
    PierLog.info('🔔 Polling de notificaciones detenido');
    _isAuthenticated = false;
    _sesion++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _notificaciones = const [];
    _avisar();
  }

  // ── Carga de notificaciones ───────────────────────────────────────
  /// Trae las notificaciones del backend. Si falla lanza ApiException y
  /// conserva las que ya tenía.
  Future<void> cargar() async {
    final sesion = _sesion;
    final nuevas = await _repo.listar();
    if (_cerrado || sesion != _sesion) return;
    if (_iguales(nuevas)) {
      PierLog.debug('🔔 Sin cambios en notificaciones');
      return;
    }
    _notificaciones = List.unmodifiable(nuevas);
    PierLog.info('🔔 Notificaciones actualizadas: ${nuevas.length} total, '
        '$noLeidas no leídas');
    _avisar();
  }

  // ── Marcar como leídas (optimistic update) ────────────────────────
  Future<String?> marcarLeida(String id) => _marcar(
        _notificaciones.where((n) => n.id == id),
        () => _repo.marcarLeida(id),
      );

  Future<String?> marcarTodasLeidas() =>
      _marcar(_notificaciones, _repo.marcarTodasLeidas);

  /// Marca [cuales] como leídas al instante y lo confirma con [llamada]; si
  /// el backend lo rechaza vuelven a quedar sin leer.
  Future<String?> _marcar(
    Iterable<Notificacion> cuales,
    Future<void> Function() llamada,
  ) async {
    final originales = {
      for (final n in cuales)
        if (!n.leida) n.id: n,
    };
    if (originales.isEmpty) return null;
    _reemplazar((n) => originales.containsKey(n.id) ? n.marcadaLeida() : n);
    try {
      await llamada();
      PierLog.info('🔔 ${originales.length} notificación(es) leída(s)');
      return null;
    } on ApiException catch (e) {
      PierLog.error('No se pudo marcar como leída: ${e.message}');
      _reemplazar((n) => originales[n.id] ?? n);
      return e.message;
    }
  }

  /// Consulta del sondeo: si falla se queda lo que hay.
  Future<void> _sondear() async {
    try {
      await cargar();
    } on ApiException catch (e) {
      PierLog.error('Error al obtener notificaciones: ${e.message}');
    }
  }

  /// Mismas notificaciones y en el mismo estado de lectura.
  bool _iguales(List<Notificacion> nuevas) =>
      nuevas.length == _notificaciones.length &&
      Iterable<int>.generate(nuevas.length).every((i) =>
          nuevas[i].id == _notificaciones[i].id &&
          nuevas[i].leida == _notificaciones[i].leida);

  void _reemplazar(Notificacion Function(Notificacion) cambio) {
    _notificaciones = List.unmodifiable(_notificaciones.map(cambio));
    _avisar();
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    PierLog.debug('NotificationProvider disposed');
    _cerrado = true;
    _pollingTimer?.cancel();
    super.dispose();
  }
}
