// lib/data/repositories/publicaciones_repository.dart
//
// Única puerta a las publicaciones del inicio del cliente (#132). Exige
// sesión de cliente (o del personal); repartidor, hornos y decoración reciben
// 403. Devuelve modelos y lanza ApiException con el mensaje del backend, o
// SesionInvalidaException si la cuenta ya no está vigente. La implementación
// HTTP es PublicacionesRepositoryRemote, registrada en
// lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/publicacion.dart';

abstract class PublicacionesRepository {
  /// GET /publicaciones/feed: de la más nueva a la más vieja; con [despues]
  /// sigue desde la última publicación vista.
  Future<PaginaFeed> feed({CursorFeed? despues});

  /// GET /publicaciones/promociones: vigentes, una por producto y con el
  /// precio que se cobra.
  Future<List<PromocionFeed>> promociones();

  /// GET /publicaciones/sugerencias: 6 por página, primero lo afín a lo que
  /// compró el cliente y luego lo más pedido.
  Future<PaginaSugerencias> sugerencias({required int pagina});

  /// PUT o DELETE /publicaciones/:id/corazon: pone o quita «Me encanta» y
  /// devuelve cómo quedó. PublicacionNoDisponibleException si ya no está.
  Future<ReaccionPublicacion> meEncanta(int id, {required bool poner});

  /// GET /publicaciones/:id/comentarios: visibles, del más viejo al más
  /// nuevo, de 20 en 20 después de [despuesId].
  Future<PaginaComentarios> comentarios(int id, {int? despuesId});

  /// POST /publicaciones/:id/comentarios: 1 a 1000 caracteres; el backend
  /// permite 5 por minuto (si no, ApiException con su aviso).
  Future<ComentarioPublicacion> comentar(int id, String texto);

  /// DELETE /publicaciones/comentarios/:id: el cliente oculta los suyos.
  Future<void> borrarComentario(int comentarioId);
}
