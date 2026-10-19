// lib/ui/comandas/widgets/comandas_acciones.dart
//
// Acciones de quien cobra sobre una comanda (#129): barra con «Entregar» y
// «Cancelar comanda», diálogo del saldo cobrado (sugiere el saldo pendiente
// y avisa si producción no ha confirmado) y diálogo del motivo de
// cancelación (5 a 300 caracteres), con los textos de la web.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/comanda.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/utils/moneda.dart';

const _motivoMinimo = 5;
const _motivoMaximo = 300;

/// 0 o más, con hasta dos decimales.
final _montoValido = RegExp(r'^\d+(\.\d{1,2})?$');

/// Barra inferior de quien cobra: «Entregar» y, si puede, «Cancelar comanda».
class BarraAcciones extends StatelessWidget {
  const BarraAcciones({
    required this.corriendo,
    this.alEntregar,
    this.alCancelar,
    super.key,
  });

  final bool corriendo;
  final VoidCallback? alEntregar;
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            if (alCancelar != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: corriendo ? null : alCancelar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Cancelar comanda'),
                ),
              ),
            if (alCancelar != null && alEntregar != null)
              const SizedBox(width: 12),
            if (alEntregar != null)
              Expanded(
                child: FilledButton(
                  onPressed: corriendo ? null : alEntregar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Entregar'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Pide el saldo cobrado al entregar [comanda]; null si eligió «Volver».
Future<double?> pedirSaldoCobrado(
  BuildContext context,
  DetalleComanda comanda,
) => showDialog<double>(
  context: context,
  builder: (_) => _DialogoEntregar(comanda),
);

/// Pide el motivo para cancelar la comanda [folio]; null si eligió
/// «Volver».
Future<String?> pedirMotivoCancelacion(BuildContext context, int folio) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DialogoCancelar(folio),
    );

class _DialogoEntregar extends StatefulWidget {
  const _DialogoEntregar(this.comanda);

  final DetalleComanda comanda;

  @override
  State<_DialogoEntregar> createState() => _DialogoEntregarState();
}

class _DialogoEntregarState extends State<_DialogoEntregar> {
  late final _campo = TextEditingController(
    text: (widget.comanda.saldo ?? 0).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  double? get _monto {
    final texto = _campo.text.trim();
    return _montoValido.hasMatch(texto) ? double.parse(texto) : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comanda;
    final pendiente = c.saldo ?? 0;
    final monto = _monto;
    final faltan = c.areasSinConfirmar;
    final ayuda = monto == null
        ? 'Escribe una cantidad válida: 0 o más, con hasta dos decimales.'
        : monto != pendiente
        ? 'Es distinto del saldo pendiente (${moneda(pendiente)}). '
              'Revisa que sea correcto.'
        : 'Si no se cobró nada, escribe 0.';
    return AlertDialog(
      title: Text('Marcar entregada la comanda #${c.folio}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registra cuánto se cobró al entregar. El saldo pendiente '
              'es ${moneda(pendiente)} (total ${moneda(c.total ?? 0)} '
              'menos anticipo ${moneda(c.anticipo ?? 0)}).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _campo,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Saldo cobrado',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ayuda,
              style: TextStyle(
                fontSize: 12,
                color: monto == null
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
            if (faltan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Producción aún no confirma la versión actual: '
                  '${faltan.length > 1 ? 'faltan' : 'falta'} '
                  '${faltan.map((a) => a.etiqueta).join(' y ')}. '
                  'Puedes entregarla de todos modos.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: monto == null ? null : () => Navigator.pop(context, monto),
          style: FilledButton.styleFrom(backgroundColor: AppColors.pierVerde),
          child: const Text('Marcar entregada'),
        ),
      ],
    );
  }
}

class _DialogoCancelar extends StatefulWidget {
  const _DialogoCancelar(this.folio);

  final int folio;

  @override
  State<_DialogoCancelar> createState() => _DialogoCancelarState();
}

class _DialogoCancelarState extends State<_DialogoCancelar> {
  final _campo = TextEditingController();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _campo.text.trim();
    final valido = motivo.length >= _motivoMinimo;
    return AlertDialog(
      icon: const Icon(LucideIcons.ban, color: AppColors.error),
      title: Text('Cancelar la comanda #${widget.folio}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Producción recibirá el aviso. Esta acción no se puede '
            'deshacer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            autofocus: true,
            maxLength: _motivoMaximo,
            maxLines: 3,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Motivo',
              helperText: 'Entre $_motivoMinimo y $_motivoMaximo caracteres.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: valido ? () => Navigator.pop(context, motivo) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Sí, cancelar'),
        ),
      ],
    );
  }
}
