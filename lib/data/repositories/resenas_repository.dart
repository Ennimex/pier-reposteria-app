// lib/data/repositories/resenas_repository.dart
//
// Única puerta a los datos de reseñas. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es ResenasRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos tipados (crearResena, listarMisResenas, editarResena,
// listarDeProducto, alternarUtil) lanzan ApiException si el backend falla.
import 'package:pier_pasteleria/domain/models/mi_resena.dart';
import 'package:pier_pasteleria/domain/models/resena_producto.dart';

abstract class ResenasRepository {
  /// GET /resenas/mis-resenas
  Future<Map<String, dynamic>> misResenas();

  /// GET /resenas/destacadas (público, home)
  Future<Map<String, dynamic>> destacadas();

  /// GET /resenas/producto/:id (público, solo aprobadas)
  Future<Map<String, dynamic>> porProducto(String productoId);

  /// GET /resenas/producto/:id tipado, en el orden del backend (verificadas,
  /// más útiles, recientes); ignora elementos que no sean objetos.
  /// porProducto() crudo se queda para el detalle de producto.
  Future<List<ResenaProducto>> listarDeProducto(String productoId);

  /// POST /resenas: {producto_id, rating, titulo, comentario}. Devuelve
  /// true si quedó publicada de inmediato (auto_aprobada) y false si quedó en
  /// revisión. Lanza ApiException con el mensaje del backend (p. ej. «Ya
  /// dejaste una reseña para este producto»).
  Future<bool> crearResena({
    required String productoId,
    required int rating,
    required String titulo,
    required String comentario,
  });

  /// GET /resenas/mis-resenas tipado; ignora elementos que no sean objetos.
  /// misResenas() crudo se queda para el contador de «Más».
  Future<List<MiResena>> listarMisResenas();

  /// PUT /resenas/:id (solo la propia). Devuelve el mensaje del backend para
  /// mostrarlo; lanza ApiException si no se guardó.
  Future<String> editarResena({
    required String id,
    required int rating,
    required String titulo,
    required String comentario,
  });

  /// POST /resenas/:id/like ("útil")
  Future<Map<String, dynamic>> like(String id);

  /// POST /resenas/:id/like tipado. El backend alterna (si ya era «útil»
  /// lo quita); devuelve cómo quedó: true = marcada. Lanza ApiException.
  Future<bool> alternarUtil(String id);
}
