// lib/ui/atencion/view_model/reembolsos_personal_view_model.dart
//
// Estado de la pestaña «Reembolsos» de Atención a clientes (#138): las
// solicitudes de los clientes, las que esperan una decisión primero, y los
// pasos de cada una con las reglas del backend y de la web
// (GestionReembolsos.tsx): el mostrador solo las pasa a revisión; aprobar,
// rechazar y marcar como devuelto lo deciden gerencia o dirección. Aprobar
// no mueve dinero: la devolución se hace en Stripe y luego se marca aquí.
// Lo crea ReembolsosPersonalTab con el rol de la sesión.
import 'package:pier_reposteria/data/repositories/atencion_clientes_repository.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/ui/atencion/view_model/lista_atencion_view_model.dart';

/// Un paso de la solicitud: el texto de su botón y el título de su
/// confirmación (los de la web).
enum PasoReembolso {
  revision('Pasar a revisión', 'Pasar a revisión'),
  rechazar('Rechazar', 'Rechazar reembolso'),
  aprobar('Aprobar', 'Aprobar reembolso'),
  devolver('Marcar como devuelto', 'Marcar como devuelto');

  const PasoReembolso(this.etiqueta, this.titulo);

  final String etiqueta;
  final String titulo;
}

class ReembolsosPersonalViewModel
    extends ListaAtencionViewModel<ReembolsoPersonal> {
  /// [rol] es el de la sesión: gerencia y dirección deciden.
  ReembolsosPersonalViewModel({
    required AtencionClientesRepository repo,
    required String? rol,
  })  : _repo = repo,
        decide = rol == 'gerencia' || rol == 'direccion_general';

  final AtencionClientesRepository _repo;

  /// Gerencia o dirección: aprueban, rechazan y marcan como devuelto.
  final bool decide;

  /// Caracteres mínimos de la justificación de un rechazo (como la web).
  static const minimoJustificacion = 20;

  /// Lo que lee el cliente cuando su solicitud pasa a revisión.
  static const mensajeRevision =
      'Recibimos tu solicitud; gerencia la revisará hoy.';

  @override
  Future<List<ReembolsoPersonal>> pedirLista() => _repo.reembolsos();

  @override
  String idDe(ReembolsoPersonal elemento) => elemento.id;

  /// Pendientes, en revisión y aprobadas (falta devolverlas) primero; al
  /// final las devueltas y las rechazadas. Dentro de cada estado, de la más
  /// reciente a la más antigua (como las manda el backend).
  List<ReembolsoPersonal> get reembolsos => [
        for (final estado in EstadoReembolso.values)
          ...elementos.where((r) => r.estado == estado),
      ];

  /// Los pasos que se ofrecen en cada estado: los mismos que valida el
  /// servidor. Rechazada y devuelta ya no tienen pasos.
  List<PasoReembolso> pasos(ReembolsoPersonal r) {
    if (r.estado == EstadoReembolso.pendiente) {
      return decide
          ? const [
              PasoReembolso.revision,
              PasoReembolso.rechazar,
              PasoReembolso.aprobar,
            ]
          : const [PasoReembolso.revision];
    }
    if (!decide) return const [];
    if (r.estado == EstadoReembolso.enRevision) {
      return const [PasoReembolso.rechazar, PasoReembolso.aprobar];
    }
    if (r.estado == EstadoReembolso.aprobado) {
      return const [PasoReembolso.devolver];
    }
    return const [];
  }

  /// El mostrador ve una solicitud en revisión: la decide gerencia.
  bool esperaDecision(ReembolsoPersonal r) =>
      !decide && r.estado == EstadoReembolso.enRevision;

  /// El texto con que abre la confirmación del paso. Aprobar y devolver
  /// parten del mensaje que ya ve el cliente, salvo el aviso de revisión,
  /// que ya no aplica al aprobar (vacío dirá «Reembolso aprobado»).
  String notaInicial(PasoReembolso paso, ReembolsoPersonal r) {
    final actual = r.respuestaAdmin ?? '';
    return switch (paso) {
      PasoReembolso.revision => mensajeRevision,
      PasoReembolso.rechazar => '',
      PasoReembolso.aprobar => actual == mensajeRevision ? '' : actual,
      PasoReembolso.devolver => actual,
    };
  }

  /// El texto del paso; null si está bien. Solo el rechazo lo exige.
  static String? validarNota(PasoReembolso paso, String nota) =>
      paso == PasoReembolso.rechazar &&
              nota.trim().length < minimoJustificacion
          ? 'La justificación debe tener al menos $minimoJustificacion '
              'caracteres.'
          : null;

  /// Da [paso] con [nota]: el mensaje para el cliente o, al rechazar, la
  /// justificación. Aprobar sin mensaje dice «Reembolso aprobado»; devolver
  /// sin mensaje conserva el de la aprobación (el backend no lo borra).
  Future<ResultadoAtencion> dar(
    PasoReembolso paso,
    ReembolsoPersonal r,
    String nota,
  ) async {
    final error = validarNota(paso, nota);
    if (error != null) return (mensaje: error, ok: false);
    final texto = nota.trim();
    final mensaje = texto.isEmpty ? null : texto;
    final pedido = r.pedidoNumero;
    return accion(
      r,
      () => switch (paso) {
        PasoReembolso.revision => _repo.resolverReembolso(
            r.id,
            estado: 'en_revision',
            respuestaAdmin: mensaje,
          ),
        PasoReembolso.rechazar => _repo.resolverReembolso(
            r.id,
            estado: 'rechazado',
            justificacionRechazo: texto,
          ),
        PasoReembolso.aprobar => _repo.resolverReembolso(
            r.id,
            estado: 'aprobado',
            respuestaAdmin: mensaje ?? 'Reembolso aprobado',
          ),
        PasoReembolso.devolver => _repo.resolverReembolso(
            r.id,
            estado: 'procesado',
            respuestaAdmin: mensaje,
          ),
      },
      switch (paso) {
        PasoReembolso.revision =>
          'La solicitud del pedido $pedido pasó a revisión',
        PasoReembolso.rechazar => 'Reembolso del pedido $pedido rechazado',
        PasoReembolso.aprobar => 'Reembolso del pedido $pedido aprobado',
        PasoReembolso.devolver =>
          'Reembolso del pedido $pedido marcado como devuelto',
      },
    );
  }
}
