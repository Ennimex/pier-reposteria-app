// lib/domain/models/category_model.dart
//
// Categoría del catálogo (GET /categorias): el id hace falta para pedir sus
// opciones de filtro (GET /categoria-opciones/:id).

/// Categoría de productos tal como la manda el backend.
class Categoria {
  const Categoria({required this.id, required this.nombre});

  /// Acepta `nombre` o `name` (el backend usa ambos según la versión).
  factory Categoria.fromJson(Map<dynamic, dynamic> json) => Categoria(
        id: json['id']?.toString() ?? '',
        nombre: (json['nombre'] ?? json['name'] ?? '').toString(),
      );

  final String id;
  final String nombre;
}
