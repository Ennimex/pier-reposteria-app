// lib/ui/core/ui/animated_indexed_stack.dart
//
// IndexedStack con transición al cambiar de índice: fade + deslizamiento
// horizontal sutil en la dirección del cambio de pestaña (derecha si vas a
// un índice mayor, izquierda si vas a uno menor).
//
// A diferencia de AnimatedSwitcher/PageView, conserva el IndexedStack por
// dentro: las pestañas NO se reconstruyen al cambiar (mantienen su estado,
// sus Navigators anidados y no re-disparan fetches).
import 'package:flutter/material.dart';

class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  /// Si se define, deslizar horizontalmente (fling) pide cambiar de pestaña:
  /// hacia la izquierda = índice siguiente, hacia la derecha = anterior (ya
  /// acotado a los límites; el padre solo actualiza su índice). Los scrolls
  /// horizontales internos (carruseles, listas de productos) ganan el gesto
  /// donde existan, igual que en cualquier app.
  final ValueChanged<int>? onSwipeToIndex;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 260),
    this.onSwipeToIndex,
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1, // sin animación en el primer build
    );
    _configurarAnimaciones(1);
  }

  void _configurarAnimaciones(int direccion) {
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0.04 * direccion, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _configurarAnimaciones(widget.index > oldWidget.index ? 1 : -1);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails d) {
    final vx = d.primaryVelocity ?? 0;
    if (vx.abs() < 300) return; // umbral: solo flings claros, no roces
    final destino = vx < 0 ? widget.index + 1 : widget.index - 1;
    if (destino < 0 || destino >= widget.children.length) return;
    widget.onSwipeToIndex!(destino);
  }

  @override
  Widget build(BuildContext context) {
    final contenido = FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: widget.index,
          children: widget.children,
        ),
      ),
    );
    if (widget.onSwipeToIndex == null) return contenido;
    return GestureDetector(
      onHorizontalDragEnd: _onDragEnd,
      child: contenido,
    );
  }
}
