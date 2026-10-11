// lib/ui/core/ui/movimiento/icono_pestana.dart
//
// Ícono activo de la barra inferior (activeIcon): al seleccionarse la
// pestaña, una píldora suave crece detrás del ícono y el ícono da un pop.
// BottomNavigationBar construye `activeIcon` solo para la pestaña elegida,
// así que el estado nace en cada selección (tap, fling o desde otra
// pantalla) y la animación corre una vez; reconstruir la barra no la repite.
//
// La píldora se pinta fuera de la caja del ícono: la barra no cambia de
// alto y las etiquetas (con las que las pruebas encuentran las pestañas) no
// se mueven. Su color sale del IconTheme de la barra (sigue la paleta).
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class IconoPestana extends StatefulWidget {
  const IconoPestana(this.icono, {super.key});

  final IconData icono;

  @override
  State<IconoPestana> createState() => _IconoPestanaState();
}

class _IconoPestanaState extends State<IconoPestana>
    with SingleTickerProviderStateMixin {
  static const double _anchoPildora = 52;
  static const double _altoPildora = 28;

  static final Animatable<double> _crecer = CurveTween(
    curve: const Interval(0, 0.85, curve: AppMovimiento.curvaEnfasis),
  );
  static final Animatable<double> _aparecer = CurveTween(
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );
  static final Animatable<double> _pop = Tween<double>(
    begin: 0.82,
    end: 1,
  ).chain(CurveTween(curve: AppMovimiento.curvaRebote));

  late final AnimationController _control;
  bool _iniciado = false;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, duration: AppMovimiento.media);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (AppMovimiento.reducido(context)) {
      _control.value = 1;
    } else {
      _control.forward().ignore();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final color = tema.color ?? Colors.grey;
    final tamano = tema.size ?? 24;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: OverflowBox(
            maxWidth: _anchoPildora,
            maxHeight: _altoPildora,
            child: FadeTransition(
              opacity: _control.drive(_aparecer),
              child: AnimatedBuilder(
                animation: _control,
                builder: (context, _) => SizedBox(
                  width:
                      tamano +
                      (_anchoPildora - tamano) * _crecer.evaluate(_control),
                  height: _altoPildora,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(_altoPildora / 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ScaleTransition(
          scale: _control.drive(_pop),
          child: Icon(widget.icono),
        ),
      ],
    );
  }
}
