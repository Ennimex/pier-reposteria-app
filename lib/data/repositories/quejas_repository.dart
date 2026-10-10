// lib/data/repositories/quejas_repository.dart
//
// Única puerta a los datos de quejas y sugerencias. En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Contrato (Fase 3.5): vistas, ViewModels y providers dependen de esta
// clase abstracta; la implementación HTTP es QuejasRepositoryRemote, registrada
// una sola vez en lib/config/dependencies.dart.
//
// Fase 3: los métodos tipados (listarMisQuejas, crearQueja) lanzan
// ApiException si el backend falla.
import 'package:pier_pasteleria/domain/models/queja.dart';

abstract class QuejasRepository {
  /// GET /quejas/mis-quejas
  Future<Map<String, dynamic>> misQuejas();

  /// GET /quejas/mis-quejas tipado; ignora elementos que no sean objetos.
  Future<List<Queja>> listarMisQuejas();

  /// POST /quejas: {tipo, categoria, asunto, descripcion, pedido_id?}
  Future<Map<String, dynamic>> crear(Map<String, dynamic> body);

  /// POST /quejas tipado. Devuelve el ticket generado (vacío si no viene);
  /// lanza ApiException con el mensaje del backend si no se creó.
  Future<String> crearQueja({
    required TipoQueja tipo,
    required CategoriaQueja categoria,
    required String asunto,
    required String descripcion,
    String? pedidoId,
  });
}
