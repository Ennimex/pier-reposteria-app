// lib/ui/feed/widgets/comentarios_sheet.dart
//
// Hoja de comentarios de una publicación (#133): los comentarios visibles
// (la respuesta de Pier resaltada), «Ver más comentarios», comentar (hasta
// 1000 caracteres; el aviso del backend si se comenta de más) y borrar los
// propios con confirmación. Al cerrarse, el inicio actualiza su contador o
// quita la publicación si ya no está.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/feed/view_model/comentarios_view_model.dart';
import 'package:pier_reposteria/ui/feed/view_model/feed_view_model.dart';
import 'package:pier_reposteria/ui/feed/widgets/tarjeta_publicacion.dart';
import 'package:provider/provider.dart';

const _maxComentario = 1000;

/// Abre la hoja de comentarios de [publicacionId] y, al cerrarla, refleja
/// en [feed] lo que se comentó o borró.
Future<void> abrirComentarios(
  BuildContext context, {
  required int publicacionId,
  required FeedViewModel feed,
}) async {
  final vm = ComentariosViewModel(
    repo: context.read(),
    publicacionId: publicacionId,
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ComentariosSheet(viewModel: vm),
  );
  if (vm.noDisponible) {
    feed.quitarPublicacion(publicacionId);
  } else {
    feed.aplicarComentarios(
      publicacionId,
      nuevos: vm.nuevos,
      borrados: vm.borrados,
    );
  }
  vm.dispose();
}

class ComentariosSheet extends StatefulWidget {
  const ComentariosSheet({required this.viewModel, super.key});

  final ComentariosViewModel viewModel;

  @override
  State<ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<ComentariosSheet> {
  final _texto = TextEditingController();
  String? _aviso;

  ComentariosViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.publicar.addListener(_alPublicar);
    _vm.borrar.addListener(_alBorrar);
    unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm.publicar.removeListener(_alPublicar);
    _vm.borrar.removeListener(_alBorrar);
    _texto.dispose();
    super.dispose();
  }

  void _alPublicar() {
    final c = _vm.publicar;
    if (c.corriendo) return;
    if (c.resultado != null) {
      _texto.clear();
      setState(() => _aviso = null);
    } else if (c.error case final ApiException e) {
      setState(() => _aviso = e.message);
    }
  }

  void _alBorrar() {
    final c = _vm.borrar;
    if (c.corriendo) return;
    if (c.error case final ApiException e) {
      setState(() => _aviso = e.message);
    }
  }

  Future<void> _confirmarBorrar(int comentarioId) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tu comentario?'),
        content: const Text('Ya no lo verá nadie.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (si ?? false) unawaited(_vm.borrar.execute(comentarioId));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ListenableBuilder(
        listenable: Listenable.merge([_vm, _vm.publicar, _texto]),
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comentarios',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _lista()),
            const Divider(height: 1),
            _Escribir(
              texto: _texto,
              aviso: _aviso,
              publicando: _vm.publicar.corriendo,
              habilitado: !_vm.noDisponible,
              alPublicar: () => unawaited(_vm.publicar.execute(_texto.text)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _lista() {
    if (_vm.cargando) return const Center(child: CircularProgressIndicator());
    if (_vm.comentarios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _vm.error ?? 'Sé el primero en comentar',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in _vm.comentarios)
          ComentarioBreve(
            c,
            alBorrar: c.puedeBorrar ? () => _confirmarBorrar(c.id) : null,
          ),
        if (_vm.hayMas)
          Center(
            child: _vm.cargandoMas
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                : TextButton(
                    onPressed: () => unawaited(_vm.cargarMas()),
                    child: const Text('Ver más comentarios'),
                  ),
          ),
      ],
    );
  }
}

/// Campo para comentar con contador y botón «Publicar».
class _Escribir extends StatelessWidget {
  const _Escribir({
    required this.texto,
    required this.aviso,
    required this.publicando,
    required this.habilitado,
    required this.alPublicar,
  });

  final TextEditingController texto;
  final String? aviso;
  final bool publicando;
  final bool habilitado;
  final VoidCallback alPublicar;

  @override
  Widget build(BuildContext context) {
    final vacio = texto.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aviso case final mensaje?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Text(
                mensaje,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: texto,
                  enabled: habilitado,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: _maxComentario,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Publicar',
                onPressed: vacio || publicando || !habilitado
                    ? null
                    : alPublicar,
                icon: publicando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        LucideIcons.sendHorizontal,
                        color: AppColors.pierVerde,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
