// lib/ui/core/ui/movimiento/foto_producto_hero.dart
//
// La foto del producto vuela de la tarjeta al detalle (y de regreso, también
// con el gesto de regresar de iOS). El vuelo pinta SIEMPRE la foto de la
// tarjeta, con fotoDeTarjeta: la reducida que la tarjeta ya pintó, o sea la
// misma entrada de caché; redondea o endereza sus esquinas en el camino.
// Nunca vuela la galería del detalle, cuya primera foto es la completa y
// puede estar aún sin descargar. Mientras vuela, la tarjeta deja un hueco
// color arena en lugar de un hoyo blanco.
//
// Funciona porque MainScreen da un HeroController a cada pestaña. Con
// movimiento reducido no hay vuelo (push normal).
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';

class FotoProductoHero extends StatelessWidget {
  const FotoProductoHero({
    required this.productoId,
    required this.imagenUrl,
    required this.child,
    this.radio = BorderRadius.zero,
    this.ambito,
    this.marcador = true,
    super.key,
  });

  final Object productoId;

  /// La URL de la foto principal (`producto.imagenUrl`), en ambos extremos.
  final String imagenUrl;

  /// Lo que se ve en reposo (la imagen de la tarjeta o la galería). La
  /// tarjeta pinta su foto con `fotoDeTarjeta(imagenUrl)`, igual que el
  /// vuelo: así este sale con la foto desde el primer cuadro.
  final Widget child;

  /// Esquinas de la foto en ESTE extremo: tarjeta de cuadrícula
  /// `BorderRadius.vertical(top: Radius.circular(20))`, galería cero.
  final BorderRadius radio;

  /// Para pantallas donde un producto puede repetirse (Inicio): cambia la
  /// etiqueta a `producto-img-<ambito>-<id>`. El otro extremo debe usar el
  /// mismo ámbito.
  final String? ambito;

  /// true deja un hueco arena en este extremo mientras la foto vuela (las
  /// tarjetas). La galería del detalle usa false.
  final bool marcador;

  /// Etiqueta del Hero: `producto-img-<id>` (la de siempre) o, con ámbito,
  /// `producto-img-<ambito>-<id>`.
  static String etiqueta(Object productoId, {String? ambito}) => ambito == null
      ? 'producto-img-$productoId'
      : 'producto-img-$ambito-$productoId';

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: !AppMovimiento.reducido(context),
      child: Hero(
        tag: etiqueta(productoId, ambito: ambito),
        // La misma curva de la página: foto y página llegan juntas.
        curve: AppMovimiento.curvaPagina,
        transitionOnUserGestures: true,
        flightShuttleBuilder: _vuelo,
        placeholderBuilder: marcador ? _hueco : null,
        child: child,
      ),
    );
  }

  static Widget _hueco(BuildContext context, Size tamano, Widget hijo) =>
      SizedBox.fromSize(
        size: tamano,
        child: ColoredBox(color: AppColors.pierArena),
      );

  Widget _vuelo(
    BuildContext contextoVuelo,
    Animation<double> animacion,
    HeroFlightDirection direccion,
    BuildContext desde,
    BuildContext hacia,
  ) {
    // En push y en pop la animación vale 0 en la ruta de abajo (la tarjeta)
    // y 1 en la de arriba (el detalle).
    final empuje = direccion == HeroFlightDirection.push;
    final abajo = (empuje ? desde : hacia)
        .findAncestorWidgetOfExactType<FotoProductoHero>();
    final arriba = (empuje ? hacia : desde)
        .findAncestorWidgetOfExactType<FotoProductoHero>();
    final radioAbajo = abajo?.radio ?? BorderRadius.zero;
    final radioArriba = arriba?.radio ?? BorderRadius.zero;
    final url = abajo?.imagenUrl ?? imagenUrl;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animacion,
        child: _FotoEnVuelo(url: url),
        builder: (context, foto) => ClipRRect(
          borderRadius: BorderRadius.lerp(
            radioAbajo,
            radioArriba,
            animacion.value,
          )!,
          child: foto,
        ),
      ),
    );
  }
}

class _FotoEnVuelo extends StatelessWidget {
  const _FotoEnVuelo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final arena = ColoredBox(color: AppColors.pierArena);
    if (url.isEmpty) return arena;
    return Image(
      image: fotoDeTarjeta(url),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => arena,
    );
  }
}
