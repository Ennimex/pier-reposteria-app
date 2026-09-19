// lib/ui/repartidor/widgets/repartidor_ui.dart
//
// Piezas de UI compartidas del módulo Repartidor (chips de estado, formato).
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';

/// Formatea un monto a "$1,250 MXN" (sin decimales, con separador de miles).
String formatMoneyMxn(double value) {
  final entero = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) buf.write(',');
    buf.write(entero[i]);
  }
  return '\$$buf MXN';
}

/// Formatea una hora local a "10:30 AM".
String formatHora(DateTime dt) {
  final h24 = dt.hour;
  final ampm = h24 < 12 ? 'AM' : 'PM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}

/// Formatea el `horario_entrega` del backend (que puede llegar como timestamp
/// ISO tipo "2026-07-05T09:00:00.000Z") a algo legible: "5 jul · 9:00 AM".
/// Si no es una fecha parseable, devuelve el texto tal cual. Preserva la hora
/// escrita (no convierte de zona horaria) para no desfasar el horario elegido.
String formatHorarioEntrega(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return 'Sin horario';
  final dt = DateTime.tryParse(t);
  if (dt == null) return t;
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${dt.day} ${meses[dt.month - 1]} · ${formatHora(dt)}';
}

/// Chip de estado de una entrega, con punto de color.
class EstadoEntregaChip extends StatelessWidget {
  final EstadoEntrega estado;
  const EstadoEntregaChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = estado.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            estado.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color == const Color(0xFF5B7BA5) ? color : _darken(color),
            ),
          ),
        ],
      ),
    );
  }

  // Oscurece ligeramente para asegurar contraste del texto sobre el fondo tenue.
  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
  }
}

/// Avatar circular con iniciales.
class InicialesAvatar extends StatelessWidget {
  final String iniciales;
  final double size;
  final Color background;
  final Color foreground;

  const InicialesAvatar({
    super.key,
    required this.iniciales,
    this.size = 48,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        iniciales,
        style: TextStyle(
          fontFamily: 'Playfair Display',
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}
