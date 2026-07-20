// lib/presentation/widgets/animated_indexed_stack.dart
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

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 260),
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

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(
          index: widget.index,
          children: widget.children,
        ),
      ),
    );
  }
}
