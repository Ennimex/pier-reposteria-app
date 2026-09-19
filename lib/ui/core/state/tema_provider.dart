// lib/ui/core/state/tema_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/ui/core/themes/tema_catalogo.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Espejo del TemaProvider de la web (src/temas/TemaProvider.tsx): lee la
/// sección pública 'personalizacion' — modo_auto=true resuelve el tema por
/// calendario (temaPorFecha); si no, usa el tema_activo elegido por Dirección
/// en el panel — y aplica la paleta a AppColors. Refresca cada 60s, así el
/// tema de temporada cambia sin lanzar updates de la app.
class TemaProvider extends ChangeNotifier {
  final ConfiguracionRepository _repo;
  Timer? _timer;
  TemaPier _tema = temaNormal;
  bool _modoAuto = false;

  TemaPier get tema => _tema;
  bool get modoAuto => _modoAuto;

  TemaProvider({ConfiguracionRepository? repo})
      : _repo = repo ?? ConfiguracionRepository() {
    resolverTema();
    _timer =
        Timer.periodic(const Duration(seconds: 60), (_) => resolverTema());
  }

  Future<void> resolverTema() async {
    var nuevo = temaNormal;
    var auto = false;
    try {
      final res = await _repo.seccion('personalizacion');
      if (res['success'] == true && res['config'] is Map) {
        final config = res['config'] as Map;
        auto = config['modo_auto'] == true || config['modo_auto'] == 'true';
        if (auto) {
          nuevo = temaPorFecha();
        } else if (config['tema_activo'] is String) {
          nuevo = temaPorId(
                  (config['tema_activo'] as String).replaceAll('"', '')) ??
              temaNormal;
        }
      }
    } catch (_) {
      // Sin conexión: se conserva el último tema aplicado (igual que la web)
      return;
    }
    _modoAuto = auto;
    if (nuevo.id != _tema.id) {
      _tema = nuevo;
      AppColors.aplicarPaleta(nuevo.colores);
      PierLog.info('🎨 Tema aplicado: ${nuevo.nombre} (auto: $auto)');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
