// lib/ui/core/themes/tema_catalogo.dart
//
// Catálogo de temas de temporada — espejo EXACTO de la web
// (pier-reposteria/src/temas/catalogo.ts): mismos ids, paletas y rangos de
// fechas, para que web y app cambien juntas desde el mismo panel de
// Personalización. Si se agrega un tema allá, hay que agregarlo acá.
import 'package:flutter/material.dart';

/// Los 8 tokens de color que la web pinta como variables CSS --pier-*.
/// Aquí alimentan los getters dinámicos de AppColors.
class PaletaPier {
  final Color verde;
  final Color verdeOscuro;
  final Color verdeClaro;
  final Color dorado;
  final Color doradoOscuro;
  final Color doradoClaro;
  final Color arena;
  final Color arenaOscuro;

  const PaletaPier({
    required this.verde,
    required this.verdeOscuro,
    required this.verdeClaro,
    required this.dorado,
    required this.doradoOscuro,
    required this.doradoClaro,
    required this.arena,
    required this.arenaOscuro,
  });
}

/// Rango mes/día para el modo automático; puede cruzar el año
/// (ej. invierno: 27 dic → 31 ene).
class RangoFechas {
  final int desdeMes, desdeDia, hastaMes, hastaDia;
  const RangoFechas(this.desdeMes, this.desdeDia, this.hastaMes, this.hastaDia);

  bool contiene(DateTime fecha) {
    final valor = fecha.month * 100 + fecha.day;
    final desde = desdeMes * 100 + desdeDia;
    final hasta = hastaMes * 100 + hastaDia;
    if (desde > hasta) return valor >= desde || valor <= hasta;
    return valor >= desde && valor <= hasta;
  }
}

class TemaPier {
  final String id;
  final String nombre;
  final PaletaPier colores;

  /// Sin fechas = solo activable a mano desde el panel.
  final RangoFechas? fechas;

  const TemaPier({
    required this.id,
    required this.nombre,
    required this.colores,
    this.fechas,
  });
}

/// Pier Clásico. verdeOscuro y doradoOscuro conservan los valores HISTÓRICOS
/// de la app (0xFF4A5A2B / 0xFFB8895C), ligeramente distintos de los de la
/// web (#556332 / #b8894f), para que la app se vea idéntica a como era antes
/// del theming dinámico. Los 3 tokens que la app no tenía (claro/arenaOscuro)
/// sí toman los valores web.
const TemaPier temaNormal = TemaPier(
  id: 'normal',
  nombre: 'Pier Clásico',
  colores: PaletaPier(
    verde: Color(0xFF6B7C3E),
    verdeOscuro: Color(0xFF4A5A2B),
    verdeClaro: Color(0xFF8A9B5E),
    dorado: Color(0xFFD4A574),
    doradoOscuro: Color(0xFFB8895C),
    doradoClaro: Color(0xFFE8C9A0),
    arena: Color(0xFFF5F1ED),
    arenaOscuro: Color(0xFFE8E0D5),
  ),
);

/// Ordenados por prioridad, igual que la web: en modo automático gana el
/// PRIMERO cuyo rango contenga la fecha (festivos cortos antes que
/// temporadas largas para resolver traslapes, ej. Reyes dentro de invierno).
const List<TemaPier> catalogoTemas = [
  TemaPier(
    id: 'dia-reyes',
    nombre: 'Día de Reyes',
    colores: PaletaPier(
      verde: Color(0xFF7C3AED),
      verdeOscuro: Color(0xFF5B21B6),
      verdeClaro: Color(0xFFA78BFA),
      dorado: Color(0xFFD9A441),
      doradoOscuro: Color(0xFFB7852D),
      doradoClaro: Color(0xFFECC987),
      arena: Color(0xFFF6F2EA),
      arenaOscuro: Color(0xFFEAE2D2),
    ),
    fechas: RangoFechas(1, 1, 1, 7),
  ),
  TemaPier(
    id: 'san-valentin',
    nombre: 'San Valentín',
    colores: PaletaPier(
      verde: Color(0xFFDB2777),
      verdeOscuro: Color(0xFF9D1A5B),
      verdeClaro: Color(0xFFF472B6),
      dorado: Color(0xFFE4A0AE),
      doradoOscuro: Color(0xFFC97B8B),
      doradoClaro: Color(0xFFF2C6CF),
      arena: Color(0xFFFDF2F6),
      arenaOscuro: Color(0xFFF8E3EC),
    ),
    fechas: RangoFechas(2, 1, 2, 15),
  ),
  TemaPier(
    id: 'dia-madres',
    nombre: 'Día de las Madres',
    colores: PaletaPier(
      verde: Color(0xFF9333EA),
      verdeOscuro: Color(0xFF6B21A8),
      verdeClaro: Color(0xFFC084FC),
      dorado: Color(0xFFE0B088),
      doradoOscuro: Color(0xFFC08C5F),
      doradoClaro: Color(0xFFEFD0AE),
      arena: Color(0xFFFAF5FF),
      arenaOscuro: Color(0xFFEFE4FA),
    ),
    fechas: RangoFechas(5, 1, 5, 15),
  ),
  TemaPier(
    id: 'dia-padre',
    nombre: 'Día del Padre',
    colores: PaletaPier(
      verde: Color(0xFF2563EB),
      verdeOscuro: Color(0xFF1E40AF),
      verdeClaro: Color(0xFF60A5FA),
      dorado: Color(0xFFB08D57),
      doradoOscuro: Color(0xFF8F6F3F),
      doradoClaro: Color(0xFFD3B787),
      arena: Color(0xFFF4F6FA),
      arenaOscuro: Color(0xFFE6EAF2),
    ),
    fechas: RangoFechas(6, 8, 6, 22),
  ),
  TemaPier(
    id: 'fiestas-patrias',
    nombre: 'Fiestas Patrias',
    colores: PaletaPier(
      verde: Color(0xFF15803D),
      verdeOscuro: Color(0xFF14532D),
      verdeClaro: Color(0xFF4ADE80),
      dorado: Color(0xFFC8952C),
      doradoOscuro: Color(0xFFA5761C),
      doradoClaro: Color(0xFFE0B45C),
      arena: Color(0xFFF7F3EC),
      arenaOscuro: Color(0xFFECE4D6),
    ),
    fechas: RangoFechas(9, 1, 9, 30),
  ),
  TemaPier(
    id: 'xantolo',
    nombre: 'Xantolo (Día de Muertos)',
    colores: PaletaPier(
      verde: Color(0xFF7B2CBF),
      verdeOscuro: Color(0xFF5A189A),
      verdeClaro: Color(0xFF9D4EDD),
      dorado: Color(0xFFF77F00),
      doradoOscuro: Color(0xFFD96800),
      doradoClaro: Color(0xFFFCA311),
      arena: Color(0xFFFDF6EC),
      arenaOscuro: Color(0xFFF3E6D1),
    ),
    fechas: RangoFechas(10, 20, 11, 3),
  ),
  TemaPier(
    id: 'navidad',
    nombre: 'Navidad',
    colores: PaletaPier(
      verde: Color(0xFF166534),
      verdeOscuro: Color(0xFF14532D),
      verdeClaro: Color(0xFF22863A),
      dorado: Color(0xFFD4AF37),
      doradoOscuro: Color(0xFFB8952C),
      doradoClaro: Color(0xFFE6CB6E),
      arena: Color(0xFFF8F5F0),
      arenaOscuro: Color(0xFFECE5DA),
    ),
    fechas: RangoFechas(12, 1, 12, 26),
  ),
  TemaPier(
    id: 'primavera',
    nombre: 'Primavera',
    colores: PaletaPier(
      verde: Color(0xFF16A34A),
      verdeOscuro: Color(0xFF15803D),
      verdeClaro: Color(0xFF4ADE80),
      dorado: Color(0xFFE9A8C9),
      doradoOscuro: Color(0xFFCF7FAE),
      doradoClaro: Color(0xFFF4C9E0),
      arena: Color(0xFFF0FDF4),
      arenaOscuro: Color(0xFFDCF5E3),
    ),
    fechas: RangoFechas(3, 16, 4, 30),
  ),
  TemaPier(
    id: 'verano',
    nombre: 'Verano',
    colores: PaletaPier(
      verde: Color(0xFF0D9488),
      verdeOscuro: Color(0xFF0F766E),
      verdeClaro: Color(0xFF2DD4BF),
      dorado: Color(0xFFF59E0B),
      doradoOscuro: Color(0xFFD97706),
      doradoClaro: Color(0xFFFBBF24),
      arena: Color(0xFFFDFBEF),
      arenaOscuro: Color(0xFFF6F0DA),
    ),
    fechas: RangoFechas(7, 1, 8, 31),
  ),
  TemaPier(
    id: 'invierno',
    nombre: 'Invierno',
    colores: PaletaPier(
      verde: Color(0xFF0E7490),
      verdeOscuro: Color(0xFF155E75),
      verdeClaro: Color(0xFF38BDF8),
      dorado: Color(0xFF8FA8BF),
      doradoOscuro: Color(0xFF6D8AA5),
      doradoClaro: Color(0xFFB8CBDC),
      arena: Color(0xFFF3F7FA),
      arenaOscuro: Color(0xFFE3ECF2),
    ),
    fechas: RangoFechas(12, 27, 1, 31),
  ),
  temaNormal,
];

TemaPier? temaPorId(String id) {
  for (final t in catalogoTemas) {
    if (t.id == id) return t;
  }
  return null;
}

/// Tema que corresponde a la fecha según el calendario (modo automático).
TemaPier temaPorFecha([DateTime? fecha]) {
  final f = fecha ?? DateTime.now();
  for (final t in catalogoTemas) {
    if (t.fechas != null && t.fechas!.contiene(f)) return t;
  }
  return temaNormal;
}
