// lib/data/repositories/comandas_repository.dart
//
// Única puerta a las comandas de pedidos personalizados (#127). Devuelve
// modelos y lanza ApiException con el mensaje del backend, o
// SesionInvalidaException si la cuenta ya no está vigente.
// Vistas y ViewModels dependen de esta clase abstracta; la implementación
// HTTP es ComandasRepositoryRemote, registrada en lib/config/dependencies.dart.
import 'package:pier_reposteria/domain/models/comanda.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';

/// Resultado de entregar: el mensaje del backend y las áreas que no habían
/// confirmado (entregar no exige firmas, pero queda dicho).
typedef EntregaComanda = ({String mensaje, List<String> advertencias});

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

  /// PUT /comandas/:id/entregar: la marca entregada con lo que se cobró.
  Future<EntregaComanda> entregar(int id, {required double saldoCobrado});

  /// PUT /comandas/:id/cancelar: la cancela con [motivo] (5 a 300
  /// caracteres). Solo quien la tomó, gerencia o dirección.
  Future<String> cancelar(int id, {required String motivo});

  /// GET /comandas/catalogo: opciones del pastel, reglas de cobro y
  /// productos del catálogo (vacío para producción).
  Future<CatalogoComanda> catalogo();

  /// POST /comandas/imagenes: sube la foto de [ruta] y devuelve lo que se
  /// manda con la comanda (url y public_id).
  Future<FotoComanda> subirFoto(String ruta);

  /// POST /comandas con [datos] (el mismo cuerpo que manda la web). Si el
  /// backend la rechaza, ApiException con todos sus motivos, uno por
  /// renglón.
  Future<ComandaCreada> crear(Map<String, dynamic> datos);

  /// GET /comandas/:id: lo capturado para editarlo, con su versión
  /// (`actualizada_en`).
  Future<ComandaParaEditar> paraEditar(int id);

  /// PUT /comandas/:id con [datos] y la versión que se editó
  /// ([actualizadaEn]). ConflictoComandaException si otra persona la
  /// guardó antes (409 COMANDA_DESACTUALIZADA); ApiException con todos los
  /// motivos si el backend la rechaza. Devuelve el mensaje y las
  /// advertencias.
  Future<({String mensaje, List<String> advertencias})> guardarCambios(
    int id,
    Map<String, dynamic> datos, {
    required String actualizadaEn,
  });
}
