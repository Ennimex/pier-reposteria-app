// lib/ui/atencion/widgets/resenas_personal_tab.dart
//
// Pestaña «Reseñas» de Atención a clientes (#138): cada reseña con su
// producto, autor, estrellas, título y comentario, su estado y las marcas
// «Aprobada automáticamente» y «Compra verificada», las que esperan revisión
// primero (con el porqué). Las pendientes se aprueban (se publican en la
// página del producto) o se rechazan con motivo; a las aprobadas sin
// respuesta se les responde como Pier Repostería. Textos de la web
// (GestionResenas.tsx).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/mi_resena.dart';
import 'package:pier_reposteria/ui/atencion/view_model/resenas_personal_view_model.dart';
import 'package:pier_reposteria/ui/atencion/widgets/atencion_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:provider/provider.dart';

enum _Accion { aprobar, rechazar, responder }

Color _colorEstado(EstadoResena estado) => switch (estado) {
      EstadoResena.enRevision => AppColors.pierDoradoOscuro,
      EstadoResena.aprobada => AppColors.pierVerde,
      EstadoResena.rechazada => AppColors.error,
    };

/// Lo que dice el diálogo de [accion]: aprobar solo confirma; rechazar pide
/// el motivo y responder, el texto público.
PeticionAtencion _peticion(_Accion accion, ResenaPersonal r) {
  final de = 'De ${r.autor} · ${r.productoNombre}';
  final cita = '«${r.comentario}»';
  return switch (accion) {
    _Accion.aprobar => PeticionAtencion(
        titulo: 'Aprobar reseña',
        subtitulo: de,
        texto: 'Se verá públicamente en la página del producto.',
        boton: 'Aprobar',
      ),
    _Accion.rechazar => PeticionAtencion(
        titulo: 'Rechazar reseña',
        subtitulo: de,
        texto: cita,
        boton: 'Rechazar',
        peligro: true,
        campo: const CampoAtencion(
          etiqueta: 'Motivo del rechazo',
          ayuda: 'Mínimo ${ResenasPersonalViewModel.minimoMotivo} caracteres. '
              'El cliente lo verá en sus reseñas.',
          validar: ResenasPersonalViewModel.validarMotivo,
        ),
      ),
    _Accion.responder => PeticionAtencion(
        titulo: 'Responder como Pier Repostería',
        subtitulo: de,
        texto: cita,
        boton: 'Publicar respuesta',
        campo: const CampoAtencion(
          etiqueta: 'Respuesta',
          ayuda: 'Se ve públicamente en la página del producto.',
          validar: ResenasPersonalViewModel.validarRespuesta,
        ),
      ),
  };
}

class ResenasPersonalTab extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pestaña crea el suyo.
  const ResenasPersonalTab({super.key, this.viewModel});

  final ResenasPersonalViewModel? viewModel;

  @override
  State<ResenasPersonalTab> createState() => _ResenasPersonalTabState();
}

class _ResenasPersonalTabState extends State<ResenasPersonalTab>
    with AutomaticKeepAliveClientMixin {
  late final ResenasPersonalViewModel _vm =
      widget.viewModel ?? ResenasPersonalViewModel(repo: context.read());

  // La lista se conserva al cambiar de pestaña.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Pide la confirmación o el texto de [accion], la corre y avisa cómo
  /// salió.
  Future<void> _hacer(ResenaPersonal r, _Accion accion) async {
    final texto = await pedirAtencion(context, _peticion(accion, r));
    if (texto == null) return;
    final resultado = await switch (accion) {
      _Accion.aprobar => _vm.aprobar(r),
      _Accion.rechazar => _vm.rechazar(r, texto),
      _Accion.responder => _vm.responder(r, texto),
    };
    if (!mounted) return;
    avisarAtencion(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Observa el tema de temporada: repinta la pestaña si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => ListaAtencion(
        viewModel: _vm,
        vacio: 'No hay reseñas',
        children: [
          for (final r in _vm.resenas)
            _TarjetaResena(
              key: ValueKey('resena-${r.id}'),
              resena: r,
              ocupado: _vm.ocupado(r),
              puedeModerar: _vm.puedeModerar(r),
              puedeResponder: _vm.puedeResponder(r),
              alHacer: (accion) => unawaited(_hacer(r, accion)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaResena extends StatelessWidget {
  const _TarjetaResena({
    required this.resena,
    required this.ocupado,
    required this.puedeModerar,
    required this.puedeResponder,
    required this.alHacer,
    super.key,
  });

  final ResenaPersonal resena;
  final bool ocupado;
  final bool puedeModerar;
  final bool puedeResponder;
  final void Function(_Accion accion) alHacer;

  @override
  Widget build(BuildContext context) {
    final r = resena;
    return TarjetaAtencion(
      ocupado: ocupado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (puedeModerar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.shieldAlert,
                    size: 16,
                    color: AppColors.pierDoradoOscuro,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r.motivoRetencion}: requiere revisión',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.pierDoradoOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            r.productoNombre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            r.autor,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          _Estrellas(r.estrellas),
          if (r.titulo case final titulo?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              r.comentario,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EtiquetaAtencion(r.estadoTexto, color: _colorEstado(r.estado)),
              if (r.autoAprobada && r.estado == EstadoResena.aprobada)
                const EtiquetaAtencion(
                  'Aprobada automáticamente',
                  color: AppColors.textSecondary,
                ),
              if (r.verificada)
                EtiquetaAtencion(
                  'Compra verificada',
                  color: AppColors.pierVerde,
                  icono: LucideIcons.badgeCheck,
                ),
            ],
          ),
          if (r.respuestaNegocio case final respuesta?)
            BloqueAtencion(
              titulo: 'Respuesta de Pier Repostería',
              texto: respuesta,
              color: AppColors.pierVerde,
            ),
          if (r.motivoRechazo case final motivo?
              when r.estado == EstadoResena.rechazada)
            BloqueAtencion(
              titulo: 'Motivo del rechazo',
              texto: motivo,
              color: AppColors.error,
            ),
          if (!ocupado && (puedeModerar || puedeResponder)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (puedeModerar) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                    ),
                    onPressed: () => alHacer(_Accion.aprobar),
                    icon: const Icon(LucideIcons.thumbsUp, size: 18),
                    label: const Text('Aprobar'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () => alHacer(_Accion.rechazar),
                    icon: const Icon(LucideIcons.thumbsDown, size: 18),
                    label: const Text('Rechazar'),
                  ),
                ],
                if (puedeResponder)
                  OutlinedButton.icon(
                    onPressed: () => alHacer(_Accion.responder),
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: const Text('Responder como Pier Repostería'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Las estrellas de la calificación; el lector de pantalla dice «N de 5
/// estrellas».
class _Estrellas extends StatelessWidget {
  const _Estrellas(this.cuantas);

  final int cuantas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$cuantas de 5 estrellas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= cuantas ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: i <= cuantas
                    ? AppColors.pierDorado
                    : AppColors.textSecondary.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
