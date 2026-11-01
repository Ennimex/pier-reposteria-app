// lib/ui/atencion/view_model/quejas_personal_view_model.dart
//
// Estado de la pestaña «Quejas» de Atención a clientes (#138): las quejas,
// sugerencias y comentarios de los clientes, las pendientes primero, y lo
// que el personal hace con cada una, como GestionQuejas.tsx de la web:
// marcarla en proceso, responder sin cerrarla o responder y resolverla. Lo
// crea QuejasPersonalTab.
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/queja.dart';
import 'package:pier_reposteria/ui/atencion/view_model/lista_atencion_view_model.dart';

class QuejasPersonalViewModel extends ListaAtencionViewModel<QuejaPersonal> {
  QuejasPersonalViewModel({required AtencionClientesRepository repo})
      : _repo = repo;

  final AtencionClientesRepository _repo;

  /// Caracteres mínimos de una respuesta (como la web).
  static const minimoRespuesta = 10;

  @override
  Future<List<QuejaPersonal>> pedirLista() => _repo.quejas();

  @override
  String idDe(QuejaPersonal elemento) => elemento.id;

  /// Pendientes, luego en proceso y al final las resueltas; dentro de cada
  /// estado, de la más reciente a la más antigua (como las manda el backend).
  List<QuejaPersonal> get quejas => [
        for (final estado in EstadoQueja.values)
          ...elementos.where((q) => q.estado == estado),
      ];

  /// La respuesta para el cliente; null si está bien.
  static String? validarRespuesta(String respuesta) =>
      respuesta.trim().length < minimoRespuesta
          ? 'La respuesta debe tener al menos $minimoRespuesta caracteres.'
          : null;

  /// «Marcar en proceso». Reenvía la respuesta que ya tenía: el backend
  /// guarda la que llegue y, sin ella, la borraría.
  Future<ResultadoAtencion> marcarEnProceso(QuejaPersonal queja) => accion(
        queja,
        () => _repo.atenderQueja(
          queja.id,
          estado: 'en_proceso',
          respuesta: queja.respuesta,
        ),
        '${queja.ticket} quedó en proceso',
      );

  /// «Responder y resolver» (con [resolver]) o «Responder sin cerrar», que
  /// la deja en proceso.
  Future<ResultadoAtencion> responder(
    QuejaPersonal queja,
    String respuesta, {
    required bool resolver,
  }) async {
    final error = validarRespuesta(respuesta);
    if (error != null) return (mensaje: error, ok: false);
    return accion(
      queja,
      () => _repo.atenderQueja(
        queja.id,
        estado: resolver ? 'resuelto' : 'en_proceso',
        respuesta: respuesta.trim(),
      ),
      resolver
          ? 'Respuesta enviada: ${queja.ticket} quedó resuelto'
          : 'Respuesta enviada: ${queja.ticket} sigue en proceso',
    );
  }
}
