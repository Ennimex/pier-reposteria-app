// lib/data/repositories/comandas_repository.dart
//
// Única puerta a las comandas de pedidos personalizados (#127). Devuelve
// modelos y lanza ApiException con el mensaje del backend, o
// SesionInvalidaException si la cuenta ya no está vigente.
// Vistas y ViewModels dependen de esta clase abstracta; la implementación
// HTTP es ComandasRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/comanda.dart';

// Crece con el detalle y el «Enterado» (#128).
// ignore: one_member_abstracts
abstract class ComandasRepository {
  /// GET /comandas: la agenda de [vista], filtrada por folio exacto o parte
  /// del nombre del cliente si hay [busqueda]. Hornos y decoración la reciben
  /// sin montos.
  Future<AgendaComandas> agenda({
    VistaAgenda vista = VistaAgenda.proximas,
    String busqueda = '',
  });
}
