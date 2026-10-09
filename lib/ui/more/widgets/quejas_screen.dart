// lib/ui/more/widgets/quejas_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository.dart';
import 'package:pier_pasteleria/domain/models/queja.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/more/view_model/quejas_view_model.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:provider/provider.dart';

// Color e icono de cada estado (presentación; el enum vive en domain/).
extension on EstadoQueja {
  Color get color => switch (this) {
        EstadoQueja.pendiente => AppColors.estadoPendiente,
        EstadoQueja.enProceso => AppColors.estadoPreparacion,
        EstadoQueja.resuelto => AppColors.estadoListo,
      };
  Color get bgColor => color.withValues(alpha: 0.1);
  IconData get icon => switch (this) {
        EstadoQueja.pendiente => LucideIcons.hourglass,
        EstadoQueja.enProceso => LucideIcons.refreshCw,
        EstadoQueja.resuelto => Icons.check_circle_rounded,
      };
}

// ── Screen ────────────────────────────────────────────────────────
class QuejasScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const QuejasScreen({super.key, this.viewModel});

  final QuejasViewModel? viewModel;

  @override
  State<QuejasScreen> createState() => _QuejasScreenState();
}

class _QuejasScreenState extends State<QuejasScreen> {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final QuejasViewModel _vm = widget.viewModel ??
      QuejasViewModel(
        quejasRepo: QuejasRepository(),
        pedidosRepo: PedidosRepository(),
      );

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ QuejasScreen');
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _abrirFormulario() {
    PierLog.nav('→ QuejasScreen BottomSheet formulario');
    _vm.nuevaQueja();
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioQueja(
        vm: _vm,
        onEnviado: () => Navigator.pop(context),
      ),
    ));
  }

  String _formatearFecha(DateTime? dt) {
    if (dt == null) return '';
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${dt.day} ${meses[dt.month - 1]}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildContenido(),
    );
  }

  Widget _buildContenido() {
    final quejas = _vm.quejas;
    final cargando = _vm.cargando;
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.pierVerdeOscuro,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.chevronLeft,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mis Quejas',
                                style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('Quejas, sugerencias y comentarios',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      // Botón nueva queja
                      GestureDetector(
                        onTap: _abrirFormulario,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus,
                                  color: AppColors.pierVerdeOscuro,
                                  size: 16),
                              const SizedBox(width: 5),
                              Text('Nueva',
                                  style: TextStyle(
                                      color: AppColors.pierVerdeOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!cargando && quejas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${quejas.length} registro${quejas.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── CONTENIDO ─────────────────────────────────────────
            Expanded(
              child: cargando
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : quejas.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _vm.cargar,
                          color: AppColors.pierVerde,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: quejas.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildCard(quejas[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Queja q) {
    final ticket = q.ticket;
    final asunto = q.asunto;
    final descripcion = q.descripcion;
    final respuesta = q.respuesta;
    final pedidoId = q.pedidoId;
    final estado = q.estado;
    final fecha = _formatearFecha(q.creadaEn);
    final expandida = _vm.expandidaId == q.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── CABECERA ────────────────────────────────────────────
          GestureDetector(
            onTap: () => _vm.alternar(q.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  // Icono
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.messageCircle,
                        color: AppColors.pierVerde, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ticket + badges
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            Text(ticket,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary.withValues(alpha: 0.5))),
                            const SizedBox(width: 6),
                            _estadoBadge(estado),
                            const SizedBox(width: 6),
                            _miniChip(q.tipoTexto),
                            const SizedBox(width: 6),
                            _miniChip(q.categoriaTexto),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text(asunto,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(fecha,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  Icon(
                    expandida
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // ── DETALLE EXPANDIDO ────────────────────────────────────
          if (expandida) ...[
            Divider(height: 1, color: AppColors.textSecondary.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  const Text('Descripción',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: .3)),
                  const SizedBox(height: 6),
                  Text(descripcion,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5)),

                  // Pedido asociado
                  if (pedidoId != null) ...[
                    const SizedBox(height: 12),
                    const Text('Pedido asociado',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: .3)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              LucideIcons.receiptText,
                              size: 14,
                              color: AppColors.pierVerde),
                          const SizedBox(width: 6),
                          Text('Pedido #${_vm.numeroDePedido(pedidoId)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.pierVerde,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],

                  // Respuesta del equipo (solo si hay respuesta)
                  if (respuesta != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: AppColors.pierVerde),
                            const SizedBox(width: 6),
                            Text('Respuesta del equipo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.pierVerde)),
                          ]),
                          const SizedBox(height: 8),
                          Text(respuesta,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.pierVerdeOscuro,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estadoBadge(EstadoQueja estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(estado.icon, size: 11, color: estado.color),
        const SizedBox(width: 4),
        Text(estado.etiqueta,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: estado.color)),
      ]),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.messageCircle,
                  size: 46,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            const Text('Sin quejas registradas',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Si tienes alguna queja, sugerencia o\ncomentario, cuéntanoslo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(LucideIcons.plus,
                  color: Colors.white, size: 18),
              label: const Text('Crear primera queja',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario (BottomSheet) ──────────────────────────────────────
class _FormularioQueja extends StatefulWidget {
  const _FormularioQueja({
    required this.vm,
    required this.onEnviado,
  });

  final QuejasViewModel vm;
  final VoidCallback onEnviado;

  @override
  State<_FormularioQueja> createState() => _FormularioQuejaState();
}

class _FormularioQuejaState extends State<_FormularioQueja> {
  final _asuntoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  QuejasViewModel get _vm => widget.vm;

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final r = await _vm.enviar(
      asunto: _asuntoCtrl.text,
      descripcion: _descripcionCtrl.text,
    );
    if (!mounted) return;
    final error = r.error;
    final ticket = r.ticket;
    if (error != null) {
      _showSnack(error);
    } else if (ticket != null) {
      widget.onEnviado();
      _showSnackSuccess('Queja enviada — ticket $ticket');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSnackSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildHoja(context),
    );
  }

  Widget _buildHoja(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible: con el texto del sistema grande no desborda.
                const Flexible(
                  child: Text('Nueva queja o sugerencia',
                      style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.x,
                        size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tipo
            _label('Tipo'),
            _selector<TipoQueja>(
              value: _vm.tipo,
              items: TipoQueja.values,
              labelOf: (t) => t.etiqueta,
              onChanged: _vm.seleccionarTipo,
            ),
            const SizedBox(height: 14),

            // Categoría
            _label('Categoría'),
            _selector<CategoriaQueja>(
              value: _vm.categoria,
              items: CategoriaQueja.values,
              labelOf: (c) => c.etiqueta,
              onChanged: _vm.seleccionarCategoria,
            ),
            const SizedBox(height: 14),

            // Pedido asociado (opcional)
            _label('Pedido asociado', opcional: true),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _vm.pedidoId,
                  isExpanded: true,
                  icon: Icon(LucideIcons.chevronDown,
                      color: AppColors.pierVerde),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  hint: Text('Sin pedido asociado',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.5))),
                  items: [
                    const DropdownMenuItem<String>(
                      child: Text('Sin pedido asociado',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                    ),
                    ..._vm.pedidos.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          '#${p.numero} — \$${p.total.toStringAsFixed(0)} (${p.statusText})',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: _vm.seleccionarPedido,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Asunto
            _label('Asunto'),
            TextField(
              controller: _asuntoCtrl,
              maxLength: 150,
              decoration: _inputDeco(
                  hint: 'Describe brevemente tu queja'),
            ),
            const SizedBox(height: 14),

            // Descripción
            _label('Descripción'),
            TextField(
              controller: _descripcionCtrl,
              maxLines: 4,
              maxLength: 1000,
              decoration:
                  _inputDeco(hint: 'Detalla tu queja o sugerencia...'),
            ),
            const SizedBox(height: 20),

            // Botón enviar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _vm.enviando ? null : _enviar,
                icon: _vm.enviando
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.send,
                        color: Colors.white, size: 18),
                label: Text(
                    _vm.enviando ? 'Enviando...' : 'Enviar queja',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  disabledBackgroundColor:
                      AppColors.pierVerde.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool opcional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (opcional) ...[
            const SizedBox(width: 4),
            Text('(opcional)',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );
  }

  Widget _selector<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown,
              color: AppColors.pierVerde),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(labelOf(i),
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      counterStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.textSecondary.withValues(alpha: 0.25))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppColors.pierVerde, width: 1.5)),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}
