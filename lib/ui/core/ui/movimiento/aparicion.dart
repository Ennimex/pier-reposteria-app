// lib/ui/core/ui/movimiento/aparicion.dart
//
// Presencia con tamaño: algo que aparece o desaparece sin que lo de abajo
// salte. Al mostrarse, el hijo entra al árbol en ese mismo cuadro (los
// finders ya lo ven), el espacio se abre y el contenido aparece con un
// fundido. Al ocultarse, el contenido se apaga y SALE del árbol; luego se
// cierra el espacio. Se apoya en AnimatedSize, que recorta solo mientras
// crece (en reposo no recorta sombras).
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class Aparicion extends StatefulWidget {
  const Aparicion({
    required this.visible,
    required this.child,
    this.duracion = AppMovimiento.corta,
    this.alineacion = AlignmentDirectional.topStart,
    super.key,
  });

  final bool visible;
  final Widget child;
  final Duration duracion;

  /// Desde dónde se abre el espacio (arriba-inicio por defecto).
  final AlignmentGeometry alineacion;

  @override
  State<Aparicion> createState() => _AparicionState();
}

class _AparicionState extends State<Aparicion>
    with SingleTickerProviderStateMixin {
  // Fundido del contenido: entra en la segunda parte de la apertura y se
  // apaga rápido al ocultarse (después el espacio se cierra ya vacío).
  late final AnimationController _control;
  late final CurvedAnimation _opacidad;

  // Si el hijo está en el árbol (visible o apagándose).
  late bool _presente = widget.visible;
  bool _reducido = false;

  // Se crean aquí y no de forma perezosa: dispose() nunca debe crearlos.
  @override
  void initState() {
    super.initState();
    _control = AnimationController(
      vsync: this,
      duration: widget.duracion,
      reverseDuration: widget.duracion * 0.4,
      value: widget.visible ? 1 : 0,
    )..addStatusListener(_alCambiarEstado);
    _opacidad = CurvedAnimation(
      parent: _control,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = AppMovimiento.reducido(context);
  }

  @override
  void didUpdateWidget(Aparicion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _control
      ..duration = widget.duracion
      ..reverseDuration = widget.duracion * 0.4;
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      _presente = true;
      if (_reducido) {
        _control.value = 1;
      } else {
        _control.forward().ignore();
      }
    } else if (_reducido) {
      _presente = false;
      _control.value = 0;
    } else {
      _control.reverse().ignore();
    }
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.dismissed && !widget.visible && _presente) {
      setState(() => _presente = false);
    }
  }

  @override
  void dispose() {
    _opacidad.dispose();
    _control.dispose();
    super.dispose();
  }

  // AnimatedSize no acepta duración cero (se reprograma a mitad del layout):
  // «instantáneo» es un milisegundo, que se resuelve en el cuadro siguiente.
  static const Duration _instante = Duration(milliseconds: 1);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _reducido || widget.duracion < _instante
          ? _instante
          : widget.duracion,
      curve: AppMovimiento.curvaEnfasis,
      alignment: widget.alineacion,
      child: _presente
          ? FadeTransition(opacity: _opacidad, child: widget.child)
          : const SizedBox.shrink(),
    );
  }
}
