// lib/ui/atencion/view_model/resenas_personal_view_model.dart
//
// Estado de la pestaña «Reseñas» de Atención a clientes (#138): las reseñas
// de los productos, las que esperan revisión primero, y lo que el personal
// hace con ellas, como GestionResenas.tsx de la web: aprobar o rechazar
// (con motivo) las que no se publicaron solas y responder como Pier
// Repostería las aprobadas que no tienen respuesta. Lo crea
// ResenasPersonalTab.
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/mi_resena.dart';
import 'package:pier_reposteria/ui/atencion/view_model/lista_atencion_view_model.dart';

class ResenasPersonalViewModel extends ListaAtencionViewModel<ResenaPersonal> {
  ResenasPersonalViewModel({required AtencionClientesRepository repo})
      : _repo = repo;

  final AtencionClientesRepository _repo;

  /// Caracteres mínimos del motivo de un rechazo y de una respuesta (como
  /// la web).
  static const minimoMotivo = 10;
  static const minimoRespuesta = 5;

  @override
  Future<List<ResenaPersonal>> pedirLista() => _repo.resenas();

  @override
  String idDe(ResenaPersonal elemento) => elemento.id;

  /// Las que esperan revisión primero; luego las demás, de la más reciente
  /// a la más antigua (como las manda el backend).
  List<ResenaPersonal> get resenas => [
        ...elementos.where(puedeModerar),
        ...elementos.where((r) => !puedeModerar(r)),
      ];

  /// Aprobar o rechazar: solo las que esperan revisión.
  bool puedeModerar(ResenaPersonal r) => r.estado == EstadoResena.enRevision;

  /// Responder como Pier Repostería: las aprobadas sin respuesta.
  bool puedeResponder(ResenaPersonal r) =>
      r.estado == EstadoResena.aprobada && r.respuestaNegocio == null;

  /// El motivo de un rechazo; null si está bien.
  static String? validarMotivo(String motivo) =>
      motivo.trim().length < minimoMotivo
          ? 'El motivo debe tener al menos $minimoMotivo caracteres.'
          : null;

  /// La respuesta pública; null si está bien.
  static String? validarRespuesta(String respuesta) =>
      respuesta.trim().length < minimoRespuesta
          ? 'La respuesta debe tener al menos $minimoRespuesta caracteres.'
          : null;

  /// Se publica en la página del producto. Reenvía la respuesta que ya
  /// tuviera: al moderar, el backend borra la que no llegue.
  Future<ResultadoAtencion> aprobar(ResenaPersonal r) => accion(
        r,
        () => _repo.moderarResena(
          r.id,
          estado: 'aprobada',
          respuestaNegocio: r.respuestaNegocio,
        ),
        'Reseña aprobada',
      );

  /// No se publica; el cliente ve [motivo] en sus reseñas.
  Future<ResultadoAtencion> rechazar(ResenaPersonal r, String motivo) async {
    final error = validarMotivo(motivo);
    if (error != null) return (mensaje: error, ok: false);
    return accion(
      r,
      () => _repo.moderarResena(
        r.id,
        estado: 'rechazada',
        motivoRechazo: motivo.trim(),
      ),
      'Reseña rechazada',
    );
  }

  /// Publica [respuesta] bajo la reseña, sin cambiar su estado.
  Future<ResultadoAtencion> responder(
    ResenaPersonal r,
    String respuesta,
  ) async {
    final error = validarRespuesta(respuesta);
    if (error != null) return (mensaje: error, ok: false);
    return accion(
      r,
      () => _repo.moderarResena(r.id, respuestaNegocio: respuesta.trim()),
      'Respuesta publicada',
    );
  }
}
