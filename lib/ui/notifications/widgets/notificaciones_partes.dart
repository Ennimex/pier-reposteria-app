// lib/ui/notifications/widgets/notificaciones_partes.dart
//
// Piezas de «Notificaciones»: la tarjeta de cada aviso (resaltada mientras
// no se lee) y el mensaje a pantalla completa que sirve para la lista vacía y
// para el error de carga.
//
// Movimiento: la tarjeta se hunde al tocarla y, al leerse, todo su resaltado
// se apaga a la vez (fondo, borde, ícono, peso del título) mientras el punto
// se desvanece y cede su espacio; si el backend lo rechaza, regresa igual de
// suave. El mensaje a pantalla completa entra en cascada.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/domain/models/notificacion.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/orders/widgets/movimiento_pedidos.dart';

/// Un aviso: ícono según su tipo, título, mensaje (2 líneas) y [cuando].
class NotificacionTarjeta extends StatelessWidget {
  const NotificacionTarjeta({
    required this.notificacion,
    required this.cuando,
    required this.onTap,
    super.key,
  });

  final Notificacion notificacion;

  /// «Hace 5 min», «Ayer, 6:30 PM»…
  final String cuando;
  final VoidCallback onTap;

  static IconData icono(String tipo) => switch (tipo) {
        'pedido' => LucideIcons.shoppingBag,
        'promocion' => LucideIcons.tag,
        'resena' => Icons.star_outline_rounded,
        'reembolso' => LucideIcons.rotateCcw,
        'producto' => LucideIcons.cake,
        _ => LucideIcons.bell,
      };

  @override
  Widget build(BuildContext context) {
    final leida = notificacion.leida;
    // Fondo, borde, ícono y título cambian con el mismo ritmo.
    final duracion = AppMovimiento.duracion(context, AppMovimiento.corta);
    const curva = AppMovimiento.curvaEstandar;
    return PresionEscala(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: duracion,
          curve: curva,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: leida
                ? Colors.white
                : AppColors.pierVerde.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: leida
                ? null
                : Border.all(color: AppColors.pierVerde.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: duracion,
                curve: curva,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: leida
                      ? AppColors.textSecondary.withValues(alpha: 0.08)
                      : AppColors.pierVerde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                      end: leida
                          ? AppColors.textSecondary.withValues(alpha: 0.5)
                          : AppColors.pierVerde),
                  duration: duracion,
                  curve: curva,
                  builder: (_, color, _) =>
                      Icon(icono(notificacion.tipo), color: color, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _textos(context, duracion)),
              // El punto se apaga, sale del árbol y su espacio se cierra
              // (el texto se acomoda sin brincar); vuelve igual si el
              // backend rechaza la lectura.
              Aparicion(
                visible: !leida,
                alineacion: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Container(
                    key: const ValueKey('punto-no-leida'),
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textos(BuildContext context, Duration duracion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El título pierde (o recupera) el negrito con suavidad.
        AnimatedDefaultTextStyle(
          duration: duracion,
          curve: AppMovimiento.curvaEstandar,
          style: DefaultTextStyle.of(context).style.merge(TextStyle(
              fontWeight: notificacion.leida ? FontWeight.w500 : FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary)),
          child: Text(notificacion.titulo),
        ),
        const SizedBox(height: 4),
        Text(
          notificacion.mensaje,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 6),
        Text(
          cuando,
          style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Mensaje a pantalla completa con un botón: la lista vacía («Explorar
/// Menú») o el error de carga («Reintentar»). Entra en cascada: el círculo
/// con el ícono crece un poco y después el título, el texto y el botón
/// suben (el botón se puede tocar desde el primer cuadro). Con [mecerIcono]
/// el ícono además se mece una vez, como una campana (la lista vacía; el
/// error solo aparece, sin alarmar).
class AvisoNotificaciones extends StatelessWidget {
  const AvisoNotificaciones({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.iconoBoton,
    required this.onPressed,
    this.mecerIcono = false,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final IconData iconoBoton;
  final VoidCallback onPressed;
  final bool mecerIcono;

  // Vaivén de campana que se apaga (en vueltas: ±0.04 ≈ 14°).
  static const Animatable<double> _vaiven = Balanceo();

  @override
  Widget build(BuildContext context) {
    final espera = esperaDeLlegada(context);
    Widget figura = Icon(icono,
        size: 56, color: AppColors.pierVerde.withValues(alpha: 0.45));
    if (mecerIcono) {
      // Cuelga de arriba y se mece cuando el círculo ya terminó de crecer.
      figura = MovimientoUnaVez(
        retraso: espera + AppMovimiento.entrada,
        duracion: AppMovimiento.relleno,
        builder: (context, avance, campana) => RotationTransition(
          turns: avance.drive(_vaiven),
          alignment: Alignment.topCenter,
          child: campana,
        ),
        child: figura,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EntradaSuave(
              retraso: espera,
              escalaInicial: 0.85,
              desplazamiento: Offset.zero,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.pierVerde.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: figura,
              ),
            ),
            const SizedBox(height: 28),
            EntradaSuave(
              orden: 1,
              retraso: espera,
              child: Text(titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 10),
            EntradaSuave(
              orden: 2,
              retraso: espera,
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
            EntradaSuave(
              orden: 3,
              retraso: espera,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(iconoBoton, color: Colors.white, size: 18),
                  label: Text(boton,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pierVerde,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
