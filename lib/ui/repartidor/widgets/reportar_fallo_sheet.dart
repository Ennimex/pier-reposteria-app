// lib/ui/repartidor/widgets/reportar_fallo_sheet.dart
//
// Hoja para reportar una entrega fallida (MVVM, Fase 5). Marca la entrega
// como «fallida» con un motivo obligatorio y se cierra con true si tuvo
// éxito. El estado vive en ReportarFalloViewModel.
//
// Movimiento: el contenido se arma en cascada mientras la hoja sube; los
// motivos se hunden al tocarlos y cambian de color sin cambiar de tamaño;
// el campo del detalle se sacude si falta.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/reportar_fallo_view_model.dart';
import 'package:pier_pasteleria/ui/repartidor/widgets/repartidor_ui.dart';
import 'package:provider/provider.dart';

class ReportarFalloSheet extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la hoja crea el suyo
  /// con [entrega].
  const ReportarFalloSheet({
    required this.entrega,
    super.key,
    this.alCambiar,
    this.viewModel,
  });

  final EntregaRepartidor entrega;

  /// Se llama (y se espera) al reportar, para que el panel se ponga al día.
  final Future<void> Function()? alCambiar;
  final ReportarFalloViewModel? viewModel;

  @override
  State<ReportarFalloSheet> createState() => _ReportarFalloSheetState();
}

class _ReportarFalloSheetState extends State<ReportarFalloSheet> {
  late final ReportarFalloViewModel _vm = widget.viewModel ??
      ReportarFalloViewModel(
        repo: context.read(),
        entrega: widget.entrega,
        alCambiar: widget.alCambiar,
      );
  final _detalleController = TextEditingController();

  // Veces que se intentó reportar sin detalle: cada una sacude el campo (el
  // aviso de siempre explica qué falta).
  int _faltas = 0;

  @override
  void dispose() {
    _detalleController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _reportar() async {
    final r = await _vm.reportar(_detalleController.text);
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, true);
    } else {
      mostrarAviso(context, r.mensaje);
      if (r.mensaje == ReportarFalloViewModel.faltaDetalle) {
        setState(() => _faltas++);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _contenido(),
      ),
    );
  }

  /// Un bloque de la cascada: entra cuando la hoja ya va subiendo.
  static Widget _paso(int orden, Widget hijo) => EntradaSuave(
        orden: orden,
        retraso: AppMovimiento.trasEmpuje,
        child: hijo,
      );

  Widget _contenido() {
    final enviando = _vm.enviando;
    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.textSecondary.withValues(alpha: 0.2),
      ),
    );
    return Column(
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
        _paso(
          0,
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
                icon:
                    const Icon(LucideIcons.x, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _paso(
          1,
          Text(
            'Selecciona el motivo',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _paso(
          2,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in ReportarFalloViewModel.motivos)
                _ChipMotivo(
                  texto: m,
                  elegido: _vm.motivo == m,
                  onTap: () => _vm.elegirMotivo(m),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _paso(
          3,
          // Se sacude si falta el detalle.
          Sacudida(
            disparo: _faltas == 0 ? null : _faltas,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    border: bordeCampo,
                    enabledBorder: bordeCampo,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _paso(
          4,
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
        ),
        const SizedBox(height: 20),
        _paso(
          5,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: enviando ? null : _reportar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  icon: IconoCargando(
                    icono: LucideIcons.triangleAlert,
                    cargando: enviando,
                    color: Colors.white,
                  ),
                  label: Text(enviando ? 'Reportando…' : 'Reportar fallo'),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(context),
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
        ),
      ],
    );
  }
}

/// Categoría del fallo; la elegida va con borde. El borde siempre ocupa su
/// lugar (transparente si no está elegida): elegir no cambia el tamaño del
/// chip ni reacomoda la fila; el color y el borde pasan con un fundido.
class _ChipMotivo extends StatelessWidget {
  const _ChipMotivo({
    required this.texto,
    required this.elegido,
    required this.onTap,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PresionEscala(
      escala: AppMovimiento.escalaPresionChica,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMovimiento.duracion(context, AppMovimiento.corta),
          curve: AppMovimiento.curvaEstandar,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: elegido
                ? AppColors.error
                : AppColors.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: elegido
                  ? AppColors.textPrimary
                  : AppColors.textPrimary.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
