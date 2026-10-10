// lib/ui/products/widgets/catalogo_secciones.dart
//
// Secciones del catálogo: encabezado verde con carrito y buscador, chips de
// categoría y estado vacío. Pintan lo que expone el ProductsViewModel; la
// pantalla las repinta cuando cambia.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';
import 'package:pier_pasteleria/ui/products/widgets/catalogo_sheets.dart';
import 'package:provider/provider.dart';

IconData _iconoDeCategoria(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'todos': return LucideIcons.layoutGrid;
    case 'pasteles': return LucideIcons.cake;
    case 'roscas': return LucideIcons.donut;
    case 'pays': return LucideIcons.chartPie;
    case 'postres': return LucideIcons.cookie;
    case 'cafetería':
    case 'cafeteria': return LucideIcons.coffee;
    case 'bebidas': return LucideIcons.cupSoda;
    case 'panes': return LucideIcons.croissant;
    default: return LucideIcons.sandwich;
  }
}

/// Encabezado verde: nombre de la tienda, carrito con contador y buscador
/// (con ordenar y filtrar mientras no haya texto).
class CatalogoHeader extends StatelessWidget {
  const CatalogoHeader({
    required this.viewModel,
    required this.buscador,
    required this.cantidadCarrito,
    super.key,
  });

  final ProductsViewModel viewModel;
  final TextEditingController buscador;
  final int cantidadCarrito;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pierVerde,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pier Repostería',
                      style: TextStyle(fontFamily: 'Playfair Display', fontSize: 28,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Artesanal & Gourmet',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
              GestureDetector(
                onTap: () => context.read<NavigationProvider>().setSelectedIndex(2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.shoppingCart, color: Colors.white, size: 22),
                    ),
                    if (cantidadCarrito > 0)
                      Positioned(
                        right: -6, top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.pierDorado, shape: BoxShape.circle),
                          child: Text('$cantidadCarrito',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buscador(context),
        ],
      ),
    );
  }

  Widget _buscador(BuildContext context) {
    final vm = viewModel;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: buscador,
        onChanged: vm.buscar,
        decoration: InputDecoration(
          hintText: 'Busca tu antojo...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 15),
          prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 22),
          suffixIcon: vm.busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    buscador.clear();
                    vm.limpiarBusqueda();
                  })
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(LucideIcons.arrowUpDown, color: AppColors.textSecondary, size: 20),
                        onPressed: () => mostrarOrdenCatalogo(context, vm), tooltip: 'Ordenar'),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.slidersHorizontal,
                              color: vm.hayFiltrosDeOpciones ? AppColors.pierVerde : Colors.grey, size: 20),
                          onPressed: () => mostrarFiltrosCatalogo(context, vm), tooltip: 'Filtrar'),
                        if (vm.hayFiltrosDeOpciones)
                          Positioned(right: 8, top: 8,
                              child: Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: AppColors.pierVerde, shape: BoxShape.circle))),
                      ],
                    ),
                  ],
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Fila deslizable de chips de categoría.
class CatalogoCategorias extends StatelessWidget {
  const CatalogoCategorias({required this.viewModel, super.key});

  final ProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final categorias = viewModel.nombresCategorias;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categorias.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final nombre = categorias[i];
            final sel = viewModel.categoria == nombre;
            return GestureDetector(
              onTap: () => viewModel.seleccionarCategoria(nombre),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.pierVerde : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.pierVerde : AppColors.textSecondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconoDeCategoria(nombre), size: 13, color: sel ? Colors.white : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(nombre,
                        style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                            color: sel ? Colors.white : AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Sin resultados" con botón para limpiar los filtros.
class CatalogoVacio extends StatelessWidget {
  const CatalogoVacio({required this.onLimpiar, super.key});

  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppColors.pierVerde.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(LucideIcons.searchX, size: 48, color: AppColors.pierVerde),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          const Text('Sin resultados',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Intenta con otros términos\no ajusta los filtros',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onLimpiar,
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            label: const Text('Limpiar filtros', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pierVerde,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
