// lib/ui/refunds/widgets/refunds_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/domain/models/reembolso.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/refunds/view_model/refunds_view_model.dart';
import 'package:provider/provider.dart';

class RefundsScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const RefundsScreen({super.key, this.viewModel});

  final RefundsViewModel? viewModel;

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen>
    with SingleTickerProviderStateMixin {
  // El State es dueño del ViewModel (lo crea, lo carga y lo libera).
  late final RefundsViewModel _vm = widget.viewModel ??
      RefundsViewModel(
        reembolsosRepo: ReembolsosRepository(),
        pedidosRepo: PedidosRepository(),
      );
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descripcionCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await _vm.enviar(descripcion: _descripcionCtrl.text);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, AppColors.error);
      return;
    }
    _showSnack('Solicitud enviada con éxito', AppColors.pierVerde);
    _descripcionCtrl.clear();
    _tabController.animateTo(0);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Título dinámico según tab activo
  String get _titulo => _tabController.index == 0
      ? 'Reembolsos'
      : 'Solicitar Reembolso';

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (_, _) => Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(LucideIcons.chevronLeft,
                            size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(_titulo,
                          style: const TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                    // Ícono ? solo en Nueva Solicitud
                    if (_tabController.index == 1)
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(LucideIcons.circleHelp,
                            size: 18, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),

            // ── TABS ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  // Sin setState: el header (título, ícono ?) y el FAB ya
                  // reaccionan vía AnimatedBuilder, y el TabBar/TabBarView los
                  // maneja el propio controller. Un setState aquí reconstruía
                  // toda la pantalla durante la animación y causaba el tirón.
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.pierVerde,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: 'Mis Solicitudes'),
                    Tab(text: 'Nueva Solicitud'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── CONTENIDO ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ListenableBuilder(
                    listenable: _vm,
                    builder: (_, _) => _buildMisSolicitudes(),
                  ),
                  ListenableBuilder(
                    listenable: _vm,
                    builder: (_, _) => _buildNuevaSolicitud(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, _) => _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _tabController.animateTo(1),
                backgroundColor: AppColors.pierVerde,
                icon: const Icon(LucideIcons.plus, color: Colors.white),
                label: const Text('Nueva Solicitud',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── TAB 1: MIS SOLICITUDES ──────────────────────────────────────
  Widget _buildMisSolicitudes() {
    final reembolsos = _vm.reembolsos;
    if (_vm.cargandoReembolsos) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.pierVerde));
    }
    if (reembolsos.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _vm.cargarReembolsos,
      color: AppColors.pierVerde,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: reembolsos.length + 1,
        itemBuilder: (context, i) {
          // Índice 0 = título de sección
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Historial de solicitudes',
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildReembolsoCard(reembolsos[i - 1]),
          );
        },
      ),
    );
  }

  Widget _buildReembolsoCard(Reembolso r) {
    final monto = r.monto;
    final respuesta = r.respuestaAdmin;

    // Estado visual
    final (statusColor, statusLabel) = switch (r.estado) {
      EstadoReembolso.aprobado => (AppColors.pierVerde, 'Aprobado'),
      EstadoReembolso.procesado => (AppColors.pierVerde, 'Procesado'),
      EstadoReembolso.rechazado => (AppColors.estadoCancelado, 'Rechazado'),
      EstadoReembolso.enRevision =>
        (AppColors.estadoPreparacion, 'En revisión'),
      EstadoReembolso.pendiente => (AppColors.estadoPendiente, 'Pendiente'),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER CARD ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.pierVerde.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.receiptText,
                      color: AppColors.pierVerde, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${r.pedidoNumero}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFecha(r.creadoEn),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Chip de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.textSecondary.withValues(alpha: 0.15)),

          // ── MOTIVO + MONTO ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Motivo',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(r.motivo ?? '—',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Monto',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('\$${monto.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pierVerde)),
                  ],
                ),
              ],
            ),
          ),

          // ── RESPUESTA DE PIER ─────────────────────────────────
          if (respuesta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.pierArena,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.pierDorado.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('✦ ',
                          style: TextStyle(
                              color: AppColors.pierDorado,
                              fontSize: 12)),
                      Text('Respuesta de Pier',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.pierDoradoOscuro)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      respuesta,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── TAB 2: NUEVA SOLICITUD ──────────────────────────────────────
  Widget _buildNuevaSolicitud() {
    final pedidos = _vm.pedidos;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── AVISO ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.pierDorado.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.pierDorado.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info,
                      color: AppColors.pierDoradoOscuro, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Solo se pueden reembolsar pedidos completados. El monto corresponde al total del pedido.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.pierDoradoOscuro,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── PEDIDO ─────────────────────────────────────────
            const Text('Pedido a reembolsar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2)),
              ),
              child: pedidos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(LucideIcons.info,
                            color: AppColors.textSecondary.withValues(alpha: 0.5), size: 18),
                        const SizedBox(width: 10),
                        const Text('No tienes pedidos completados',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<Order>(
                        isExpanded: true,
                        // Sin elegir, va el primero (antes solo se mostraba
                        // como pista y el envío pedía elegirlo).
                        value: _vm.pedidoSeleccionado,
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Icon(
                              LucideIcons.chevronDown,
                              color: AppColors.pierVerde),
                        ),
                        items: pedidos
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      '#${p.numero} — \$${p.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: _vm.seleccionarPedido,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // ── MOTIVO ─────────────────────────────────────────
            const Text('Motivo',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16)),
                  initialValue: _vm.motivo,
                  hint: Text('Selecciona un motivo',
                      style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14)),
                  icon: Icon(LucideIcons.chevronDown,
                      color: AppColors.pierVerde),
                  items: RefundsViewModel.motivos
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary))))
                      .toList(),
                  onChanged: _vm.seleccionarMotivo,
                  validator: (val) =>
                      val == null ? 'Selecciona un motivo' : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── DESCRIPCIÓN ────────────────────────────────────
            const Text('Descripción',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe el problema con detalle...',
                hintStyle:
                    TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.2))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.pierVerde, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.error)),
                contentPadding: const EdgeInsets.all(14),
              ),
              validator: (val) =>
                  (val == null || val.trim().length < 10)
                      ? 'Mínimo 10 caracteres'
                      : null,
            ),
            const SizedBox(height: 32),

            // ── BOTÓN ENVIAR ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (_vm.enviando || pedidos.isEmpty)
                    ? null
                    : _enviarSolicitud,
                icon: _vm.enviando
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.send,
                        color: Colors.white, size: 18),
                label: Text(
                    _vm.enviando ? 'Enviando...' : 'Enviar Solicitud',
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

  // ── EMPTY STATE ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.receiptText,
                  size: 52,
                  color: AppColors.pierVerde.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 24),
            const Text('Sin solicitudes',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Aún no tienes solicitudes. Si tuviste un problema con un pedido, puedes crear una aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime? dt) {
    if (dt == null) return '';
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}, ${dt.year}';
  }
}
