import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Product> _productos = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get productos => _productos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Product> get populares =>
      _productos.where((p) => p.popular && p.disponible).toList();

  List<Product> get recientes =>
      _productos.where((p) => p.disponible).take(6).toList();

  List<Product> byCategoria(String categoria) {
    if (categoria == 'Todos')
      return _productos.where((p) => p.disponible).toList();
    return _productos
        .where((p) => p.categoria == categoria && p.disponible)
        .toList();
  }

  Future<void> cargarProductos() async {
    if (_productos.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _api.get(ApiConstants.productos);

    _isLoading = false;

    if (result['success'] == true) {
      final data = result['data'] ?? result['productos'] ?? [];
      if ((data as List).isNotEmpty) {
        _productos = data
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
        return;
      }
    }

    // Fallback: productos de ejemplo si la API no responde
    _errorMessage = null;
    _productos = _sampleProducts();
    notifyListeners();
  }

  Future<void> refrescar() async {
    _productos = [];
    await cargarProductos();
  }

  static List<Product> _sampleProducts() {
    return [
      Product(
        id: '1',
        nombre: 'Pastel de Chocolate Premium',
        descripcion: 'Delicioso pastel de chocolate con cobertura de ganache',
        precio: 450.00,
        categoria: 'Pasteles',
        imagenUrl:
            'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&fit=crop',
        popular: true,
        rating: 5.0,
        totalResenas: 120,
      ),
      Product(
        id: '2',
        nombre: 'Rosca Cielito Lindo',
        descripcion: 'Con glorias de Linares, sabor tradicional mexicano',
        precio: 320.00,
        categoria: 'Roscas',
        imagenUrl:
            'https://images.unsplash.com/photo-1535920527894-b945a9ebc533?w=400&fit=crop',
        popular: true,
        rating: 5.0,
        totalResenas: 98,
      ),
      Product(
        id: '3',
        nombre: 'Mostachón de Maracuyá',
        descripcion: 'Explosión tropical en cada bocado',
        precio: 280.00,
        categoria: 'Pays',
        imagenUrl:
            'https://images.unsplash.com/photo-1573080496294-4330daf27c91?w=400&fit=crop',
        popular: true,
        rating: 4.8,
        totalResenas: 74,
      ),
      Product(
        id: '4',
        nombre: 'Postre Cuchereable Especial',
        descripcion: 'Postre individual perfecto para cualquier ocasión',
        precio: 120.00,
        categoria: 'Postres',
        imagenUrl:
            'https://images.unsplash.com/photo-1565958011504-98d6efed2eea?w=400&fit=crop',
        popular: false,
        rating: 4.5,
        totalResenas: 45,
      ),
      Product(
        id: '5',
        nombre: 'Soda Italiana Artesanal',
        descripcion: 'Bebida refrescante con ingredientes premium',
        precio: 65.00,
        categoria: 'Cafetería',
        imagenUrl:
            'https://images.unsplash.com/photo-1511537190424-bbbab87ac5d1?w=400&fit=crop',
        popular: true,
        rating: 4.8,
        totalResenas: 62,
      ),
      Product(
        id: '6',
        nombre: 'Pastel Red Velvet',
        descripcion: 'Clásico pastel terciopelo rojo con queso crema',
        precio: 480.00,
        categoria: 'Pasteles',
        imagenUrl:
            'https://images.unsplash.com/photo-1553882900-f2b06423ff54?w=400&fit=crop',
        popular: true,
        rating: 4.9,
        totalResenas: 88,
      ),
      Product(
        id: '7',
        nombre: 'Pastel de Fresas y Nata',
        descripcion: 'Esponjoso pastel con fresas frescas de temporada',
        precio: 420.00,
        categoria: 'Pasteles',
        imagenUrl:
            'https://images.unsplash.com/photo-1488477181946-6b0b2f36b816?w=400&fit=crop',
        popular: true,
        rating: 4.9,
        totalResenas: 103,
      ),
      Product(
        id: '8',
        nombre: 'Brownie Premium',
        descripcion: 'Brownies de chocolate denso con nueces',
        precio: 85.00,
        categoria: 'Postres',
        imagenUrl:
            'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=400&fit=crop',
        popular: true,
        rating: 4.7,
        totalResenas: 56,
      ),
      Product(
        id: '9',
        nombre: 'Tiramisú Italiano',
        descripcion: 'Postre italiano clásico con mascarpone',
        precio: 150.00,
        categoria: 'Postres',
        imagenUrl:
            'https://images.unsplash.com/photo-1571115764595-644a12c7aed5?w=400&fit=crop',
        popular: false,
        rating: 4.8,
        totalResenas: 39,
      ),
      Product(
        id: '10',
        nombre: 'Café Cappuccino Premium',
        descripcion: 'Espresso con leche vaporizada y espuma perfecta',
        precio: 75.00,
        categoria: 'Cafetería',
        imagenUrl:
            'https://images.unsplash.com/photo-1517668808822-9ebb02ae2a0e?w=400&fit=crop',
        popular: true,
        rating: 4.9,
        totalResenas: 77,
      ),
      Product(
        id: '11',
        nombre: 'Donut Glaseado',
        descripcion: 'Donuts caseros con glaseado artesanal',
        precio: 95.00,
        categoria: 'Roscas',
        imagenUrl:
            'https://images.unsplash.com/photo-1585745377279-60aaff0f4fa6?w=400&fit=crop',
        popular: true,
        rating: 4.6,
        totalResenas: 51,
      ),
      Product(
        id: '12',
        nombre: 'Tres Leches Gourmet',
        descripcion: 'Pastel tres leches con ingredientes premium',
        precio: 520.00,
        categoria: 'Pasteles',
        imagenUrl:
            'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&fit=crop',
        popular: true,
        rating: 5.0,
        totalResenas: 134,
      ),
    ];
  }
}