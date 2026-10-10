// lib/ui/products/widgets/catalogo_sheets.dart
//
// Hojas inferiores del catálogo: filtros (sabor, tamaño, tipo) y orden. Leen
// y modifican el ProductsViewModel; se repintan solas al cambiarlo.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';

/// Abre la hoja de filtros del catálogo.
Future<void> mostrarFiltrosCatalogo(
    BuildContext context, ProductsViewModel viewModel) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => CatalogoFiltrosSheet(viewModel: viewModel),
  );
}

/// Abre la hoja para elegir el orden del catálogo.
Future<void> mostrarOrdenCatalogo(
    BuildContext context, ProductsViewModel viewModel) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => CatalogoOrdenSheet(viewModel: viewModel),
  );
}

/// Asa gris de arriba de las hojas.
class _Asa extends StatelessWidget {
  const _Asa();

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2)));
  }
}

class CatalogoFiltrosSheet extends StatelessWidget {
  const CatalogoFiltrosSheet({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Asa()),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    if (vm.hayFiltrosDeOpciones)
                      GestureDetector(
                        onTap: vm.limpiarFiltrosDeOpciones,
                        child: Text('Limpiar',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _GrupoFiltro(
                  titulo: 'Sabor',
                  opciones: vm.sabores,
                  seleccionada: vm.filtroSabor,
                  onTap: vm.alternarSabor,
                ),
                _GrupoFiltro(
                  titulo: 'Tamaño',
                  opciones: vm.tamanos,
                  seleccionada: vm.filtroTamano,
                  onTap: vm.alternarTamano,
                ),
                _GrupoFiltro(
                  titulo: 'Tipo',
                  opciones: vm.tipos,
                  seleccionada: vm.filtroTipo,
                  onTap: vm.alternarTipo,
                ),
                if (!vm.filtrosCargados)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.pierVerde),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pierVerde,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Aplicar filtros',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Título y chips de un filtro; no se pinta si no hay opciones. La opción
/// "Todos" que a veces manda el backend se omite (sin filtro = todos).
class _GrupoFiltro extends StatelessWidget {
  const _GrupoFiltro({
    required this.titulo,
    required this.opciones,
    required this.seleccionada,
    required this.onTap,
  });

  final String titulo;
  final List<String> opciones;
  final String? seleccionada;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: opciones
              .where((o) => o != ProductsViewModel.todas)
              .map((o) {
            final sel = seleccionada == o;
            return GestureDetector(
              onTap: () => onTap(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                ),
                child: Text(o,
                    style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class CatalogoOrdenSheet extends StatelessWidget {
  const CatalogoOrdenSheet({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  static const List<(String, SortOption, IconData)> _opciones = [
    ('Más populares',         SortOption.popular,   Icons.star_rounded),
    ('Precio: Menor a Mayor', SortOption.priceAsc,  LucideIcons.trendingUp),
    ('Precio: Mayor a Menor', SortOption.priceDesc, LucideIcons.trendingDown),
    ('Nombre: A–Z',           SortOption.nameAsc,   LucideIcons.arrowDownAZ),
    ('Nombre: Z–A',           SortOption.nameDesc,  LucideIcons.arrowDownAZ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Asa(),
            const SizedBox(height: 20),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Ordenar por',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
            const SizedBox(height: 16),
            ..._opciones.map((t) {
              final sel = viewModel.orden == t.$2;
              return GestureDetector(
                onTap: () {
                  viewModel.ordenarPor(t.$2);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.pierVerde.withValues(alpha: 0.08) : AppColors.textSecondary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: sel ? Border.all(color: AppColors.pierVerde.withValues(alpha: 0.3)) : null,
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(t.$3, size: 18, color: sel ? Colors.white : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(t.$1,
                        style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? AppColors.pierVerde : AppColors.textPrimary, fontSize: 15))),
                    if (sel) Icon(Icons.check_circle_rounded, color: AppColors.pierVerde, size: 20),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
