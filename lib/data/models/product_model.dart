//app/lib/data/models/product_model.dart
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

// Datos de ejemplo con imágenes de Unsplash (API de pasteles y postres)
class ProductData {
  static List<Product> getSampleProducts() {
    return [
      Product(
        id: '1',
        name: 'Pastel de Chocolate Premium',
        description: 'Delicioso pastel de chocolate con cobertura de ganache',
        price: 450.00,
        category: 'Pasteles',
        imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=300&h=300&fit=crop',
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '2',
        name: 'Rosca Cielito Lindo',
        description: 'Con glorias de Linares, sabor tradicional mexicano',
        price: 320.00,
        category: 'Roscas',
        imageUrl: 'https://images.unsplash.com/photo-1535920527894-b945a9ebc533?w=300&h=300&fit=crop',
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '3',
        name: 'Mostachón de Maracuyá',
        description: 'Explosión tropical en cada bocado',
        price: 280.00,
        category: 'Pays',
        imageUrl: 'https://images.unsplash.com/photo-1573080496294-4330daf27c91?w=300&h=300&fit=crop',
        popular: true,
        rating: 5.0,
      ),
      Product(
        id: '4',
        name: 'Postre Cuchereable Especial',
        description: 'Postre individual perfecto para cualquier ocasión',
        price: 120.00,
        category: 'Postres',
        imageUrl: 'https://images.unsplash.com/photo-1565958011504-98d6efed2eea?w=300&h=300&fit=crop',
        rating: 4.5,
      ),
      Product(
        id: '5',
        name: 'Soda Italiana Artesanal',
        description: 'Bebida refrescante con ingredientes premium',
        price: 65.00,
        category: 'Cafetería',
        imageUrl: 'https://images.unsplash.com/photo-1511537190424-bbbab87ac5d1?w=300&h=300&fit=crop',
        rating: 4.8,
      ),
      Product(
        id: '6',
        name: 'Pastel Red Velvet',
        description: 'Clásico pastel terciopelo rojo con queso crema',
        price: 480.00,
        category: 'Pasteles',
        imageUrl: 'https://images.unsplash.com/photo-1553882900-f2b06423ff54?w=300&h=300&fit=crop',
        popular: false,
        rating: 4.9,
      ),
      Product(
        id: '7',
        name: 'Pastel de Fresas y Nata',
        description: 'Esponjoso pastel con fresas frescas',
        price: 420.00,
        category: 'Pasteles',
        imageUrl: 'https://images.unsplash.com/photo-1488477181946-6b0b2f36b816?w=300&h=300&fit=crop',
        popular: true,
        rating: 4.9,
      ),
      Product(
        id: '8',
        name: 'Brownie Premium',
        description: 'Brownies de chocolate denso con nueces',
        price: 85.00,
        category: 'Postres',
        imageUrl: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=300&h=300&fit=crop',
        popular: true,
        rating: 4.7,
      ),
      Product(
        id: '9',
        name: 'Tiramisú Italiano',
        description: 'Postre italiano clásico con mascarpone',
        price: 150.00,
        category: 'Postres',
        imageUrl: 'https://images.unsplash.com/photo-1571115764595-644a12c7aed5?w=300&h=300&fit=crop',
        rating: 4.8,
      ),
      Product(
        id: '10',
        name: 'Café Cappuccino Premium',
        description: 'Espresso con leche vaporizada',
        price: 75.00,
        category: 'Cafetería',
        imageUrl: 'https://images.unsplash.com/photo-1517668808822-9ebb02ae2a0e?w=300&h=300&fit=crop',
        popular: true,
        rating: 4.9,
      ),
      Product(
        id: '11',
        name: 'Donut Glaseado',
        description: 'Donuts caseros con glaseado artesanal',
        price: 95.00,
        category: 'Roscas',
        imageUrl: 'https://images.unsplash.com/photo-1585745377279-60aaff0f4fa6?w=300&h=300&fit=crop',
        popular: true,
        rating: 4.6,
      ),
      Product(
        id: '12',
        name: 'Tres Leches Gourmet',
        description: 'Pastel tres leches con ingredientes premium',
        price: 520.00,
        category: 'Pasteles',
        imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=300&h=300&fit=crop',
        popular: true,
        rating: 5.0,
      ),
    ];
  }
}