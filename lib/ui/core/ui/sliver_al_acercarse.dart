// lib/ui/core/ui/sliver_al_acercarse.dart
//
// Un sliver que no arma su contenido hasta que el scroll lo acerca.
//
// Lo que queda lejos de la pantalla (la tercera publicación del Inicio, por
// ejemplo) no hace falta todavía, y armarlo junto con lo que sí se ve alarga
// ese cuadro (#341). Mientras empieza más allá de la pantalla y de la franja
// que la lista prepara por adelantado, este sliver solo aparta un alto. En
// cuanto queda cerca arma su contenido y se queda con él, aunque el scroll lo
// vuelva a alejar: conserva su estado como cualquier otro sliver.
import 'package:flutter/widgets.dart';

class SliverAlAcercarse extends StatefulWidget {
  const SliverAlAcercarse({
    required this.child,
    this.altoApartado = 300,
    super.key,
  });

  /// Lo que se arma al acercarse (una caja, no un sliver).
  final Widget child;

  /// Alto que se aparta mientras el contenido no se arma. Si fuera cero, lo
  /// que sigue quedaría igual de cerca y se armaría junto.
  final double altoApartado;

  @override
  State<SliverAlAcercarse> createState() => _SliverAlAcercarseState();
}

class _SliverAlAcercarseState extends State<SliverAlAcercarse> {
  // Ya estuvo cerca de la pantalla.
  bool _armado = false;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, medidas) {
      if (medidas.remainingCacheExtent > 0) _armado = true;
      return SliverToBoxAdapter(
        child: _armado ? widget.child : SizedBox(height: widget.altoApartado),
      );
    },
  );
}
