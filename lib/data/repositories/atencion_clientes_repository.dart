// lib/data/repositories/atencion_clientes_repository.dart
//
// Única puerta a «Atención a clientes» del personal (#138): las quejas, las
// solicitudes de reembolso y las reseñas de los clientes, y lo que el
// personal hace con ellas (responder quejas, dar cada paso de un reembolso,
// moderar y responder reseñas). Devuelve modelos y lanza ApiException con el
// mensaje del backend. La implementación HTTP es
// AtencionClientesRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';

abstract class AtencionClientesRepository {
  /// GET /quejas: de la más reciente a la más antigua.
  Future<List<QuejaPersonal>> quejas();

  /// PUT /quejas/:id con {estado, respuesta?}. El backend guarda la
  /// respuesta que llegue: sin ella, borra la que había. Devuelve el
  /// mensaje para el personal.
  Future<String> atenderQueja(
    String id, {
    required String estado,
    String? respuesta,
  });

  /// GET /reembolsos: de la más reciente a la más antigua.
  Future<List<ReembolsoPersonal>> reembolsos();

  /// PUT /reembolsos/:id con {estado, respuesta_admin?,
  /// justificacion_rechazo?}. El backend valida el paso y el rol (403/409
  /// con su mensaje) y no mueve dinero: la devolución se hace en Stripe.
  Future<String> resolverReembolso(
    String id, {
    required String estado,
    String? respuestaAdmin,
    String? justificacionRechazo,
  });

  /// GET /resenas: todas, de la más reciente a la más antigua.
  Future<List<ResenaPersonal>> resenas();

  /// PUT /resenas/:id/estado. Sin [estado] solo publica [respuestaNegocio];
  /// con él (aprobada o rechazada) modera, y lo que no llegue queda vacío.
  Future<String> moderarResena(
    String id, {
    String? estado,
    String? motivoRechazo,
    String? respuestaNegocio,
  });
}
