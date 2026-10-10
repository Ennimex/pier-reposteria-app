// lib/domain/models/filtros_catalogo.dart
//
// Opciones de filtro del catálogo: el set global (GET /filtros) o el propio
// de una categoría (GET /categoria-opciones/:id, que no trae tamaños).

/// Sabores, tamaños y tipos por los que se puede filtrar el catálogo.
class FiltrosCatalogo {
  const FiltrosCatalogo({
    this.sabores = const [],
    this.tamanos = const [],
    this.tipos = const [],
  });

  /// `{sabores: [String], tamanos: [String], tipos: [String]}` de /filtros.
  factory FiltrosCatalogo.fromFiltros(Map<dynamic, dynamic> json) =>
      FiltrosCatalogo(
        sabores: _textos(json['sabores']),
        tamanos: _textos(json['tamanos']),
        tipos: _textos(json['tipos']),
      );

  /// `{sabores: [...], tipos: [...]}` de /categoria-opciones/:id, donde cada
  /// opción puede venir como texto o como `{nombre}`. Se omiten las vacías.
  factory FiltrosCatalogo.fromOpcionesCategoria(Map<dynamic, dynamic> json) =>
      FiltrosCatalogo(
        sabores: _nombres(json['sabores']),
        tipos: _nombres(json['tipos']),
      );

  final List<String> sabores;
  final List<String> tamanos;
  final List<String> tipos;

  static List<String> _textos(dynamic lista) =>
      lista is List ? lista.map((e) => e.toString()).toList() : const [];

  static List<String> _nombres(dynamic lista) => lista is List
      ? lista
          .map((o) => (o is Map ? o['nombre'] : o)?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList()
      : const [];
}
