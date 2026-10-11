// lib/ui/core/ui/movimiento/monto_animado.dart
//
// Monto que cuenta hasta su nuevo valor cuando cambia (nunca al montarse).
// El texto final es EXACTAMENTE `formato(valor)`: el último cuadro pinta el
// valor recibido, no el resultado de una interpolación. Los lectores de
// pantalla siempre leen el valor final.
import 'package:flutter/material.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class MontoAnimado extends StatefulWidget {
  const MontoAnimado({
    required this.valor,
    required this.formato,
    this.estilo,
    this.alineacionTexto,
    this.duracion = AppMovimiento.conteo,
    super.key,
  });

  final double valor;

  /// El mismo formato que la pantalla usa hoy, p. ej.
  /// `(v) => '\$${v.toStringAsFixed(0)} MXN'`.
  final String Function(double valor) formato;

  final TextStyle? estilo;
  final TextAlign? alineacionTexto;

  /// Máximo 450 ms (las pruebas del carrito asientan en 600 ms).
  final Duration duracion;

  @override
  State<MontoAnimado> createState() => _MontoAnimadoState();
}

class _MontoAnimadoState extends State<MontoAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control;
  late final CurvedAnimation _curva;
  late double _desde = widget.valor;

  @override
  void initState() {
    super.initState();
    _control = AnimationController(vsync: this, duration: widget.duracion);
    _curva = CurvedAnimation(
      parent: _control,
      curve: AppMovimiento.curvaEstandar,
    );
  }

  // Lo que se ve ahora rumbo a [hasta].
  double _mostrado(double hasta) =>
      _control.isAnimating ? _desde + (hasta - _desde) * _curva.value : hasta;

  @override
  void didUpdateWidget(MontoAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    _control.duration = widget.duracion;
    if (oldWidget.valor == widget.valor) return;
    // Si un conteo quedó a medias, el nuevo sigue desde lo que se ve.
    _desde = _mostrado(oldWidget.valor);
    // Oculto (pestaña o ruta tapada) o con movimiento reducido: salta.
    if (AppMovimiento.reducido(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _control.value = 1;
      return;
    }
    _control.forward(from: 0).ignore();
  }

  @override
  void dispose() {
    _curva.dispose();
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = widget.formato(widget.valor);
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _control,
        builder: (context, _) => Text(
          _control.isAnimating
              ? widget.formato(_mostrado(widget.valor))
              : texto,
          style: widget.estilo,
          textAlign: widget.alineacionTexto,
        ),
      ),
    );
  }
}
