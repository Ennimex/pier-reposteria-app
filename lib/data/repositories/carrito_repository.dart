// lib/data/repositories/carrito_repository.dart
//
// Única puerta a los datos de el carrito del cliente (el backend es la fuente de verdad). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es CarritoRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class CarritoRepository {
  /// GET /carrito
  Future<Map<String, dynamic>> obtener();

  /// POST /carrito. El backend separa líneas por tamaño y recalcula el
  /// precio unitario; productoId puede ir como int o String.
  Future<Map<String, dynamic>> agregar({
    required dynamic productoId,
    required int cantidad,
    required String tamano,
  });

  /// PUT /carrito/:itemId
  Future<Map<String, dynamic>> actualizarCantidad(String itemId, int cantidad);

  /// DELETE /carrito/:itemId
  Future<Map<String, dynamic>> eliminarItem(String itemId);

  /// DELETE /carrito (vaciar)
  Future<Map<String, dynamic>> vaciar();
}
