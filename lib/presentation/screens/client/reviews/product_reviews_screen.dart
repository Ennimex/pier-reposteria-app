import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ProductReviewsScreen extends StatelessWidget {
  const ProductReviewsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Opiniones del producto'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Resumen Superior
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF9F9F9),
            child: Row(
              children: [
                Column(
                  children: const [
                    Text(
                      '4.8',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Row(children: [Icon(Icons.star, size: 16, color: AppColors.pierDorado), Icon(Icons.star, size: 16, color: AppColors.pierDorado), Icon(Icons.star, size: 16, color: AppColors.pierDorado), Icon(Icons.star, size: 16, color: AppColors.pierDorado), Icon(Icons.star, size: 16, color: AppColors.pierDorado)]),
                    Text('124 calificaciones', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      return Row(
                        children: [
                          Text('$star', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: star == 5 ? 0.8 : (star == 4 ? 0.15 : 0.02),
                              backgroundColor: Colors.grey[200],
                              color: AppColors.pierDorado,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.sort, size: 16, color: AppColors.textPrimary),
                  label: const Text('Más recientes', style: TextStyle(color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 16, color: AppColors.textPrimary),
                  label: const Text('Todas las estrellas', style: TextStyle(color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Reseñas
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const Divider(),
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.pierArena,
                          child: Text('MP', style: TextStyle(color: AppColors.pierVerde)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Maria Perez', style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: const [
                                Icon(Icons.star, size: 14, color: AppColors.pierDorado),
                                Icon(Icons.star, size: 14, color: AppColors.pierDorado),
                                Icon(Icons.star, size: 14, color: AppColors.pierDorado),
                                Icon(Icons.star, size: 14, color: AppColors.pierDorado),
                                Icon(Icons.star, size: 14, color: AppColors.pierDorado),
                                SizedBox(width: 8),
                                Text('Hace 2 días', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('¡Delicioso!', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Me encantó el sabor y la presentación. Llegó muy fresco y a tiempo. Definitivamente volveré a pedir para mi próximo evento.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.check_circle, size: 16, color: AppColors.pierVerde),
                        SizedBox(width: 4),
                        Text('Compra verificada', style: TextStyle(color: AppColors.pierVerde, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}