// lib/domain/models/consulta_catalogo.dart
//
// Lo que el cliente pide ver del catálogo (#37): categoría, búsqueda, filtros
// de sabor/tamaño/tipo y orden. Sus `parametros` son los de GET /productos y,
// según el orden, se sabe si el servidor puede entregar el catálogo por
// páginas o si hay que traerlo completo.
import 'package:flutter/foundation.dart' show immutable;

/// Criterios de orden del catálogo.
enum SortOption { popular, priceAsc, priceDesc, nameAsc, rating }

/// Consulta inmutable al catálogo; con sus valores por omisión es el catálogo
/// completo en el orden de los más populares.
@immutable
class ConsultaCatalogo {
  const ConsultaCatalogo({
    this.categoria = todas,
    this.busqueda = '',
    this.sabor,
    this.tamano,
    this.tipo,
    this.orden = SortOption.popular,
  });

  /// Categoría que muestra todo el catálogo (no se manda al servidor).
  static const String todas = 'Todos';

  /// Órdenes cuyas páginas del servidor no repiten ni saltan productos porque
  /// su ORDER BY termina en el nombre. Precio y calificación empatan seguido y
  /// el servidor no desempata, así que se piden completos. Es el único lugar
  /// a cambiar el día que el servidor desempate también esos órdenes.
  static const Set<SortOption> ordenesConPaginasDelServidor = {
    SortOption.popular,
    SortOption.nameAsc,
  };

  final String categoria;
  final String busqueda;
  final String? sabor;
  final String? tamano;
  final String? tipo;
  final SortOption orden;

  /// Parámetros de GET /productos de esta consulta. Lo que no filtra
  /// (categoría «Todos», búsqueda vacía, el orden popular) no se manda.
  Map<String, String> get parametros {
    final texto = busqueda.trim();
    return {
      if (categoria != todas) 'categoria': categoria,
      if (texto.isNotEmpty) 'busqueda': texto,
      'sabor': ?sabor,
      'tamano': ?tamano,
      'tipo': ?tipo,
      'ordenar': ?_ordenar,
    };
  }

  /// Valor de `ordenar` del servidor; null = su orden por omisión (populares).
  String? get _ordenar => switch (orden) {
        SortOption.popular => null,
        SortOption.priceAsc => 'precio-asc',
        SortOption.priceDesc => 'precio-desc',
        SortOption.nameAsc => 'nombre',
        SortOption.rating => 'rating',
      };

  /// ¿El servidor no puede paginar este orden? Entonces se pide el catálogo
  /// completo y la paginación se hace en local.
  bool get pideTodo => !ordenesConPaginasDelServidor.contains(orden);

  /// ¿Es la consulta sin criterios, la que el servidor contesta sin
  /// parámetros?
  bool get esPorOmision => parametros.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsultaCatalogo &&
          other.categoria == categoria &&
          other.busqueda == busqueda &&
          other.sabor == sabor &&
          other.tamano == tamano &&
          other.tipo == tipo &&
          other.orden == orden;

  @override
  int get hashCode =>
      Object.hash(categoria, busqueda, sabor, tamano, tipo, orden);
}
