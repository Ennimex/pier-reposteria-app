// lib/ui/atencion/widgets/atencion_partes.dart
//
// Piezas que comparten las pestañas de «Atención a clientes» (#138): la
// lista con sus estados (cargando, error con «Reintentar» o vacía) que se
// pone al día al jalar hacia abajo, la tarjeta que se toca, las etiquetas,
// los datos y bloques de texto del detalle, el aviso del resultado de cada
// acción y el diálogo que confirma una acción o pide su texto (mensaje,
// justificación, motivo o respuesta) con su validación.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/ui/atencion/view_model/lista_atencion_view_model.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';

/// Avisa cómo salió una acción: en verde si salió bien; si no, en terracota
/// con el mensaje del backend.
void avisarAtencion(BuildContext context, ResultadoAtencion resultado) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(resultado.mensaje),
        backgroundColor:
            resultado.ok ? AppColors.pierVerde : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// La lista de una pestaña: el indicador mientras carga, el motivo con
/// «Reintentar» si no cargó, o las tarjetas (o el aviso [vacio]) con
/// deslizar hacia abajo para recargar.
class ListaAtencion extends StatelessWidget {
  const ListaAtencion({
    required this.viewModel,
    required this.vacio,
    required this.children,
    super.key,
  });

  final ListaAtencionViewModel<Object?> viewModel;
  final String vacio;
  final List<Widget> children;

  /// Si el backend no respondió, la lista se queda como estaba y se avisa.
  Future<void> _refrescar(BuildContext context) async {
    final motivo = await viewModel.refrescar();
    if (motivo == null || !context.mounted) return;
    avisarAtencion(context, (mensaje: motivo, ok: false));
  }

  @override
  Widget build(BuildContext context) {
    if (viewModel.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = viewModel.error;
    if (error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: viewModel.cargar,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.pierVerde,
      onRefresh: () => _refrescar(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: children.isEmpty ? [_Vacio(vacio)] : children,
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Icon(LucideIcons.inbox, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca de la lista; se toca para ver el detalle ([alTocar]).
/// Con [ocupado], una barra de progreso al pie mientras corre una acción.
class TarjetaAtencion extends StatelessWidget {
  const TarjetaAtencion({
    required this.child,
    super.key,
    this.alTocar,
    this.ocupado = false,
  });

  final VoidCallback? alTocar;
  final bool ocupado;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                if (ocupado) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(color: AppColors.pierVerde),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de color: estado, prioridad o una marca («Compra verificada»).
class EtiquetaAtencion extends StatelessWidget {
  const EtiquetaAtencion(
    this.texto, {
    required this.color,
    super.key,
    this.icono,
  });

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono case final i?) ...[
            Icon(i, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un dato del detalle: su nombre arriba y el valor abajo.
class DatoAtencion extends StatelessWidget {
  const DatoAtencion(this.etiqueta, this.valor, {super.key});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Un texto con su título y una raya de [color] a la izquierda, como la
/// web: el mensaje del cliente, la respuesta de Pier o un rechazo.
class BloqueAtencion extends StatelessWidget {
  const BloqueAtencion({
    required this.titulo,
    required this.texto,
    required this.color,
    super.key,
  });

  final String titulo;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// El campo de texto de un diálogo: su etiqueta, la ayuda, el texto con que
/// abre y cómo se valida ([validar] devuelve null si está bien).
class CampoAtencion {
  const CampoAtencion({
    required this.etiqueta,
    this.ayuda,
    this.inicial = '',
    this.validar,
  });

  final String etiqueta;
  final String? ayuda;
  final String inicial;
  final String? Function(String texto)? validar;
}

/// Lo que dice el diálogo de una acción. Sin [campo] solo confirma.
class PeticionAtencion {
  const PeticionAtencion({
    required this.titulo,
    required this.boton,
    this.subtitulo,
    this.texto,
    this.campo,
    this.peligro = false,
  });

  final String titulo;
  final String boton;
  final String? subtitulo;

  /// Lo que hay que saber antes de confirmar.
  final String? texto;
  final CampoAtencion? campo;

  /// Rechazar: el botón va en terracota.
  final bool peligro;
}

/// El texto escrito, ya validado y sin espacios en las orillas ('' si el
/// diálogo solo confirma), o null si la persona se arrepintió.
Future<String?> pedirAtencion(BuildContext context, PeticionAtencion p) =>
    showDialog<String>(
      context: context,
      animationStyle: AppMovimiento.estiloDialogo(context),
      builder: (_) => EntradaDialogo(child: _DialogoAtencion(p)),
    );

class _DialogoAtencion extends StatefulWidget {
  const _DialogoAtencion(this.p);

  final PeticionAtencion p;

  @override
  State<_DialogoAtencion> createState() => _DialogoAtencionState();
}

class _DialogoAtencionState extends State<_DialogoAtencion> {
  late final TextEditingController _texto;
  String? _error;

  @override
  void initState() {
    super.initState();
    _texto = TextEditingController(text: widget.p.campo?.inicial ?? '');
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _aceptar() {
    final campo = widget.p.campo;
    final texto = _texto.text.trim();
    final error = campo?.validar?.call(texto);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, campo == null ? '' : texto);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final campo = p.campo;
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(p.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.subtitulo case final subtitulo?)
            Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          if (p.texto case final texto?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(texto),
            ),
          if (campo != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _texto,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: campo.etiqueta,
                  helperText: campo.ayuda,
                  helperMaxLines: 3,
                  errorText: _error,
                  errorMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.peligro ? AppColors.error : AppColors.pierVerde,
          ),
          onPressed: _aceptar,
          child: Text(p.boton),
        ),
      ],
    );
  }
}
