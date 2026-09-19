// lib/domain/models/direccion_model.dart
//
// Dirección de entrega del cliente (libreta reutilizable). Fuente:
// GET /api/direcciones — incluye la zona/tarifa si la colonia tiene cobertura.
class DireccionCliente {
  final String id;
  final String alias;
  final String calleNumero;
  final String colonia;
  final String? referencias;
  final String? telefonoContacto;
  final String? zonaNombre;
  final double? tarifa; // null = sin cobertura de envío en esa colonia

  const DireccionCliente({
    required this.id,
    required this.alias,
    required this.calleNumero,
    required this.colonia,
    this.referencias,
    this.telefonoContacto,
    this.zonaNombre,
    this.tarifa,
  });

  bool get tieneCobertura => tarifa != null;

  factory DireccionCliente.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return DireccionCliente(
      id: json['id']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      calleNumero: json['calle_numero']?.toString() ?? '',
      colonia: json['colonia']?.toString() ?? '',
      referencias: str(json['referencias']),
      telefonoContacto: str(json['telefono_contacto']),
      zonaNombre: str(json['zona_nombre']) ?? str(json['zona']),
      tarifa: json['tarifa'] != null
          ? double.tryParse(json['tarifa'].toString())
          : null,
    );
  }

  String get lineaResumen {
    final partes = [calleNumero, colonia].where((s) => s.isNotEmpty);
    return partes.join(', ');
  }
}
