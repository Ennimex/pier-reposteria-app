// lib/ui/pedidos_personal/widgets/pedidos_del_dia_screen.dart
//
// «Pedidos del día» (#137): empleado, gerencia y dirección gestionan los
// pedidos de la sucursal desde el teléfono. Secciones por lo que falta hacer
// (por confirmar, por preparar, listos para recoger o enviar, en reparto y
// entregas fallidas), la hora comprometida (hoy o vencida) y los botones de
// cada estado con los textos y confirmaciones de la web. Se actualiza al
// jalar hacia abajo, al volver a la app y después de cada acción. Los
// diálogos están en pedidos_del_dia_dialogos.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/pedidos_personal/view_model/pedidos_del_dia_view_model.dart';
import 'package:pier_reposteria/ui/pedidos_personal/widgets/pedidos_del_dia_dialogos.dart';
import 'package:pier_reposteria/utils/moneda.dart';
import 'package:provider/provider.dart';

class PedidosDelDiaScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const PedidosDelDiaScreen({super.key, this.viewModel});

  final PedidosDelDiaViewModel? viewModel;

  @override
  State<PedidosDelDiaScreen> createState() => _PedidosDelDiaScreenState();
}

class _PedidosDelDiaScreenState extends State<PedidosDelDiaScreen>
    with WidgetsBindingObserver {
  late final PedidosDelDiaViewModel _vm =
      widget.viewModel ?? PedidosDelDiaViewModel(repo: context.read());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_vm.cargar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_vm.refrescar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.dispose();
    super.dispose();
  }

  void _avisar(ResultadoAccion r) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(r.mensaje),
        backgroundColor: r.ok ? AppColors.pierVerde : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _hacer(AccionPedido accion, PedidoDelDia p) async {
    final correr = await _preguntar(accion, p);
    if (correr != null) _avisar(await correr());
  }

  /// Pide lo que la acción necesita (confirmación, motivo o repartidor) y
  /// la devuelve lista para correr; null si la persona se arrepintió.
  Future<Future<ResultadoAccion> Function()?> _preguntar(
    AccionPedido accion,
    PedidoDelDia p,
  ) async {
    switch (accion) {
      case AccionPedido.aprobar:
        return () => _vm.aprobar(p);
      case AccionPedido.avisarDemora:
        return () => _vm.avisarDemora(p);
      case AccionPedido.marcarListo:
        final si = await confirmarAccion(context, ConfirmacionPedido.listo(p));
        return si ? () => _vm.marcarListo(p) : null;
      case AccionPedido.entregar:
        final si = await confirmarAccion(context, ConfirmacionPedido.entregar);
        return si ? () => _vm.entregar(p) : null;
      case AccionPedido.volverAEnviar:
        final si =
            await confirmarAccion(context, ConfirmacionPedido.volverAEnviar);
        return si ? () => _vm.volverAEnviar(p) : null;
      case AccionPedido.cancelar:
        final motivo =
            await pedirMotivo(context, MotivoPedido.cancelar(p.numero));
        return motivo == null ? null : () => _vm.cancelar(p, motivo);
      case AccionPedido.rechazar:
        final motivo =
            await pedirMotivo(context, MotivoPedido.rechazar(p.numero));
        return motivo == null ? null : () => _vm.rechazar(p, motivo);
      case AccionPedido.asignar:
        final id = await elegirRepartidor(context, _vm.repartidores);
        return id == null ? null : () => _vm.asignar(p, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      appBar: AppBar(
        backgroundColor: AppColors.pierVerde,
        foregroundColor: Colors.white,
        title: const Text('Pedidos del día'),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_vm.cargando) return const Center(child: CircularProgressIndicator());
    final error = _vm.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _vm.cargar,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Reintentar'),
            ),
          ]),
        ),
      );
    }
    final grupos = _vm.grupos;
    final otros = _vm.deOtrosDias;
    return RefreshIndicator(
      color: AppColors.pierVerde,
      onRefresh: () async {
        final motivo = await _vm.refrescar();
        if (motivo != null) _avisar((mensaje: motivo, ok: false));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('Hoy y vencidos'),
              selected: _vm.soloHoy,
              onSelected: (_) => _vm.verSoloHoy(valor: true),
            ),
            ChoiceChip(
              label: const Text('Todos los abiertos'),
              selected: !_vm.soloHoy,
              onSelected: (_) => _vm.verSoloHoy(valor: false),
            ),
          ]),
          if (otros > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  otros == 1
                      ? '1 pedido de otro día no se muestra'
                      : '$otros pedidos de otros días no se muestran',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          if (grupos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Column(children: [
                Icon(LucideIcons.circleCheck,
                    size: 48, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('No hay pedidos pendientes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ]),
            ),
          for (final (grupo, pedidos) in grupos) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text('${grupo.titulo} (${pedidos.length})',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            for (final p in pedidos)
              _TarjetaPedido(
                key: ValueKey(p.id),
                pedido: p,
                cuando: _vm.cuando(p),
                vencido: _vm.vencido(p),
                acciones: _vm.acciones(p),
                ocupado: _vm.ocupado(p),
                alHacer: (a) => unawaited(_hacer(a, p)),
              ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({
    required this.pedido,
    required this.cuando,
    required this.vencido,
    required this.acciones,
    required this.ocupado,
    required this.alHacer,
    super.key,
  });

  final PedidoDelDia pedido;
  final String? cuando;
  final bool vencido;
  final List<AccionPedido> acciones;
  final bool ocupado;
  final void Function(AccionPedido) alHacer;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final hora = cuando;
    final principales =
        acciones.where((a) => a != AccionPedido.cancelar).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: vencido
            ? Border.all(color: AppColors.error.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(p.numero,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ),
            Text(moneda(p.total),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.pierVerde)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _Etiqueta(
              icono: p.esDomicilio ? LucideIcons.truck : LucideIcons.store,
              texto: p.esDomicilio ? 'A domicilio' : 'Recoger',
              color: AppColors.pierVerde,
            ),
            if (hora != null)
              _Etiqueta(
                icono: LucideIcons.clock,
                texto: hora,
                color: vencido ? AppColors.error : AppColors.pierDoradoOscuro,
              ),
          ]),
          const SizedBox(height: 8),
          Text(
              [p.cliente, ?p.telefono].where((t) => t.isNotEmpty).join(' · '),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
          for (final linea in p.productos.take(3))
            Text(linea,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          if (p.productos.length > 3)
            Text('y ${p.productos.length - 3} más',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          if (p.esDomicilio && p.direccion != null)
            Text(p.direccion!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          if (p.repartidor case final r?)
            Text('Repartidor: $r',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          if (p.notas case final n?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Notas: $n',
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 10),
          if (ocupado)
            const LinearProgressIndicator()
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < principales.length; i++)
                if (i == 0)
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pierVerde),
                    onPressed: () => alHacer(principales[i]),
                    child: Text(principales[i].etiqueta),
                  )
                else
                  OutlinedButton(
                    onPressed: () => alHacer(principales[i]),
                    child: Text(principales[i].etiqueta),
                  ),
              if (acciones.contains(AccionPedido.cancelar))
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  onPressed: () => alHacer(AccionPedido.cancelar),
                  child: Text(AccionPedido.cancelar.etiqueta),
                ),
            ]),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.texto,
    required this.color,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}
