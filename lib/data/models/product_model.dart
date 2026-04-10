import 'dart:convert';
// lib/data/models/product_model.dart
class Product {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final double? precioGrande;
  final String categoria;
  final String imagenUrl;
  final List<String> imagenes;
  final List<String> ingredientes;
  final String? sabor;
  final String? tamano;
  final String? tipo;
  final bool popular;
  final bool esNuevo;
  final int stockOnline;
  final bool disponible;
  final double rating;
  final int totalResenas;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    this.precioGrande,
    required this.categoria,
    required this.imagenUrl,
    this.imagenes = const [],
    this.ingredientes = const [],
    this.sabor,
    this.tamano,
    this.tipo,
    this.popular = false,
    this.esNuevo = false,
    this.stockOnline = 0,
    this.disponible = true,
    this.rating = 0.0,
    this.totalResenas = 0,
  });

  // Método estático — Dart no permite funciones locales tipadas dentro de factories
  static List<String> _parseList(dynamic val) {
    if (val == null) return const [];
    if (val is List) {
      return val.map((e) {
        // Si el elemento es un objeto {url, public_id} extraer url
        if (e is Map) return (e['url'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    // Backend devuelve JSON string desde PostgreSQL
    if (val is String && val.trim().startsWith('[')) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map) return (e['url'] ?? '').toString();
            return e.toString();
          }).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      precio: double.tryParse(json['precio_chico']?.toString() ?? '0') ?? 0.0,
      precioGrande: json['precio_grande'] != null
          ? double.tryParse(json['precio_grande'].toString())
          : null,
      categoria: json['categoria'] ?? '',
      imagenUrl: json['imagen_url'] ?? '',
      imagenes: Product._parseList(json['imagenes']),
      ingredientes: Product._parseList(json['ingredientes']),
      sabor: json['sabor'],
      tamano: json['tamano'],
      tipo: json['tipo'],
      popular: json['popular'] == true || json['popular'] == 1,
      esNuevo: json['es_nuevo'] == true || json['es_nuevo'] == 1,
      stockOnline: int.tryParse(json['stock_online']?.toString() ?? '0') ?? 0,
      disponible: json['activo'] == true || json['activo'] == 1,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      totalResenas: int.tryParse(json['reviews']?.toString() ?? '0') ?? 0,
    );
  }

  // Getters de compatibilidad con código existente
  String get name => nombre;
  String get description => descripcion;
  double get price => precio;
  String get imageUrl => imagenUrl;
}