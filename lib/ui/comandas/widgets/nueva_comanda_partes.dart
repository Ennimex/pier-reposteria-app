// lib/ui/comandas/widgets/nueva_comanda_partes.dart
//
// Piezas de «Nueva comanda» (#130), una por sección como el formulario de la
// web: el marco de cada sección, la tarjeta de un pastel, la de un producto
// del catálogo, las fotos de referencia y el cobro. Cada pieza recibe el
// ViewModel y cambia lo capturado con `editar`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/nueva_comanda.dart';
import 'package:pier_reposteria/ui/comandas/view_model/nueva_comanda_view_model.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/utils/moneda.dart';

/// Tarjeta blanca con el título de la sección.
class SeccionComanda extends StatelessWidget {
  const SeccionComanda({
    required this.titulo,
    required this.icono,
    required this.children,
    super.key,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icono, size: 18, color: AppColors.pierVerde),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Decoración de los campos del formulario.
InputDecoration campoComanda(String etiqueta, {String? ayuda, String? prefijo}) =>
    InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      prefixText: prefijo,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

/// Un pastel personalizado: sabor, tamaño, forma, decoración, pisos,
/// cantidad, precio, leyenda y descripción.
class TarjetaPastel extends StatelessWidget {
  const TarjetaPastel({required this.vm, required this.pastel, super.key});

  final NuevaComandaViewModel vm;
  final PastelBorrador pastel;

  @override
  Widget build(BuildContext context) {
    final o = vm.catalogo?.opciones ?? const OpcionesPastel();
    Widget lista(String etiqueta, String valor, List<String> opciones,
            void Function(String) cambiar) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            initialValue: opciones.contains(valor) ? valor : null,
            isExpanded: true,
            decoration: campoComanda(etiqueta),
            items: [
              for (final o in opciones)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: (v) => vm.editar(() => cambiar(v ?? '')),
          ),
        );
    return _MarcoRenglon(
      titulo: 'Pastel ${vm.numeroDePastel(pastel)}',
      importe: vm.importe(pastel),
      alQuitar: () => vm.quitar(pastel),
      children: [
        lista('Sabor', pastel.sabor, o.sabores, (v) => pastel.sabor = v),
        lista('Tamaño', pastel.tamano, o.tamanos, (v) => pastel.tamano = v),
        lista('Forma', pastel.forma, o.formas, (v) => pastel.forma = v),
        lista('Decoración', pastel.decoracion, o.decoraciones,
            (v) => pastel.decoracion = v),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: pastel.pisos,
              decoration: campoComanda('Pisos'),
              items: [
                for (var i = 1; i <= 6; i++)
                  DropdownMenuItem(value: i, child: Text('$i')),
              ],
              onChanged: (v) => vm.editar(() => pastel.pisos = v ?? 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: pastel.cantidad,
              keyboardType: TextInputType.number,
              decoration: campoComanda('Cantidad'),
              onChanged: (v) => vm.editar(() => pastel.cantidad = v),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: pastel.precio,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: campoComanda('Precio por pastel', prefijo: r'$ '),
          onChanged: (v) => vm.editar(() => pastel.precio = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: pastel.leyenda,
          maxLength: 200,
          decoration: campoComanda('Leyenda (opcional)'),
          onChanged: (v) => vm.editar(() => pastel.leyenda = v),
        ),
        TextFormField(
          initialValue: pastel.descripcion,
          maxLines: 3,
          minLines: 1,
          decoration: campoComanda('Descripción (opcional)'),
          onChanged: (v) => vm.editar(() => pastel.descripcion = v),
        ),
      ],
    );
  }
}

/// Un producto del catálogo: tamaño chico o grande, cantidad y su precio.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({required this.vm, required this.producto, super.key});

  final NuevaComandaViewModel vm;
  final ProductoBorrador producto;

  @override
  Widget build(BuildContext context) {
    final p = producto.producto;
    final grande = p.precioGrande;
    return _MarcoRenglon(
      titulo: p.nombre,
      importe: vm.importe(producto),
      alQuitar: () => vm.quitar(producto),
      children: [
        // Chips en un Wrap: en pantallas angostas bajan a otro renglón.
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: Text('Chico · ${moneda(p.precioChico / 100)}'),
            // Como en la agenda: con el verde lleno del tema el texto
            // seleccionado no se veía (Samsung, 28-oct).
            selectedColor: AppColors.pierVerde.withValues(alpha: 0.18),
            selected: !producto.grande,
            onSelected: (_) => vm.editar(() => producto.grande = false),
          ),
          ChoiceChip(
            label: Text(grande == null
                ? 'Sin grande'
                : 'Grande · ${moneda(grande / 100)}'),
            selectedColor: AppColors.pierVerde.withValues(alpha: 0.18),
            selected: producto.grande,
            onSelected: grande == null
                ? null
                : (_) => vm.editar(() => producto.grande = true),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: producto.cantidad,
          keyboardType: TextInputType.number,
          decoration: campoComanda('Cantidad'),
          onChanged: (v) => vm.editar(() => producto.cantidad = v),
        ),
      ],
    );
  }
}

class _MarcoRenglon extends StatelessWidget {
  const _MarcoRenglon({
    required this.titulo,
    required this.importe,
    required this.alQuitar,
    required this.children,
  });

  final String titulo;

  /// En centavos.
  final int importe;
  final VoidCallback alQuitar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.pierArenaOscuro),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            Text(moneda(importe / 100),
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.pierVerde)),
            IconButton(
              tooltip: 'Quitar $titulo',
              icon: const Icon(LucideIcons.trash2, size: 18),
              color: AppColors.error,
              onPressed: alQuitar,
            ),
          ]),
          ...children,
        ],
      ),
    );
  }
}

/// Las fotos de referencia: miniatura, «subiendo» y, si falló, reintentar.
class FotosComanda extends StatelessWidget {
  const FotosComanda({
    required this.vm,
    required this.alTomar,
    required this.alElegir,
    super.key,
  });

  final NuevaComandaViewModel vm;
  final VoidCallback alTomar;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.fotos.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final f in vm.fotos) _Miniatura(vm: vm, foto: f)],
          ),
        if (vm.fotos.isNotEmpty) const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: vm.puedeAgregarFoto ? alTomar : null,
              icon: const Icon(LucideIcons.camera, size: 18),
              label: const Text('Tomar foto'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: vm.puedeAgregarFoto ? alElegir : null,
              icon: const Icon(LucideIcons.image, size: 18),
              label: const Text('Galería'),
            ),
          ),
        ]),
        if (!vm.puedeAgregarFoto)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Máximo ${NuevaComandaViewModel.maxFotos} imágenes',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.vm, required this.foto});

  final NuevaComandaViewModel vm;
  final FotoBorrador foto;

  static const double _lado = 88;

  @override
  Widget build(BuildContext context) {
    final capa = switch (foto.estado) {
      EstadoFoto.subiendo => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      EstadoFoto.fallo => Center(
          child: IconButton.filled(
            tooltip: 'Reintentar foto',
            style: IconButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            onPressed: () => vm.reintentarFoto(foto),
          ),
        ),
      EstadoFoto.lista => null,
    };
    return SizedBox(
      width: _lado,
      height: _lado,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(foto.ruta),
            fit: BoxFit.cover,
            cacheWidth: 264,
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.pierArenaOscuro,
              child: const Icon(LucideIcons.image, color: Colors.white),
            ),
          ),
        ),
        if (capa != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: capa,
          ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton(
            tooltip: 'Quitar foto',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.circleX, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => vm.quitarFoto(foto),
          ),
        ),
      ]),
    );
  }
}

/// Subtotal, descuento, total, anticipo (con su mínimo) y saldo.
class CobroComanda extends StatelessWidget {
  const CobroComanda({required this.vm, super.key});

  final NuevaComandaViewModel vm;

  @override
  Widget build(BuildContext context) {
    Widget fila(String etiqueta, int centavos, {bool fuerte = false}) {
      final estilo = TextStyle(
        fontSize: fuerte ? 16 : 14,
        fontWeight: fuerte ? FontWeight.bold : FontWeight.w500,
        color: AppColors.textPrimary,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(moneda(centavos / 100), style: estilo),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fila('Subtotal', vm.subtotal),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: vm.descuento,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: campoComanda('Descuento (opcional)', prefijo: r'$ '),
          onChanged: (v) => vm.editar(() => vm.descuento = v),
        ),
        const SizedBox(height: 4),
        fila('Total', vm.total, fuerte: true),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: vm.anticipo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: campoComanda('Anticipo',
              ayuda: vm.textoMinimo, prefijo: r'$ '),
          onChanged: (v) => vm.editar(() => vm.anticipo = v),
        ),
        const SizedBox(height: 4),
        fila('Saldo al entregar', vm.saldo),
      ],
    );
  }
}

/// Lo que hay que corregir antes de guardar, en un recuadro.
class ErroresComanda extends StatelessWidget {
  const ErroresComanda(this.errores, {super.key});

  final List<String> errores;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revisa lo siguiente:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.error)),
          const SizedBox(height: 6),
          for (final e in errores)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $e',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary)),
            ),
        ],
      ),
    );
  }
}
