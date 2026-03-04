import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';

class CreateReviewScreen extends StatefulWidget {
  final Product product;

  const CreateReviewScreen({super.key, required this.product});

  @override
  State<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends State<CreateReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _ratingLabels = [
    'Selecciona una calificación',
    'Malo',
    'Regular',
    'Bueno',
    'Muy bueno',
    '¡Excelente!'
  ];

  void _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona las estrellas')),
      );
      return;
    }
    if (_commentController.text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El comentario debe tener al menos 20 caracteres')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Simular API
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Éxito
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.check_circle, color: AppColors.pierVerde, size: 50),
        content: const Text(
          '¡Gracias por tu opinión!\nSerá publicada después de ser revisada.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Cerrar pantalla de reseña
            },
            child: const Text('Entendido', style: TextStyle(color: AppColors.pierVerde)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escribir Opinión'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Info Producto
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.product.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Pedido #PED-4829', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Selector de Estrellas
            const Text('¿Qué te pareció el producto?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: AppColors.pierDorado,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            Text(
              _ratingLabels[_rating],
              style: const TextStyle(
                color: AppColors.pierVerde,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),

            // Campos de texto
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título de tu opinión (Opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Cuéntanos tu experiencia',
                hintText: 'Mínimo 20 caracteres...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Botón Foto (Simulado)
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.camera_alt, color: Colors.grey),
              label: const Text('Agregar fotos', style: TextStyle(color: Colors.grey)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
            const SizedBox(height: 30),

            // Botón Enviar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Publicar Opinión', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}