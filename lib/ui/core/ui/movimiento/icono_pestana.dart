// lib/ui/core/ui/movimiento/icono_pestana.dart
//
// Ícono de la barra inferior: al elegirse la pestaña, una píldora suave
// crece detrás del ícono y el ícono da un pop; al dejarse, la píldora se
// encoge y se apaga (sin pop). Se usa en las dos ranuras del
// BottomNavigationBarItem: `icon: IconoPestana(i, activo: false)` y
// `activeIcon: IconoPestana(i)`. La barra pone una u otra en el mismo
// lugar y, como son del mismo tipo, el estado se conserva y anima los dos
// sentidos. Montarse elegido (la barra recién creada, o IconoPestana solo en
// activeIcon) también anima, una vez; reconstruir la barra no la repite.
//
// La píldora se pinta fuera de la caja del ícono: la barra no cambia de
// alto y las etiquetas (con las que las pruebas encuentran las pestañas) no
// se mueven. Su color sale del IconTheme de la barra (sigue la paleta).
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';

class IconoPestana extends StatefulWidget {
  const IconoPestana(this.icono, {this.activo = true, super.key});

  final IconData icono;

  /// Si la pestaña está elegida: false en `icon` y true en `activeIcon`.
  final bool activo;

  @override
  State<IconoPestana> createState() => _IconoPestanaState();
}

class _IconoPestanaState extends State<IconoPestana>
    with TickerProviderStateMixin {
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

  // La píldora va y viene; el pop del ícono solo corre al elegirse (en
  // reposo vale 1: el ícono de una pestaña sin elegir no se ve encogido).
  late final AnimationController _pildora;
  late final AnimationController _salto;
  bool _iniciado = false;

  @override
  void initState() {
    super.initState();
    _pildora = AnimationController(
      vsync: this,
      duration: AppMovimiento.media,
      reverseDuration: AppMovimiento.corta,
    );
    _salto = AnimationController(
      vsync: this,
      duration: AppMovimiento.media,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (widget.activo) _animar(elegida: true);
  }

  @override
  void didUpdateWidget(IconoPestana oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activo != widget.activo) _animar(elegida: widget.activo);
  }

  void _animar({required bool elegida}) {
    if (AppMovimiento.reducido(context)) {
      _pildora.value = elegida ? 1 : 0;
      _salto.value = 1;
    } else if (elegida) {
      _pildora.forward().ignore();
      _salto.forward(from: 0).ignore();
    } else {
      _pildora.reverse().ignore();
    }
  }

  @override
  void dispose() {
    _pildora.dispose();
    _salto.dispose();
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
              opacity: _pildora.drive(_aparecer),
              child: AnimatedBuilder(
                animation: _pildora,
                builder: (context, _) => SizedBox(
                  width:
                      tamano +
                      (_anchoPildora - tamano) * _crecer.evaluate(_pildora),
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
          scale: _salto.drive(_pop),
          child: Icon(widget.icono),
        ),
      ],
    );
  }
}
