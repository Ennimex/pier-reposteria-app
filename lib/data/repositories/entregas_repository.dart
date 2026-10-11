// lib/data/repositories/entregas_repository.dart
//
// Única puerta a los datos de entregas del repartidor. Tipado en la Fase 5 de
// MVVM: devuelve modelos y lanza ApiException con el mensaje del backend
// (p. ej. «Otro repartidor ya tomó este pedido»).
// Contrato (Fase 3.5): vistas y ViewModels dependen de esta clase abstracta;
// la implementación HTTP es EntregasRepositoryRemote, registrada una sola vez
// en lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

abstract class EntregasRepository {
  /// GET /entregas/mis-entregas: las entregas del repartidor (en curso y las
  /// finalizadas hoy).
  Future<List<EntregaRepartidor>> misEntregas();

  /// GET /entregas/disponibilidad: si el repartidor recibe entregas.
  Future<bool> disponibilidad();

  /// PUT /entregas/disponibilidad. Devuelve el valor que quedó guardado.
  Future<bool> cambiarDisponibilidad({required bool disponible});

  /// GET /entregas/disponibles: pool de pedidos 'listo' a domicilio.
  Future<List<PedidoDisponible>> disponibles();

  /// POST /entregas/aceptar: el primero que acepta gana (409 si ya se tomó).
  /// Devuelve el mensaje del backend («Tomaste el pedido #…»).
  Future<String> aceptar(String pedidoId);

  /// PUT /entregas/:id/estado. El backend exige [recibioNombre] al entregar
  /// y [motivoFallo] al reportar un fallo.
  Future<void> cambiarEstado(
    String entregaId,
    EstadoEntrega nuevo, {
    String? evidenciaUrl,
    String? recibioNombre,
    String? motivoFallo,
  });

  /// POST /entregas/:id/llegue: avisa al cliente sin cambiar estado.
  /// Devuelve el mensaje del backend.
  Future<String> avisarLlegada(String entregaId);

  /// POST /upload/imagen (tipo entrega): sube la evidencia y devuelve su URL.
  Future<String> subirEvidencia(String filePath);
}
