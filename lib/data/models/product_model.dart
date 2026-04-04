class Product {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final String imagenUrl;
  final bool popular;
  final double rating;
  final int totalResenas;
  final bool disponible;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    required this.imagenUrl,
    this.popular = false,
    this.rating = 0.0,
    this.totalResenas = 0,
    this.disponible = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id_producto']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      categoria: json['categoria'] ?? json['nombre_categoria'] ?? '',
      imagenUrl: json['imagen_url'] ?? json['imagenUrl'] ?? '',
      popular: json['popular'] == true || json['popular'] == 1,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      totalResenas: int.tryParse(json['total_resenas']?.toString() ?? '0') ?? 0,
      disponible: json['disponible'] == true || json['disponible'] == 1,
    );
  }

  // Getters de compatibilidad con código existente de Tilin
  String get name => nombre;
  String get description => descripcion;
  double get price => precio;
  String get imageUrl => imagenUrl;
}