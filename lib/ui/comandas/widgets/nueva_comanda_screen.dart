// lib/ui/comandas/widgets/nueva_comanda_screen.dart
//
// «Nueva comanda» (#130): empleado, gerencia y dirección capturan una
// comanda desde el teléfono, con las secciones de la web (cliente, entrega,
// productos, fotos de referencia, cobro y notas). Al guardar abre la
// comanda creada con su folio; si el backend la rechaza, el recuadro de
// arriba del botón dice qué corregir sin perder lo capturado. Las piezas
// están en nueva_comanda_partes.dart; el estado, en NuevaComandaViewModel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';
import 'package:pier_reposteria/ui/comandas/view_model/nueva_comanda_view_model.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_screen.dart';
import 'package:pier_reposteria/ui/comandas/widgets/nueva_comanda_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/utils/moneda.dart';
import 'package:provider/provider.dart';

class NuevaComandaScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const NuevaComandaScreen({super.key, this.viewModel});

  final NuevaComandaViewModel? viewModel;

  @override
  State<NuevaComandaScreen> createState() => _NuevaComandaScreenState();
}

class _NuevaComandaScreenState extends State<NuevaComandaScreen> {
  late final NuevaComandaViewModel _vm =
      widget.viewModel ?? NuevaComandaViewModel(repo: context.read());
  final _picker = ImagePicker();
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_revisarSesion);
    if (_vm.catalogo == null) unawaited(_vm.cargar());
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_revisarSesion)
      ..dispose();
    super.dispose();
  }

  void _revisarSesion() {
    if (!_vm.sesionInvalida || _saliendo) return;
    _saliendo = true;
    unawaited(salirDeComandas(context, mensaje: _vm.errorCarga ??
        (_vm.errores.isEmpty ? null : _vm.errores.first)));
  }

  Future<void> _foto(ImageSource fuente) async {
    try {
      final img = await _picker.pickImage(
        source: fuente,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (img != null) await _vm.agregarFoto(img.path);
    } on Exception {
      if (mounted) avisoComandas(context, 'No se pudo acceder a la imagen');
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = _vm.hoy;
    final elegida = await showDatePicker(
      context: context,
      initialDate: _vm.fecha ?? hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: NuevaComandaViewModel.maxDias)),
      helpText: 'Fecha de entrega',
    );
    if (elegida != null) _vm.editar(() => _vm.fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final partes = _vm.hora?.split(':');
    final elegida = await showTimePicker(
      context: context,
      initialTime: partes == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
      helpText: 'Hora de entrega',
    );
    if (elegida == null) return;
    String dos(int n) => n.toString().padLeft(2, '0');
    _vm.editar(() => _vm.hora = '${dos(elegida.hour)}:${dos(elegida.minute)}');
  }

  Future<void> _elegirProducto() async {
    final productos = _vm.catalogo?.productos ?? const <ProductoCatalogo>[];
    final elegido = await showModalBottomSheet<ProductoCatalogo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Producto del catálogo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final p in productos)
              ListTile(
                title: Text(p.nombre),
                subtitle: Text([
                  ?p.categoria,
                  'Chico ${moneda(p.precioChico / 100)}',
                  if (p.precioGrande case final g?) 'Grande ${moneda(g / 100)}',
                ].join(' · ')),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (elegido != null) _vm.agregarProducto(elegido);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final creada = await _vm.guardar();
    if (creada == null || !mounted) return;
    final avisos = ScaffoldMessenger.of(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DetalleComandaScreen(id: creada.id),
      ),
    );
    avisos.showSnackBar(SnackBar(
      content: Text([creada.mensaje, ...creada.advertencias].join('\n')),
      backgroundColor: creada.advertencias.isEmpty
          ? AppColors.pierVerde
          : AppColors.aviso,
      behavior: SnackBarBehavior.floating,
    ));
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
        title: const Text('Nueva comanda'),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _cuerpo(),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => _vm.catalogo == null
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _vm.guardando ? null : _guardar,
                    icon: _vm.guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(LucideIcons.check, size: 18),
                    label: Text(_vm.guardando
                        ? 'Guardando…'
                        : 'Guardar · ${moneda(_vm.total / 100)}'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_vm.catalogo == null) {
      final error = _vm.errorCarga;
      if (error == null) {
        return const Center(child: CircularProgressIndicator());
      }
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
    final advertencia = _vm.advertencia;
    final productos = _vm.catalogo?.productos ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SeccionComanda(
          titulo: 'Cliente',
          icono: LucideIcons.user,
          children: [
            TextFormField(
              initialValue: _vm.nombre,
              textCapitalization: TextCapitalization.words,
              decoration: campoComanda('Nombre del cliente'),
              onChanged: (v) => _vm.editar(() => _vm.nombre = v),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _vm.telefono,
              keyboardType: TextInputType.phone,
              decoration: campoComanda('Teléfono (10 dígitos)'),
              onChanged: (v) => _vm.editar(() => _vm.telefono = v),
            ),
          ],
        ),
        SeccionComanda(
          titulo: 'Entrega',
          icono: LucideIcons.calendar,
          children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(LucideIcons.calendar, size: 18),
                  label: Text(_vm.fecha == null
                      ? 'Fecha'
                      : _fechaCorta(_vm.fecha!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirHora,
                  icon: const Icon(LucideIcons.clock, size: 18),
                  label: Text(_vm.hora ?? 'Hora'),
                ),
              ),
            ]),
            if (advertencia != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(advertencia,
                    style: TextStyle(fontSize: 13, color: AppColors.aviso)),
              ),
          ],
        ),
        SeccionComanda(
          titulo: 'Productos',
          icono: LucideIcons.cake,
          children: [
            for (final r in _vm.renglones)
              switch (r) {
                PastelBorrador() =>
                  TarjetaPastel(key: ValueKey(r.clave), vm: _vm, pastel: r),
                ProductoBorrador() => TarjetaProducto(
                    key: ValueKey(r.clave), vm: _vm, producto: r),
              },
            OutlinedButton.icon(
              onPressed: _vm.puedeAgregar ? _vm.agregarPastel : null,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Agregar pastel personalizado'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  _vm.puedeAgregar && productos.isNotEmpty ? _elegirProducto : null,
              icon: const Icon(LucideIcons.packagePlus, size: 18),
              label: const Text('Agregar producto del catálogo'),
            ),
            if (!_vm.puedeAgregar)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Llegaste al máximo de 30 renglones por comanda.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
          ],
        ),
        SeccionComanda(
          titulo: 'Imágenes de referencia',
          icono: LucideIcons.camera,
          children: [
            FotosComanda(
              vm: _vm,
              alTomar: () => unawaited(_foto(ImageSource.camera)),
              alElegir: () => unawaited(_foto(ImageSource.gallery)),
            ),
          ],
        ),
        SeccionComanda(
          titulo: 'Cobro',
          icono: LucideIcons.wallet,
          children: [CobroComanda(vm: _vm)],
        ),
        SeccionComanda(
          titulo: 'Notas',
          icono: LucideIcons.stickyNote,
          children: [
            TextFormField(
              initialValue: _vm.notas,
              maxLines: 4,
              minLines: 2,
              maxLength: 1000,
              decoration: campoComanda('Notas para producción (opcional)'),
              onChanged: (v) => _vm.editar(() => _vm.notas = v),
            ),
          ],
        ),
        if (_vm.errores.isNotEmpty) ErroresComanda(_vm.errores),
      ],
    );
  }

  static const _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// «14 Nov 2026».
  static String _fechaCorta(DateTime f) =>
      '${f.day} ${_meses[f.month - 1]} ${f.year}';
}
