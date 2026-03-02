import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nosotros'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen Hero (Fachada)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300], // Placeholder imagen
              child: const Icon(Icons.store, size: 80, color: Colors.grey),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Nuestra Historia
                  _buildSectionTitle('Nuestra Historia'),
                  const Text(
                    'Pier Repostería nació en el corazón de Huejutla de Reyes como un pequeño sueño familiar. Lo que comenzó en una cocina casera, horneando con recetas de la abuela, hoy es un referente de sabor y tradición en la Huasteca Hidalguense.',
                    style: TextStyle(color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // 3. Misión y Visión
                  _buildCardInfo('Misión', 'Crear momentos inolvidables a través de sabores auténticos y una calidad artesanal inigualable.'),
                  const SizedBox(height: 16),
                  _buildCardInfo('Visión', 'Ser la pastelería líder en la región, reconocida por nuestra innovación constante sin perder la esencia tradicional.'),
                  
                  const SizedBox(height: 24),

                  // 4. Nuestros Valores
                  _buildSectionTitle('Nuestros Valores'),
                  _buildValueItem('Calidad Artesanal'),
                  _buildValueItem('Ingredientes Frescos'),
                  _buildValueItem('Atención Personalizada'),
                  _buildValueItem('Tradición e Innovación'),

                  const SizedBox(height: 32),

                  // 5. Nuestras Sucursales
                  _buildSectionTitle('Nuestras Sucursales'),
                  _buildBranchCard('Sucursal Principal', 'Av. Revolución 123, Centro'),
                  _buildBranchCard('Sucursal Plaza', 'Plaza Las Flores, Local 4'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro),
      ),
    );
  }

  Widget _buildCardInfo(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pierArena.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pierVerde.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.pierVerde)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildValueItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.pierDorado, size: 20),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBranchCard(String name, String address) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.pierVerde.withAlpha(26), shape: BoxShape.circle),
          child: const Icon(Icons.location_on, color: AppColors.pierVerde),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(address),
      ),
    );
  }
}