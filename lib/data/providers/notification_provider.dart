// lib/data/providers/notification_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _notificaciones = [];
  int _noLeidas = 0;
  Timer? _pollingTimer;
  bool _isAuthenticated = false;

  // ── Getters ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get notificaciones => _notificaciones;
  int get noLeidas => _noLeidas;

  // ── Iniciar polling cuando el usuario está autenticado ───────────────
  void startPolling() {
    if (_isAuthenticated) return; // ya está activo
    _isAuthenticated = true;
    _fetchNotificaciones(); // carga inmediata
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _fetchNotificaciones();
    });
  }

  // ── Detener polling cuando el usuario cierra sesión ──────────────────
  void stopPolling() {
    _isAuthenticated = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _notificaciones = [];
    _noLeidas = 0;
    notifyListeners();
  }

  // ── Carga de notificaciones ───────────────────────────────────────────
  Future<void> _fetchNotificaciones() async {
    final result = await _api.getAuth(ApiConstants.notificaciones);
    if (result['success'] == true) {
      final lista = List<Map<String, dynamic>>.from(
          result['notificaciones'] ?? []);
      final noLeidas =
          int.tryParse(result['no_leidas']?.toString() ?? '0') ?? 0;

      // Solo notifica si hubo cambio real
      if (noLeidas != _noLeidas || lista.length != _notificaciones.length) {
        _notificaciones = lista;
        _noLeidas = noLeidas;
        notifyListeners();
      }
    }
  }

  // ── Refresh manual (pull-to-refresh) ─────────────────────────────────
  Future<void> refresh() async {
    await _fetchNotificaciones();
  }

  // ── Marcar una como leída (optimistic update) ─────────────────────────
  Future<void> marcarLeida(String id) async {
    final idx = _notificaciones.indexWhere((n) => n['id'].toString() == id);
    if (idx == -1 || _notificaciones[idx]['leida'] == true) return;

    _notificaciones[idx]['leida'] = true;
    if (_noLeidas > 0) _noLeidas--;
    notifyListeners();

    await _api.putAuth(ApiConstants.marcarNotificacionLeida(id), {});
  }

  // ── Marcar todas como leídas ──────────────────────────────────────────
  Future<void> marcarTodasLeidas() async {
    for (final n in _notificaciones) {
      n['leida'] = true;
    }
    _noLeidas = 0;
    notifyListeners();
    await _api.putAuth('/notificaciones/leer-todas', {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
