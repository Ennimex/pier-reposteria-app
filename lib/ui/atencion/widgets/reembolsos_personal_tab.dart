// lib/ui/atencion/widgets/reembolsos_personal_tab.dart
//
// Pestaña «Reembolsos» de Atención a clientes (#138): cada solicitud con su
// pedido, cliente, monto, motivo y estado (y si la generó el sistema al
// cancelar un pedido pagado), las que esperan una decisión primero. Al
// tocarla se abre su detalle con la descripción, la evidencia fotográfica
// (cada foto se amplía al tocarla) y los pasos que permite el rol: el
// mostrador la pasa a revisión; gerencia y dirección la aprueban, la
// rechazan con justificación y la marcan como devuelta después de hacer la
// devolución en Stripe. Cada paso se confirma con los textos de la web
// (GestionReembolsos.tsx).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/reembolso.dart';
import 'package:pier_reposteria/ui/atencion/view_model/reembolsos_personal_view_model.dart';
import 'package:pier_reposteria/ui/atencion/widgets/atencion_partes.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/utils/moneda.dart';
import 'package:provider/provider.dart';

/// Lo que espera una decisión en dorado, lo resuelto a favor en verde y lo
/// rechazado en terracota (como la web).
Color _colorEstado(EstadoReembolso estado) => switch (estado) {
      EstadoReembolso.pendiente ||
      EstadoReembolso.enRevision =>
        AppColors.pierDoradoOscuro,
      EstadoReembolso.aprobado ||
      EstadoReembolso.procesado =>
        AppColors.pierVerde,
      EstadoReembolso.rechazado => AppColors.error,
    };

/// La confirmación de [paso]: título, pedido y monto, lo que hay que saber
/// y el texto que lee el cliente (la justificación, al rechazar).
PeticionAtencion _peticion(
  PasoReembolso paso,
  ReembolsoPersonal r,
  String inicial,
) {
  final monto = moneda(r.monto);
  return PeticionAtencion(
    titulo: paso.titulo,
    subtitulo: 'Pedido ${r.pedidoNumero} · $monto',
    boton: paso.etiqueta,
    peligro: paso == PasoReembolso.rechazar,
    texto: switch (paso) {
      PasoReembolso.aprobar =>
        'Aprobar registra la decisión y avisa al cliente; la devolución del '
            'dinero se hace en Stripe. Cuando la hagas, márcala como devuelta.',
      PasoReembolso.devolver =>
        'Esto solo registra la devolución: hazla primero en Stripe por $monto.',
      PasoReembolso.revision || PasoReembolso.rechazar => null,
    },
    campo: CampoAtencion(
      etiqueta: switch (paso) {
        PasoReembolso.rechazar => 'Justificación del rechazo',
        PasoReembolso.devolver => 'Mensaje para el cliente (opcional)',
        PasoReembolso.revision ||
        PasoReembolso.aprobar =>
          'Mensaje para el cliente',
      },
      ayuda: switch (paso) {
        PasoReembolso.rechazar =>
          'Mínimo ${ReembolsosPersonalViewModel.minimoJustificacion} '
              'caracteres. El cliente la verá en su solicitud.',
        PasoReembolso.devolver =>
          'Puedes agregar la referencia de la devolución en Stripe. Si lo '
              'dejas vacío, se conserva el mensaje actual.',
        PasoReembolso.aprobar =>
          'Lo verá en su solicitud. Si lo dejas vacío, dirá «Reembolso '
              'aprobado».',
        PasoReembolso.revision => 'Lo verá en su solicitud.',
      },
      inicial: inicial,
      validar: (texto) => ReembolsosPersonalViewModel.validarNota(paso, texto),
    ),
  );
}

class ReembolsosPersonalTab extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pestaña crea el suyo
  /// con el rol de la sesión.
  const ReembolsosPersonalTab({super.key, this.viewModel});

  final ReembolsosPersonalViewModel? viewModel;

  @override
  State<ReembolsosPersonalTab> createState() => _ReembolsosPersonalTabState();
}

class _ReembolsosPersonalTabState extends State<ReembolsosPersonalTab>
    with AutomaticKeepAliveClientMixin {
  late final ReembolsosPersonalViewModel _vm = widget.viewModel ??
      ReembolsosPersonalViewModel(
        repo: context.read(),
        rol: context.read<AuthProvider>().rol,
      );

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

  /// Abre el detalle; si ahí se confirmó un paso, lo da y avisa cómo salió.
  Future<void> _abrir(ReembolsoPersonal r) async {
    final eleccion = await showModalBottomSheet<(PasoReembolso, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: AppMovimiento.estiloHoja(context),
      builder: (_) => _DetalleReembolso(
        reembolso: r,
        pasos: _vm.pasos(r),
        esperaDecision: _vm.esperaDecision(r),
        notaInicial: (paso) => _vm.notaInicial(paso, r),
      ),
    );
    if (eleccion == null) return;
    final (paso, nota) = eleccion;
    final resultado = await _vm.dar(paso, r, nota);
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
        vacio: 'No hay solicitudes de reembolso',
        children: [
          for (final r in _vm.reembolsos)
            _TarjetaReembolso(
              key: ValueKey('reembolso-${r.id}'),
              reembolso: r,
              ocupado: _vm.ocupado(r),
              alTocar: () => unawaited(_abrir(r)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaReembolso extends StatelessWidget {
  const _TarjetaReembolso({
    required this.reembolso,
    required this.ocupado,
    required this.alTocar,
    super.key,
  });

  final ReembolsoPersonal reembolso;
  final bool ocupado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final r = reembolso;
    final fotos = r.fotos.length;
    return TarjetaAtencion(
      ocupado: ocupado,
      alTocar: ocupado ? null : alTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Pedido ${r.pedidoNumero}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                moneda(r.monto),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.pierVerde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            r.cliente,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          Text(
            r.motivoTexto,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EtiquetaAtencion(
                r.estadoTexto,
                color: _colorEstado(r.estado),
              ),
              if (r.automatico)
                const EtiquetaAtencion(
                  'Automático por cancelación',
                  color: AppColors.textSecondary,
                ),
              if (fotos > 0)
                EtiquetaAtencion(
                  fotos == 1 ? '1 foto' : '$fotos fotos',
                  color: AppColors.textSecondary,
                  icono: LucideIcons.camera,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El detalle de una solicitud. Cierra con el paso confirmado (y su texto)
/// o sin nada si la persona solo la revisó.
class _DetalleReembolso extends StatelessWidget {
  const _DetalleReembolso({
    required this.reembolso,
    required this.pasos,
    required this.esperaDecision,
    required this.notaInicial,
  });

  final ReembolsoPersonal reembolso;
  final List<PasoReembolso> pasos;
  final bool esperaDecision;
  final String Function(PasoReembolso paso) notaInicial;

  /// Confirma [paso] y cierra el detalle con él; si la persona se
  /// arrepiente, el detalle sigue abierto.
  Future<void> _dar(BuildContext context, PasoReembolso paso) async {
    final nota = await pedirAtencion(
      context,
      _peticion(paso, reembolso, notaInicial(paso)),
    );
    if (nota == null || !context.mounted) return;
    Navigator.pop(context, (paso, nota));
  }

  @override
  Widget build(BuildContext context) {
    final r = reembolso;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Solicitud del pedido ${r.pedidoNumero}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                EtiquetaAtencion(
                  r.estadoTexto,
                  color: _colorEstado(r.estado),
                ),
              ],
            ),
            DatoAtencion('Cliente', [r.cliente, ?r.telefono].join('\n')),
            DatoAtencion('Monto', moneda(r.monto)),
            DatoAtencion('Motivo', r.motivoTexto),
            if (r.descripcion case final descripcion?)
              BloqueAtencion(
                titulo: 'Descripción',
                texto: descripcion,
                color: AppColors.textSecondary,
              ),
            if (r.automatico)
              const BloqueAtencion(
                titulo: 'Reembolso automático por cancelación',
                texto: 'Lo generó el sistema al cancelar o rechazar un pedido '
                    'pagado: no se mide contra la política de reembolso.',
                color: AppColors.textSecondary,
              ),
            if (r.fotos.isNotEmpty) _Evidencia(r.fotos),
            if (r.respuestaAdmin case final mensaje?)
              BloqueAtencion(
                titulo: 'Mensaje para el cliente',
                texto: mensaje,
                color: AppColors.textSecondary,
              ),
            if (r.justificacionRechazo case final justificacion?
                when r.estado == EstadoReembolso.rechazado)
              BloqueAtencion(
                titulo: 'Justificación del rechazo',
                texto: justificacion,
                color: AppColors.error,
              ),
            if (esperaDecision)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Gerencia decide si se aprueba o se rechaza.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            if (pasos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // El último paso es el principal (como la web).
                  for (final paso in pasos)
                    if (paso == pasos.last)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.pierVerde,
                        ),
                        onPressed: () => unawaited(_dar(context, paso)),
                        child: Text(paso.etiqueta),
                      )
                    else
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: paso == PasoReembolso.rechazar
                              ? AppColors.error
                              : AppColors.pierVerde,
                        ),
                        onPressed: () => unawaited(_dar(context, paso)),
                        child: Text(paso.etiqueta),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Evidencia fotográfica (N)»: miniaturas que se amplían al tocarlas.
class _Evidencia extends StatelessWidget {
  const _Evidencia(this.fotos);

  final List<String> fotos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.camera,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Evidencia fotográfica (${fotos.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, url) in fotos.indexed)
                _Miniatura(url: url, numero: i + 1),
            ],
          ),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url, required this.numero});

  final String url;
  final int numero;

  static const double _lado = 72;

  Future<void> _ampliar(BuildContext context) => showDialog<void>(
        context: context,
        animationStyle: AppMovimiento.estiloDialogo(context),
        builder: (dialogo) => EntradaDialogo(
          child: Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          'Evidencia fotográfica',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogo),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 200,
                        child: _FotoNoDisponible(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ampliar la foto $numero',
      child: InkWell(
        onTap: () => unawaited(_ampliar(context)),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: _lado,
            height: _lado,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: _lado,
              height: _lado,
              child: _FotoNoDisponible(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FotoNoDisponible extends StatelessWidget {
  const _FotoNoDisponible();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pierArena,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
          child: Icon(LucideIcons.imageOff, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
