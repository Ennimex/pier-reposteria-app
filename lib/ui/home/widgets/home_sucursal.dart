// lib/ui/home/widgets/home_sucursal.dart
//
// "Encuéntranos": una tarjeta por sucursal cuando la configuración de
// contacto trae al menos 2 (como la web); si no, la tarjeta única con la
// dirección y el horario generales. Tocar una tarjeta abre Contacto.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/public/widgets/contact_screen.dart';
import 'package:pier_pasteleria/utils/config_format.dart';

/// Sección de sucursales del inicio.
class HomeSucursal extends StatelessWidget {
  const HomeSucursal({
    required this.contacto,
    required this.sucursales,
    super.key,
  });

  /// Config de la sección contacto.
  final Map<String, dynamic> contacto;

  /// Sucursales con nombre (0 o 2).
  final List<Map<String, dynamic>> sucursales;

  @override
  Widget build(BuildContext context) {
    final direccion = formatearDireccion(contacto['direccion'],
        fallback: BusinessInfo.direccion);
    final horario = formatearHorario(contacto['horarios'],
        fallback: BusinessInfo.horario);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Encuéntranos',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (sucursales.isEmpty)
            _TarjetaSucursal(
              color: AppColors.pierVerdeOscuro,
              encabezado: _FilaIcono(
                icono: LucideIcons.store,
                titulo: BusinessInfo.sucursal,
                texto: direccion,
                conFlecha: true,
              ),
              detalle: [
                _FilaIcono(
                    icono: LucideIcons.clock, titulo: 'Horario', texto: horario),
              ],
            )
          else
            for (var i = 0; i < sucursales.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _tarjetaDeSucursal(sucursales[i], i, direccion),
            ],
        ],
      ),
    );
  }

  /// Tarjeta por sucursal (Repostería / Cafetería), espejo de las
  /// SucursalCard de la web. La 1a en verde, la 2a en dorado oscuro.
  Widget _tarjetaDeSucursal(
      Map<String, dynamic> s, int indice, String direccion) {
    final nombre = s['sucursal']?.toString() ?? '';
    final descripcion = s['descripcion']?.toString() ?? '';
    final horario = s['horario']?.toString() ?? '';
    final lower = nombre.toLowerCase();
    final esCafe = lower.contains('café') || lower.contains('cafe');
    final suave = Colors.white.withValues(alpha: 0.75);

    return _TarjetaSucursal(
      color: indice == 0 ? AppColors.pierVerdeOscuro : AppColors.pierDoradoOscuro,
      encabezado: _FilaIcono(
        icono: esCafe ? LucideIcons.coffee : LucideIcons.cake,
        titulo: nombre,
        texto: descripcion,
        unaLinea: true,
        conFlecha: true,
      ),
      detalle: [
        Row(children: [
          Icon(LucideIcons.mapPin, color: suave, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(direccion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: suave, fontSize: 12)),
          ),
        ]),
        if (horario.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(LucideIcons.clock, color: suave, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(horario,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ]),
        ],
      ],
    );
  }
}

/// Marco de color con sombra: encabezado, divisor y detalle.
class _TarjetaSucursal extends StatelessWidget {
  const _TarjetaSucursal({
    required this.color,
    required this.encabezado,
    required this.detalle,
  });

  final Color color;
  final Widget encabezado;
  final List<Widget> detalle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const ContactScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            encabezado,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.15), height: 1),
            ),
            ...detalle,
          ],
        ),
      ),
    );
  }
}

/// Ícono en caja, título en negritas y texto suave; opcionalmente con la
/// flecha de "abrir" a la derecha.
class _FilaIcono extends StatelessWidget {
  const _FilaIcono({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.unaLinea = false,
    this.conFlecha = false,
  });

  final IconData icono;
  final String titulo;

  /// Vacío = solo el título.
  final String texto;
  final bool unaLinea;
  final bool conFlecha;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icono, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(texto,
                  maxLines: unaLinea ? 1 : null,
                  overflow: unaLinea ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12)),
            ],
          ],
        ),
      ),
      if (conFlecha)
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.chevronRight,
              color: Colors.white, size: 20),
        ),
    ]);
  }
}
