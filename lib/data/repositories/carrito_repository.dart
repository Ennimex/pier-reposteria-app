// lib/data/repositories/carrito_repository.dart
//
// Única puerta a los datos del carrito del cliente (el backend es la fuente
// de verdad). Tipado en la Fase 5 de MVVM: devuelve modelos y lanza
// ApiException con el mensaje del backend (p. ej. «Solo quedan 2 unidades»).
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es CarritoRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/cart_item_model.dart';

abstract class CarritoRepository {
  /// GET /carrito: las líneas del carrito.
  Future<List<CartItem>> obtener();

  /// POST /carrito. El backend separa líneas por tamaño, suma si la línea ya
  /// existe y valida el stock; productoId puede ir como int o String.
  Future<void> agregar({
    required dynamic productoId,
    required int cantidad,
    required String tamano,
  });

  /// PUT /carrito/:itemId (valida el stock).
  Future<void> actualizarCantidad(String itemId, int cantidad);

  /// DELETE /carrito/:itemId
  Future<void> eliminarItem(String itemId);

  /// DELETE /carrito (vaciar)
  Future<void> vaciar();
}
