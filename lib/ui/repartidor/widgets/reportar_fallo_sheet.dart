// lib/ui/repartidor/widgets/reportar_fallo_sheet.dart
//
// Hoja para reportar una entrega fallida. Marca la entrega como "fallida" con
// un motivo obligatorio. Devuelve true por Navigator.pop si tuvo éxito.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';

class ReportarFalloSheet extends StatefulWidget {
  final EntregaRepartidor entrega;
  const ReportarFalloSheet({super.key, required this.entrega});

  @override
  State<ReportarFalloSheet> createState() => _ReportarFalloSheetState();
}

class _ReportarFalloSheetState extends State<ReportarFalloSheet> {
  static const _motivos = [
    'Cliente ausente',
    'Dirección incorrecta',
    'No contestó',
    'Otro',
  ];

  String? _motivoSel;
  final _detalleController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _reportar() async {
    final detalle = _detalleController.text.trim();
    if (detalle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe brevemente el motivo del fallo'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // El motivo enviado combina la categoría elegida (si hay) con el detalle.
    final motivo = _motivoSel != null && _motivoSel != 'Otro'
        ? '$_motivoSel: $detalle'
        : detalle;

    setState(() => _enviando = true);
    final res = await context.read<EntregasProvider>().cambiarEstado(
          widget.entrega.id,
          EstadoEntrega.fallida,
          motivoFallo: motivo,
        );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'No se pudo reportar'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reportar entrega fallida',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona el motivo',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _motivos.map((m) {
              final sel = _motivoSel == m;
              return GestureDetector(
                onTap: () => setState(() => _motivoSel = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(50),
                    border: sel
                        ? Border.all(color: AppColors.textPrimary, width: 2)
                        : null,
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Motivo del fallo (Requerido)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _detalleController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Describe brevemente lo ocurrido…',
              fillColor: AppColors.pierArena,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info,
                    size: 20, color: AppColors.error.withValues(alpha: 0.9)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta acción marcará el pedido como no entregado y notificará al cliente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _reportar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.triangleAlert, size: 18),
              label: Text(_enviando ? 'Reportando…' : 'Reportar fallo'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _enviando ? null : () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: AppColors.pierVerde,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
