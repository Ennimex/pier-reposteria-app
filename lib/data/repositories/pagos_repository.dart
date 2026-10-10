// lib/data/repositories/pagos_repository.dart
//
// Única puerta a los datos de pagos con Stripe. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es PagosRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.

abstract class PagosRepository {
  /// GET /pagos/config: publishable key (público).
  Future<Map<String, dynamic>> config();

  /// POST /pagos/crear-intent: {tipo_entrega?, direccion_id?, horario_recogida?}
  /// -> {clientSecret, publishableKey, total, por_confirmar, ...}
  Future<Map<String, dynamic>> crearIntent(Map<String, dynamic> body);

  /// POST /pagos/confirmar: crea el pedido y vacía el carrito en la misma
  /// transacción (reintentar es seguro).
  Future<Map<String, dynamic>> confirmar(Map<String, dynamic> body);
}
