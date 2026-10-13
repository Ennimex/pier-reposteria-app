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
}
