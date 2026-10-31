// lib/data/services/catalogo_guardado_service.dart
//
// La primera página del catálogo sin búsqueda, filtros ni orden, guardada en
// el teléfono (#265, SharedPreferences, no secreta). El servidor gratuito se
// duerme y su primera respuesta puede tardar unos 20 s: con esta copia el
// catálogo se ve al instante mientras llega la nueva, y sin internet se queda
// lo último que se vio. Es solo para mostrar: el carrito y el pago validan
// precio y existencia con el servidor, así que un dato viejo de la copia nunca
// se cobra.
import 'dart:convert';

import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CatalogoGuardadoService {
  /// [ahora] da la fecha que se guarda junto con la copia (en pruebas, una
  /// fija).
  CatalogoGuardadoService({DateTime Function() ahora = DateTime.now})
      : _ahora = ahora;

  /// La versión va en la llave: si cambia el formato, la copia vieja se deja
  /// de leer sin romper nada.
  static const _llave = 'pierreposteria_catalogo_v1';

  final DateTime Function() _ahora;

  /// La copia guardada, o null si no hay, no se puede leer o no trae
  /// productos.
  Future<List<Product>?> leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_llave);
      if (guardado == null) return null;
      final datos = jsonDecode(guardado) as Map<String, dynamic>;
      final productos = [
        for (final p in datos['productos'] as List<dynamic>)
          Product.fromJson(p as Map<String, dynamic>),
      ];
      return productos.isEmpty ? null : productos;
    } on Object catch (e) {
      PierLog.error('No se pudo leer el catálogo guardado: $e');
      return null;
    }
  }

  /// Guarda [productos] (la página 1 tal como llegó del servidor) con la
  /// fecha de ahora en UTC. Reemplaza la copia anterior. Una página vacía no
  /// es una copia: se queda la anterior. Nunca lanza: sin copia el catálogo
  /// funciona igual.
  Future<void> guardar(List<Product> productos) async {
    if (productos.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _llave,
        jsonEncode({
          'guardado': _ahora().toUtc().toIso8601String(),
          'productos': [for (final p in productos) p.toJson()],
        }),
      );
    } on Object catch (e) {
      PierLog.error('No se pudo guardar el catálogo: $e');
    }
  }
}
