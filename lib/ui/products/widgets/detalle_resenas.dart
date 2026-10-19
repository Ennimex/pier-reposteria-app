// lib/ui/products/widgets/detalle_resenas.dart
//
// "Opiniones destacadas" del detalle: las 2 primeras reseñas con su "útil",
// escribir una nueva y ver todas. El "útil" lo lleva el ViewModel; aquí solo
// se pinta y se avisa el toque. Las opiniones reemplazan al indicador de
// carga con un fundido y el "útil" responde con un pop y su cuenta rueda.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/resena_producto.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/products/view_model/product_detail_view_model.dart';
import 'package:pier_reposteria/ui/products/widgets/movimiento_catalogo.dart';

/// "Hoy", "Ayer", "Hace 3 días", "Hace 2 sem.", "Hace 4 mes"; vacío sin fecha.
String fechaRelativa(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return '';
  final dias = (ahora ?? DateTime.now()).difference(fecha).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  if (dias < 7) return 'Hace $dias días';
  if (dias < 30) return 'Hace ${(dias / 7).floor()} sem.';
  return 'Hace ${(dias / 30).floor()} mes';
}

class DetalleResenas extends StatelessWidget {
  const DetalleResenas({
    required this.viewModel,
    required this.onEscribir,
    required this.onVerTodas,
    required this.onUtil,
    super.key,
  });

  final ProductDetailViewModel viewModel;
  final VoidCallback onEscribir;
  final VoidCallback onVerTodas;
  final ValueChanged<String> onUtil;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Opiniones destacadas',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            PresionEscala(
              escala: AppMovimiento.escalaPresionChica,
              child: GestureDetector(
                onTap: onEscribir,
                child: Row(children: [
                  Icon(LucideIcons.pencil, color: AppColors.pierVerde, size: 16),
                  const SizedBox(width: 4),
                  Text('Escribir',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.pierVerde,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Del indicador de carga a las opiniones (o al aviso de que no hay)
        // con un fundido a través; lo de abajo se recorre con suavidad en vez
        // de saltar.
        TamanoAnimado(
          duracion: AppMovimiento.media,
          child: CambioAnimado(
            tipo: TipoCambio.atravesar,
            child: KeyedSubtree(
              key: ValueKey<String>(vm.cargandoResenas
                  ? 'cargando'
                  : vm.resenas.isEmpty
                      ? 'sinOpiniones'
                      : 'opiniones'),
              child: _contenido(vm),
            ),
          ),
        ),
        if (vm.totalResenas > 0)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onVerTodas,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Ver las ${vm.totalResenas} opiniones',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  /// Cargando, sin opiniones o las 2 primeras.
  Widget _contenido(ProductDetailViewModel vm) {
    if (vm.cargandoResenas) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.pierVerde));
    }
    if (vm.resenas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Aún no hay opiniones.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      );
    }
    return Column(
      children: vm.resenas
          .take(2)
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ResenaDestacadaItem(
                    resena: r, onUtil: () => onUtil(r.id)),
              ))
          .toList(),
    );
  }
}

/// Una reseña: iniciales, autor, fecha relativa, estrellas, "útil" y texto.
class ResenaDestacadaItem extends StatelessWidget {
  const ResenaDestacadaItem({
    required this.resena,
    required this.onUtil,
    super.key,
  });

  final ResenaProducto resena;
  final VoidCallback onUtil;

  @override
  Widget build(BuildContext context) {
    final nombre = resena.autor;
    final marcada = resena.marcadaUtil;
    final iniciales = nombre.length >= 2
        ? nombre.substring(0, 2).toUpperCase()
        : nombre.isNotEmpty
            ? nombre[0]
            : '?';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.pierDorado.withValues(alpha: 0.15),
                child: Text(
                  iniciales,
                  style: TextStyle(
                      color: AppColors.pierDoradoOscuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(fechaRelativa(resena.creadaEn),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                const SizedBox(width: 3),
                Text(resena.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 8),
              // Al marcarlo con un toque da un pop con un destello verde (una
              // recarga de reseñas no destella), el pulgar cambia de color y
              // la cuenta rueda.
              DestelloCorazon(
                activo: marcada,
                color: AppColors.pierVerde,
                radio: 14,
                child: PresionEscala(
                  escala: AppMovimiento.escalaPresionChica,
                  child: GestureDetector(
                    onTap: onUtil,
                    child: Row(
                      children: [
                        IconoColorAnimado(
                          LucideIcons.thumbsUp,
                          color: marcada
                              ? AppColors.pierVerde
                              : AppColors.textSecondary.withValues(alpha: 0.5),
                          tamano: 15,
                        ),
                        const SizedBox(width: 4),
                        CifraRodante(
                          valor: resena.utilCount,
                          texto: '${resena.utilCount}',
                          estilo: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                marcada ? FontWeight.bold : FontWeight.normal,
                            color: marcada
                                ? AppColors.pierVerde
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(resena.comentario,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
    ]);
  }
}
