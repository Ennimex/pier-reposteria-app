// lib/data/providers/notification_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/utils/logger.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _notificaciones = [];
  int _noLeidas = 0;
  Timer? _pollingTimer;
  bool _isAuthenticated = false;

  List<Map<String, dynamic>> get notificaciones => _notificaciones;
  int get noLeidas => _noLeidas;

  // ── Iniciar polling cuando el usuario está autenticado ───────────
  void startPolling() {
    if (_isAuthenticated) return;
    _isAuthenticated = true;
    PierLog.info('🔔 Polling de notificaciones iniciado');
    _fetchNotificaciones();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      PierLog.debug('🔔 Polling tick — verificando notificaciones');
      _fetchNotificaciones();
    });
  }

  // ── Detener polling al cerrar sesión ─────────────────────────────
  void stopPolling() {
    PierLog.info('🔔 Polling de notificaciones detenido');
    _isAuthenticated = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _notificaciones = [];
    _noLeidas = 0;
    notifyListeners();
  }

  // ── Carga de notificaciones ───────────────────────────────────────
  Future<void> _fetchNotificaciones() async {
    PierLog.api('GET ${ApiConstants.notificaciones}');
    final result = await _api.getAuth(ApiConstants.notificaciones);

    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['notificaciones'] ?? []);
      final noLeidas =
          int.tryParse(result['no_leidas']?.toString() ?? '0') ?? 0;

      if (noLeidas != _noLeidas ||
          lista.length != _notificaciones.length) {
        PierLog.info(
            '🔔 Notificaciones actualizadas: ${lista.length} total, $noLeidas no leídas');
        _notificaciones = lista;
        _noLeidas = noLeidas;
        notifyListeners();
      } else {
        PierLog.debug('🔔 Sin cambios en notificaciones');
      }
    } else {
      PierLog.error(
          'Error al obtener notificaciones: ${result['message']}');
    }
  }

  // ── Refresh manual (pull-to-refresh) ─────────────────────────────
  Future<void> refresh() async {
    PierLog.info('🔔 Refresh manual de notificaciones');
    await _fetchNotificaciones();
  }

  // ── Marcar una como leída (optimistic update) ─────────────────────
  Future<void> marcarLeida(String id) async {
    final idx =
        _notificaciones.indexWhere((n) => n['id'].toString() == id);
    if (idx == -1 || _notificaciones[idx]['leida'] == true) return;

    PierLog.api('PUT ${ApiConstants.marcarNotificacionLeida(id)}');

    // Optimistic update
    _notificaciones[idx]['leida'] = true;
    if (_noLeidas > 0) _noLeidas--;
    notifyListeners();

    final result =
        await _api.putAuth(ApiConstants.marcarNotificacionLeida(id), {});

    if (result['success'] != true) {
      PierLog.error('Error al marcar notificación $id como leída');
      // Revertir
      _notificaciones[idx]['leida'] = false;
      _noLeidas++;
      notifyListeners();
    } else {
      PierLog.info('🔔 Notificación $id marcada como leída');
    }
  }

  // ── Marcar todas como leídas ──────────────────────────────────────
  Future<void> marcarTodasLeidas() async {
    PierLog.api('PUT ${ApiConstants.notificacionesLeerTodas}');

    for (final n in _notificaciones) {
      n['leida'] = true;
    }
    _noLeidas = 0;
    notifyListeners();

    final result =
        await _api.putAuth(ApiConstants.notificacionesLeerTodas, {});

    if (result['success'] != true) {
      PierLog.error(
          'Error al marcar todas las notificaciones como leídas');
    } else {
      PierLog.info('🔔 Todas las notificaciones marcadas como leídas');
    }
  }

  @override
  void dispose() {
    PierLog.debug('NotificationProvider disposed');
    _pollingTimer?.cancel();
    super.dispose();
  }
}