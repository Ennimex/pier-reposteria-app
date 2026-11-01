// lib/ui/atencion/widgets/quejas_personal_tab.dart
//
// Pestaña «Quejas» de Atención a clientes (#138): cada ticket con su tipo,
// estado y prioridad, el asunto y el cliente, los pendientes primero. Al
// tocarlo se abre su detalle con el mensaje del cliente y la respuesta que
// ya tenga; mientras no esté resuelto, «Marcar en proceso» (si está
// pendiente), respuestas rápidas y el campo de la respuesta para mandarla
// sin cerrar el ticket o resolviéndolo, con los textos de la web
// (GestionQuejas.tsx).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/atencion_clientes.dart';
import 'package:pier_reposteria/domain/models/queja.dart';
import 'package:pier_reposteria/ui/atencion/view_model/quejas_personal_view_model.dart';
import 'package:pier_reposteria/ui/atencion/widgets/atencion_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';

/// Lo que se decide en el detalle: marcarla en proceso o responder, sin
/// cerrarla o resolviéndola.
enum _Decision { enProceso, responder, resolver }

/// Respuestas que se pueden cumplir (ninguna promete compensación ni
/// descuento), por tipo, como la web.
const Map<String, List<String>> _respuestasRapidas = {
  'queja': [
    'Sentimos la molestia. Te llamaremos para resolverlo contigo.',
    'Lamentamos lo ocurrido. Pasa a la sucursal con tu número de pedido y lo resolvemos ahí mismo.',
    'Sentimos mucho lo sucedido. Tu satisfacción es muy importante para nosotros. Nos pondremos en contacto contigo directamente para resolverlo.',
  ],
  'sugerencia': [
    '¡Excelente sugerencia! La compartiremos con nuestro equipo para evaluarla. Gracias por ayudarnos a mejorar.',
    'Nos encanta recibir ideas de nuestros clientes. Tomaremos en cuenta tu sugerencia para futuras mejoras en nuestro servicio.',
    'Gracias por tomarte el tiempo de escribirnos. Es una gran idea que vamos a considerar seriamente.',
  ],
  'comentario': [
    '¡Muchas gracias por tus palabras! Nos motiva saber que disfrutas nuestros productos. Te esperamos pronto.',
    '¡Nos alegra mucho leer esto! Tu preferencia es lo que nos impulsa a seguir mejorando. ¡Gracias por ser parte de Pier Repostería!',
    'Gracias por compartir tu experiencia con nosotros. Nos llena de alegría saber que te gustó. ¡Te esperamos de vuelta!',
  ],
};

/// Las de su tipo; un tipo desconocido usa las de un comentario.
List<String> _rapidasDe(String tipo) =>
    _respuestasRapidas[tipo] ?? _respuestasRapidas['comentario']!;

/// Lo que espera respuesta en dorado, en proceso neutro y resuelto en verde.
Color _colorEstado(EstadoQueja estado) => switch (estado) {
      EstadoQueja.pendiente => AppColors.pierDoradoOscuro,
      EstadoQueja.enProceso => AppColors.textSecondary,
      EstadoQueja.resuelto => AppColors.pierVerde,
    };

Color _colorPrioridad(PrioridadQueja prioridad) =>
    prioridad == PrioridadQueja.alta ? AppColors.error : AppColors.textSecondary;

class QuejasPersonalTab extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pestaña crea el suyo.
  const QuejasPersonalTab({super.key, this.viewModel});

  final QuejasPersonalViewModel? viewModel;

  @override
  State<QuejasPersonalTab> createState() => _QuejasPersonalTabState();
}

class _QuejasPersonalTabState extends State<QuejasPersonalTab>
    with AutomaticKeepAliveClientMixin {
  late final QuejasPersonalViewModel _vm =
      widget.viewModel ?? QuejasPersonalViewModel(repo: context.read());

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

  /// Abre el detalle; si ahí se decidió algo, lo manda y avisa cómo salió.
  Future<void> _abrir(QuejaPersonal queja) async {
    final eleccion = await showModalBottomSheet<(_Decision, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: AppMovimiento.estiloHoja(context),
      builder: (_) => _DetalleQueja(queja),
    );
    if (eleccion == null) return;
    final (decision, texto) = eleccion;
    final resultado = await switch (decision) {
      _Decision.enProceso => _vm.marcarEnProceso(queja),
      _Decision.responder => _vm.responder(queja, texto, resolver: false),
      _Decision.resolver => _vm.responder(queja, texto, resolver: true),
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
        vacio: 'No hay quejas ni sugerencias',
        children: [
          for (final q in _vm.quejas)
            _TarjetaQueja(
              key: ValueKey('queja-${q.id}'),
              queja: q,
              ocupado: _vm.ocupado(q),
              alTocar: () => unawaited(_abrir(q)),
            ),
        ],
      ),
    );
  }
}

class _TarjetaQueja extends StatelessWidget {
  const _TarjetaQueja({
    required this.queja,
    required this.ocupado,
    required this.alTocar,
    super.key,
  });

  final QuejaPersonal queja;
  final bool ocupado;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final q = queja;
    return TarjetaAtencion(
      ocupado: ocupado,
      alTocar: ocupado ? null : alTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EtiquetaAtencion(q.tipoTexto, color: AppColors.textSecondary),
              EtiquetaAtencion(
                q.estado.etiqueta,
                color: _colorEstado(q.estado),
              ),
              EtiquetaAtencion(
                q.prioridad.etiqueta,
                color: _colorPrioridad(q.prioridad),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            q.asunto,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${q.ticket} · ${q.cliente}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// El detalle de un ticket. Cierra con lo que se decidió (la respuesta ya
/// validada) o sin nada si la persona solo lo leyó.
class _DetalleQueja extends StatefulWidget {
  const _DetalleQueja(this.queja);

  final QuejaPersonal queja;

  @override
  State<_DetalleQueja> createState() => _DetalleQuejaState();
}

class _DetalleQuejaState extends State<_DetalleQueja> {
  final _respuesta = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _respuesta.dispose();
    super.dispose();
  }

  void _usar(String nota) => setState(() {
        _respuesta.text = nota;
        _error = null;
      });

  void _responder({required bool resolver}) {
    final error = QuejasPersonalViewModel.validarRespuesta(_respuesta.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, (
      resolver ? _Decision.resolver : _Decision.responder,
      _respuesta.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.queja;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                q.asunto,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [q.ticket, q.tipoTexto, q.categoriaTexto]
                    .where((t) => t.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  EtiquetaAtencion(
                    q.estado.etiqueta,
                    color: _colorEstado(q.estado),
                  ),
                  EtiquetaAtencion(
                    q.prioridad.etiqueta,
                    color: _colorPrioridad(q.prioridad),
                  ),
                ],
              ),
              DatoAtencion(
                'Cliente',
                [q.cliente, ?q.email, ?q.telefono].join('\n'),
              ),
              DatoAtencion('Pedido', q.pedidoNumero ?? 'Sin pedido'),
              if (q.descripcion.isNotEmpty)
                BloqueAtencion(
                  titulo: 'Mensaje del cliente',
                  texto: q.descripcion,
                  color: AppColors.textSecondary,
                ),
              if (q.respuesta case final respuesta?)
                BloqueAtencion(
                  titulo: 'Respuesta de Pier Repostería',
                  texto: respuesta,
                  color: AppColors.pierVerde,
                ),
              if (!q.resuelta) ..._paraResponder(q),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _paraResponder(QuejaPersonal q) => [
        const SizedBox(height: 16),
        if (q.estado == EstadoQueja.pendiente)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, (_Decision.enProceso, '')),
              icon: const Icon(LucideIcons.clock, size: 18),
              label: const Text('Marcar en proceso'),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Respuestas rápidas',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        for (final nota in _rapidasDe(q.tipo))
          _RespuestaRapida(nota, alElegir: () => _usar(nota)),
        const SizedBox(height: 8),
        TextField(
          controller: _respuesta,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Respuesta',
            hintText: 'Escribe tu respuesta o elige una rápida',
            errorText: _error,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _responder(resolver: false),
              child: const Text('Responder sin cerrar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
              ),
              onPressed: () => _responder(resolver: true),
              icon: const Icon(LucideIcons.send, size: 18),
              label: const Text('Responder y resolver'),
            ),
          ],
        ),
      ];
}

/// Una respuesta rápida: al tocarla llena el campo (se puede editar).
class _RespuestaRapida extends StatelessWidget {
  const _RespuestaRapida(this.nota, {required this.alElegir});

  final String nota;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alElegir,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                LucideIcons.messageCircle,
                size: 16,
                color: AppColors.pierVerde,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nota,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
