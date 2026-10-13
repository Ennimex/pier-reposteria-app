// lib/data/repositories/comandas_repository.dart
//
// Única puerta a las comandas de pedidos personalizados (#127). Devuelve
// modelos y lanza ApiException con el mensaje del backend, o
// SesionInvalidaException si la cuenta ya no está vigente.
// Vistas y ViewModels dependen de esta clase abstracta; la implementación
// HTTP es ComandasRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_pasteleria/domain/models/comanda.dart';

abstract class ComandasRepository {
  /// GET /comandas: la agenda de [vista], filtrada por folio exacto o parte
  /// del nombre del cliente si hay [busqueda]. Hornos y decoración la reciben
  /// sin montos.
  Future<AgendaComandas> agenda({
    VistaAgenda vista = VistaAgenda.proximas,
    String busqueda = '',
  });

  /// GET /comandas/:id: la comanda completa con sus firmas, historial y qué
  /// cambió desde la última confirmación de mi área.
  Future<DetalleComanda> detalle(int id);

  /// POST /comandas/:id/confirmar: «Enterado» de mi área sobre la [version]
  /// que leí (el área la decide el backend con el rol). Devuelve el mensaje
  /// del backend; ConflictoComandaException si la comanda cambió o si otra
  /// persona del área ya la confirmó.
  Future<String> confirmar(int id, {required int version});
}
