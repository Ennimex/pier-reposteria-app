// lib/ui/reviews/view_model/product_reviews_view_model.dart
//
// Estado de «Opiniones» de un producto (MVVM, Fase 3): las reseñas, el
// resumen (promedio y distribución), el filtro por estrellas, el orden y
// «útil». Si la carga falla la lista se queda como estaba (la pantalla no
// muestra error, como antes). La sesión la revisa la vista.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/resena_producto.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Orden de la lista; «recientes» respeta el del backend.
enum OrdenResenas { recientes, mejor, peor }

class ProductReviewsViewModel extends ChangeNotifier {
  ProductReviewsViewModel({
    required ResenasRepository repo,
    required String productoId,
  })  : _repo = repo,
        _productoId = productoId;

  final ResenasRepository _repo;
  final String _productoId;
  bool _cerrado = false;

  List<ResenaProducto> _resenas = const [];
  bool _cargando = true;
  int _filtroEstrellas = 0;
  OrdenResenas _orden = OrdenResenas.recientes;
  final Set<String> _utiles = {};

  List<ResenaProducto> get resenas => _resenas;
  bool get cargando => _cargando;

  /// 0 = todas.
  int get filtroEstrellas => _filtroEstrellas;
  OrdenResenas get orden => _orden;

  /// ¿El cliente la marcó «útil» en esta visita?
  bool esUtil(String id) => _utiles.contains(id);

  double get promedio => _resenas.isEmpty
      ? 0
      : _resenas.fold<double>(0, (s, r) => s + r.rating) / _resenas.length;

  /// Cuántas reseñas hay de 5, 4, 3, 2 y 1 estrellas.
  Map<int, int> get distribucion {
    final dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _resenas) {
      final e = r.estrellas;
      if (dist.containsKey(e)) dist[e] = dist[e]! + 1;
    }
    return dist;
  }

  /// Las del filtro, en el orden elegido.
  List<ResenaProducto> get filtradas {
    final lista = _filtroEstrellas == 0
        ? [..._resenas]
        : _resenas.where((r) => r.estrellas == _filtroEstrellas).toList();
    switch (_orden) {
      case OrdenResenas.mejor:
        lista.sort((a, b) => b.rating.compareTo(a.rating));
      case OrdenResenas.peor:
        lista.sort((a, b) => a.rating.compareTo(b.rating));
      case OrdenResenas.recientes:
        break;
    }
    return lista;
  }

  Future<void> cargar() async {
    _cargando = true;
    notifyListeners();
    try {
      _resenas = await _repo.listarDeProducto(_productoId);
      PierLog.info('✅ Reseñas cargadas: ${_resenas.length}');
    } on ApiException catch (e) {
      PierLog.error('Error al cargar reseñas: ${e.message}');
    }
    if (_cerrado) return;
    _cargando = false;
    notifyListeners();
  }

  void filtrar(int estrellas) {
    _filtroEstrellas = estrellas;
    notifyListeners();
  }

  void ordenar(OrdenResenas orden) {
    _orden = orden;
    notifyListeners();
  }

  /// Marca o desmarca «útil» al instante y lo confirma con el backend. El
  /// backend alterna por su cuenta: si ya estaba marcada de otra visita, la
  /// quita, y aquí se ajusta a lo que responda. Si falla, se revierte.
  Future<void> alternarUtil(String id) async {
    final i = _resenas.indexWhere((r) => r.id == id);
    if (i == -1) return;
    final base = _resenas[i].utilCount;
    final marcada = _utiles.contains(id);
    _aplicar(id, marcada: !marcada, conteo: base + (marcada ? -1 : 1));

    try {
      final quedo = await _repo.alternarUtil(id);
      if (_cerrado) return;
      if (quedo == marcada) {
        // El backend sabía algo que la app no (p. ej. ya la había marcado
        // en otra visita): el conteo real es el de antes ± 1.
        _aplicar(id, marcada: quedo, conteo: base + (quedo ? 1 : -1));
      }
      PierLog.info('Like ${quedo ? 'agregado' : 'removido'} en reseña $id');
    } on ApiException {
      PierLog.error('Error al dar like a reseña $id');
      if (_cerrado) return;
      _aplicar(id, marcada: marcada, conteo: base);
    }
  }

  void _aplicar(String id, {required bool marcada, required int conteo}) {
    if (marcada) {
      _utiles.add(id);
    } else {
      _utiles.remove(id);
    }
    _resenas = _resenas
        .map((r) =>
            r.id == id ? r.copyWith(utilCount: conteo < 0 ? 0 : conteo) : r)
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
