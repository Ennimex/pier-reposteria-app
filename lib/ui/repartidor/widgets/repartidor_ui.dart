// lib/ui/repartidor/widgets/repartidor_ui.dart
//
// Piezas de UI compartidas del módulo Repartidor: formato de montos y horas,
// avisos, chip de estado, avatar, ícono con texto, ícono que se vuelve
// indicador de carga y el switch de disponibilidad.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';

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

/// Aviso flotante: verde si [ok], rojo si no.
void mostrarAviso(BuildContext context, String mensaje, {bool ok = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: ok ? AppColors.pierVerde : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Chip de estado de una entrega, con punto de color.
class EstadoEntregaChip extends StatelessWidget {
  const EstadoEntregaChip({required this.estado, super.key});

  final EstadoEntrega estado;

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
  const InicialesAvatar({
    required this.iniciales,
    required this.background,
    required this.foreground,
    super.key,
    this.size = 48,
  });

  final String iniciales;
  final double size;
  final Color background;
  final Color foreground;

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

/// Ícono gris seguido de un texto gris (colonia, horario, hora).
class IconoTexto extends StatelessWidget {
  const IconoTexto({
    required this.icono,
    required this.texto,
    super.key,
    this.tamanoIcono = 16,
    this.tamanoTexto = 14,
    this.separacion = 4,
    this.unaLinea = false,
  });

  final IconData icono;
  final String texto;
  final double tamanoIcono;
  final double tamanoTexto;
  final double separacion;

  /// Corta el texto con «…» en una sola línea.
  final bool unaLinea;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: tamanoIcono, color: AppColors.textSecondary),
        SizedBox(width: separacion),
        Expanded(
          child: Text(
            texto,
            maxLines: unaLinea ? 1 : null,
            overflow: unaLinea ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontSize: tamanoTexto,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// [icono] de un botón; mientras [cargando], un indicador del mismo tamaño.
class IconoCargando extends StatelessWidget {
  const IconoCargando({
    required this.icono,
    required this.cargando,
    super.key,
    this.tamano = 18,
    this.color,
  });

  final IconData icono;
  final bool cargando;
  final double tamano;

  /// Color del indicador (el del tema si es null).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!cargando) return Icon(icono, size: tamano);
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// Switch de disponibilidad del repartidor; avisa si el backend lo rechaza.
class SwitchDisponible extends StatelessWidget {
  const SwitchDisponible({required this.viewModel, super.key});

  final RepartidorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: viewModel.disponible,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.pierVerde,
      onChanged: (v) async {
        final ok = await viewModel.cambiarDisponible(valor: v);
        if (!ok && context.mounted) {
          mostrarAviso(context, 'No se pudo cambiar la disponibilidad');
        }
      },
    );
  }
}
