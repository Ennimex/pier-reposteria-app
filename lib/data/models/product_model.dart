class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool popular;
  final double rating;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.popular = false,
    this.rating = 5.0,
  });
}

// Datos de ejemplo (dummy data)
class ProductData {
  static List<Product> getSampleProducts() {
    return [
      Product(
        id: '1',
        name: 'Pastel de Chocolate Premium',
        description: 'Delicioso pastel de chocolate con cobertura de ganache',
        price: 450.00,
        category: 'Pasteles',
        imageUrl: 'https://picsum.photos/300/300?random=1', // Temporal
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '2',
        name: 'Rosca Cielito Lindo',
        description: 'Con glorias de Linares, sabor tradicional mexicano',
        price: 320.00,
        category: 'Roscas',
        imageUrl: 'https://picsum.photos/300/300?random=2',
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '3',
        name: 'Mostachón de Maracuyá',
        description: 'Explosión tropical en cada bocado',
        price: 280.00,
        category: 'Pays',
        imageUrl: 'https://picsum.photos/300/300?random=3',
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '4',
        name: 'Postre Cuchereable Especial',
        description: 'Postre individual perfecto para cualquier ocasión',
        price: 120.00,
        category: 'Postres',
        imageUrl: 'https://picsum.photos/300/300?random=4',
        rating: 4.5,
      ),
      Product(
        id: '5',
        name: 'Soda Italiana Artesanal',
        description: 'Bebida refrescante con ingredientes premium',
        price: 65.00,
        category: 'Cafetería',
        imageUrl: 'https://picsum.photos/300/300?random=5',
        rating: 4.8,
      ),
      Product(
        id: '6',
        name: 'Pastel Red Velvet',
        description: 'Clásico pastel terciopelo rojo con queso crema',
        price: 480.00,
        category: 'Pasteles',
        imageUrl: 'https://picsum.photos/300/300?random=6',
        popular: false,
        rating: 4.9,
      ),
    ];
  }
}