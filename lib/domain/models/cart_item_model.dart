// lib/domain/models/cart_item_model.dart
//
// Una línea del carrito (producto + tamaño), tal como la devuelve GET /carrito.
// El backend manda el precio ya con descuento (precio_unitario) y el de lista
// (precio_original); el ahorro se calcula aquí y nunca sale negativo.

class CartItem {
  CartItem({
    required this.id,
    required this.nombre,
    required this.quantity,
    required this.precio,
    required this.imagenUrl,
    this.carritoItemId,
    double? precioOriginal,
    this.tieneDescuento = false,
    this.promoNombre,
    this.tamano = 'chico',
  }) : precioOriginal = precioOriginal ?? precio;

  /// Línea de GET /carrito. Sin precio_original (o menor que el precio) se
  /// toma el mismo precio: sin descuento, en lugar de un ahorro negativo.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final precio = _numero(json['precio_unitario']) ?? 0;
    final original = _numero(json['precio_original']);
    final precioOriginal =
        original != null && original > precio ? original : precio;
    return CartItem(
      id: json['producto_id']?.toString() ?? '',
      carritoItemId: json['carrito_item_id']?.toString(),
      nombre: json['nombre']?.toString() ?? '',
      precio: precio,
      precioOriginal: precioOriginal,
      quantity: int.tryParse(json['cantidad']?.toString() ?? '') ?? 1,
      imagenUrl: json['imagen_url']?.toString() ?? '',
      tieneDescuento:
          json['tiene_descuento'] == true && precioOriginal > precio,
      promoNombre: json['promo_nombre']?.toString(),
      tamano: json['tamano']?.toString() ?? 'chico',
    );
  }

  final String id;              // producto_id
  final String? carritoItemId;  // id en tblcarrito_items
  final String nombre;
  final int quantity;
  final double precio;          // precio con descuento ya aplicado (precio_unitario del backend)
  final double precioOriginal;  // precio sin descuento (precio_original del backend)
  final String imagenUrl;
  final bool tieneDescuento;
  final String? promoNombre;    // nombre_temporada de la promoción
  final String tamano;          // 'chico' | 'grande' — el backend cobra según esto

  static double? _numero(Object? valor) =>
      valor == null ? null : double.tryParse(valor.toString());

  // Clave única de línea: un mismo producto en chico y grande son dos líneas.
  String get lineKey => '${id}_$tamano';

  CartItem copyWith({
    int? quantity,
    String? carritoItemId,
    double? precio,
    double? precioOriginal,
    bool? tieneDescuento,
    String? promoNombre,
    String? tamano,
  }) {
    return CartItem(
      id: id,
      carritoItemId: carritoItemId ?? this.carritoItemId,
      nombre: nombre,
      precio: precio ?? this.precio,
      precioOriginal: precioOriginal ?? this.precioOriginal,
      quantity: quantity ?? this.quantity,
      imagenUrl: imagenUrl,
      tieneDescuento: tieneDescuento ?? this.tieneDescuento,
      promoNombre: promoNombre ?? this.promoNombre,
      tamano: tamano ?? this.tamano,
    );
  }

  // ✅ Subtotal calculado con precio ya descontado
  double get subtotal => precio * quantity;

  // ✅ Ahorro total en este item
  double get ahorroTotal =>
      tieneDescuento ? (precioOriginal - precio) * quantity : 0.0;
}
