import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/providers/cart_provider.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../auth/login_screen.dart';
import '../../../widgets/product/product_card.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1;
  bool isFavorite = false;
  int _currentImageIndex = 0;
  
  // Controlador para hacer scroll a los comentarios
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewsKey = GlobalKey();

  // Simulamos imágenes múltiples repitiendo la que tenemos o usando placeholders
  late List<String> productImages;
  
  // Simulamos productos relacionados
  late List<Product> relatedProducts;

  @override
  void initState() {
    super.initState();
    // Simulamos 3 imágenes para el carrusel
    productImages = [
      widget.product.imageUrl,
      widget.product.imageUrl,
      widget.product.imageUrl, 
    ];

    // Obtenemos productos relacionados simulados
    relatedProducts = ProductData.getSampleProducts()
        .where((p) => p.id != widget.product.id) // Excluimos el actual
        .take(4)
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _increment() {
    if (quantity < 10) setState(() => quantity++);
  }

  void _decrement() {
    if (quantity > 1) setState(() => quantity--);
  }

  void _addToCart() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(widget.product, quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantity x ${widget.product.name} agregado al carrito'),
        backgroundColor: AppColors.pierVerde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
    Navigator.pop(context);
  }

  void _scrollToReviews() {
    final context = _reviewsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- PANEL PARA MOSTRAR TODAS LAS OPINIONES ---
  void _showAllReviewsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9, 
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 5, width: 40,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Opiniones del producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text('4.8', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: List.generate(5, (index) => Icon(Icons.star, color: index < 4 ? Colors.amber : Colors.amber.shade200, size: 24))),
                          const SizedBox(height: 4),
                          const Text('120 calificaciones', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: 10,
                    separatorBuilder: (context, index) => const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
                    itemBuilder: (context, index) {
                      final names = ['María G.', 'Carlos R.', 'Ana P.', 'Luis M.', 'Sofía T.'];
                      final ratings = [5, 4, 5, 5, 3];
                      final dates = ['Hace 2 días', 'Hace 1 semana', 'Hace 2 semanas', 'Hace 1 mes', 'Hace 1 mes'];
                      final currentIdx = index % 5; 

                      return _buildReviewCard(
                        names[currentIdx], 
                        ratings[currentIdx], 
                        ratings[currentIdx] >= 4 ? '¡Excelente!' : 'Bueno', 
                        'El sabor es increíble, la textura del pan está perfecta. Muy recomendado para cualquier evento.', 
                        dates[currentIdx]
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- NUEVA FUNCIÓN: PANEL PARA ESCRIBIR UNA OPINIÓN ---
  void _showAddReviewSheet() {
    // 1. Verificamos si está logueado
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // Variables de estado para el panel
    int selectedRating = 5;
    final TextEditingController reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Importante para que el teclado empuje el panel hacia arriba
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder permite redibujar solo el panel interior (para las estrellas)
          builder: (context, setModalState) {
            return Padding(
              // viewInsets.bottom empuja el contenido cuando sale el teclado
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calificar producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Estrellas interactivas
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return IconButton(
                          iconSize: 40,
                          icon: Icon(
                            index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setModalState(() {
                              selectedRating = index + 1; // Actualiza las estrellas pintadas
                            });
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Campo de texto
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos qué te pareció el sabor, la presentación y la calidad...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.pierVerde, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de Enviar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        // AQUÍ IRÍA LA LÓGICA PARA GUARDAR EN LA BASE DE DATOS
                        Navigator.pop(context); // Cierra el panel
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text('¡Gracias por tu opinión!'),
                              ],
                            ),
                            backgroundColor: AppColors.pierVerde,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierVerde,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Enviar opinión', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. APPBAR CON CARRUSEL DE IMÁGENES
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.pierVerdeOscuro,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1 * 255), blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.pierVerde),
                    onPressed: () {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      if (!auth.isAuthenticated) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        return;
                      }
                      setState(() => isFavorite = !isFavorite);
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: productImages.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return Image.network(
                        productImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.cake, size: 80, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6 * 255),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${productImages.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        productImages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentImageIndex == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index ? AppColors.pierDorado : Colors.white.withValues(alpha: 0.5 * 255),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. CONTENIDO DEL PRODUCTO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips de Información
                  Row(
                    children: [
                      if (widget.product.popular) ...[
                        _buildChip('🌟 Popular', AppColors.pierDorado, true),
                        const SizedBox(width: 8),
                      ],
                      _buildChip('Pasteles', AppColors.pierVerde, false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Text(widget.product.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro)),
                  const SizedBox(height: 8),
                  
                  // Rating Clickeable
                  GestureDetector(
                    onTap: _scrollToReviews,
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const Icon(Icons.star_half, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Text('4.8 ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('(120 reseñas)', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Text('\$${widget.product.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.pierDorado)),
                  
                  const Divider(height: 40),

                  // Info extra (Porciones, Tiempo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoIcon(Icons.pie_chart_outline, '12 Porciones'),
                      _buildInfoIcon(Icons.access_time, '24-48 hrs prep.'),
                    ],
                  ),

                  const Divider(height: 40),
                  
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(widget.product.description, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
                  
                  const SizedBox(height: 24),
                  
                  // Ingredientes
                  const Text('Ingredientes Principales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildIngredientChip('Harina artesanal'),
                      _buildIngredientChip('Mantequilla'),
                      _buildIngredientChip('Vainilla natural'),
                    ],
                  ),

                  const SizedBox(height: 40),
                  
                  // Controles de cantidad
                  Row(
                    children: [
                      const Text('Cantidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove), onPressed: _decrement, color: AppColors.pierVerde),
                            Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.add), onPressed: _increment, color: AppColors.pierVerde),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // BOTÓN AGREGAR
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.shopping_cart, color: Colors.white),
                      label: Text('Agregar al carrito - \$${(widget.product.price * quantity).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierVerde,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                      ),
                    ),
                  ),
                  
                  const Divider(height: 60, thickness: 8, color: Color(0xFFF5F1ED)),

                  // --- SECCIÓN DE OPINIONES ---
                  Container(key: _reviewsKey), 
                  const Text('Opiniones del producto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro)),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      const Text('4.8', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (index) => Icon(Icons.star, color: index < 4 ? Colors.amber : Colors.amber.shade200, size: 20)),
                          ),
                          const SizedBox(height: 4),
                          const Text('Basado en 120 calificaciones', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Reseñas Mockeadas (Muestra solo 2 como vista previa)
                  _buildReviewCard('María G.', 5, '¡Delicioso!', 'Compré este pastel para el cumpleaños de mi mamá y le encantó. El bizcocho súper suave.', 'Hace 2 días'),
                  _buildReviewCard('Carlos R.', 4, 'Muy bueno', 'Excelente sabor, la presentación impecable. Solo me gustaría que fuera un poco más grande.', 'Hace 1 semana'),
                  
                  const SizedBox(height: 16),
                  
                  // BOTÓN: MOSTRAR TODAS LAS OPINIONES
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showAllReviewsPanel, 
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.pierVerde),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Mostrar todas las opiniones', style: TextStyle(color: AppColors.pierVerde, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // BOTÓN: ESCRIBIR UNA OPINIÓN
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddReviewSheet,
                      icon: const Icon(Icons.create_rounded, color: AppColors.pierVerdeOscuro, size: 20),
                      label: const Text('Escribir una opinión', style: TextStyle(color: AppColors.pierVerdeOscuro, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pierDorado.withValues(alpha: 0.3 * 255),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const Divider(height: 60, thickness: 8, color: Color(0xFFF5F1ED)),

                  // --- TAMBIÉN TE PUEDE GUSTAR ---
                  const Text('También te puede gustar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.pierVerdeOscuro)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 280,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: relatedProducts.length,
                      separatorBuilder: (context, _) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 180,
                          child: ProductCard(
                            product: relatedProducts[index],
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => ProductDetailScreen(product: relatedProducts[index])),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildChip(String label, Color color, bool isOutline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOutline ? color.withValues(alpha: 0.1 * 255) : color.withValues(alpha: 0.15 * 255),
        borderRadius: BorderRadius.circular(20),
        border: isOutline ? Border.all(color: color) : null,
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildIngredientChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }

  Widget _buildReviewCard(String name, int stars, String title, String comment, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.pierDorado.withValues(alpha: 0.2 * 255),
                radius: 20,
                child: Text(name[0], style: const TextStyle(color: AppColors.pierDorado, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      Row(children: List.generate(5, (index) => Icon(Icons.star, color: index < stars ? Colors.amber : Colors.grey[300], size: 14))),
                      const SizedBox(width: 8),
                      const Text('• Compra verificada', style: TextStyle(color: AppColors.pierVerde, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(comment, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('Útil', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}