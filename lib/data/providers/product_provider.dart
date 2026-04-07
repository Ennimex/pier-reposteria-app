// lib/data/providers/product_provider.dart
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
    if (categoria == 'Todos') {
      return _productos.where((p) => p.disponible).toList();
    }
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
      final data = result['productos'] ?? result['data'] ?? [];
      _productos = (data as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      _errorMessage = result['message'] ?? 'Error al cargar productos';
    }

    notifyListeners();
  }

  Future<void> refrescar() async {
    _productos = [];
    await cargarProductos();
  }

  // Carga un solo producto por id (para detalle)
  Future<Map<String, dynamic>?> cargarDetalle(String id) async {
    final result = await _api.get('${ApiConstants.productos}/$id');
    if (result['success'] == true) return result;
    return null;
  }
}