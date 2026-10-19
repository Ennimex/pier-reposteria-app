// lib/ui/core/ui/movimiento/rutas.dart
//
// Transiciones de ruta que no son un push normal:
//
// * paginaRaiz: páginas de go_router a las que se llega con context.go
//   (splash → inicio, login → inicio, registro → verificar, cerrar sesión →
//   login). Un cambio de contexto no es «ir más adentro», así que en vez del
//   deslizamiento lateral es un fundido a través de la arena: el contenido
//   anterior se disuelve en arena y el nuevo aparece con una escala corta.
//   (go_router deja la página anterior debajo hasta que la nueva termina de
//   entrar —Navigator solo la quita cuando la de arriba queda quieta—, así
//   que nunca se ve un lienzo vacío).
//
// * RutaCelebracion: checkout → «¡Pedido confirmado!». Un fondo opaco tapa
//   el checkout AL INSTANTE (ya se redibujó con el carrito vacío) y la
//   página de éxito florece encima.
//
// Las dos funcionan sin AppTheme (colores explícitos) y no crean
// CurvedAnimation en el transitionsBuilder (corre en cada cuadro): solo
// animation.drive con Animatables estáticos.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/themes/app_movimiento.dart';

/// Página para una ruta de go_router a la que se llega con context.go.
///
/// Conserva lo que go_router pone en sus páginas de siempre (key, nombre,
/// argumentos y restorationId); sin la key, go reutilizaría la página.
/// [fondo] es el color a través del cual se funde (arena de la paleta activa
/// si no se da).
CustomTransitionPage<void> paginaRaiz(
  GoRouterState estado,
  Widget pantalla, {
  Color? fondo,
}) {
  return CustomTransitionPage<void>(
    key: estado.pageKey,
    name: estado.name ?? estado.path,
    arguments: <String, String>{
      ...estado.pathParameters,
      ...estado.uri.queryParameters,
    },
    restorationId: estado.pageKey.value,
    transitionDuration: AppMovimiento.raiz,
    reverseTransitionDuration: AppMovimiento.corta,
    // Se ignora la animación secundaria: si encima se empuja un
    // MaterialPageRoute (Registro sobre /login), Cupertino desplaza esta
    // página con su delegatedTransition, igual que siempre.
    transitionsBuilder: (context, animacion, _, hijo) => _fundirAtraves(
      context: context,
      animacion: animacion,
      fondo: fondo ?? AppColors.pierArena,
      pagina: hijo,
    ),
    child: pantalla,
  );
}

/// Ruta de la pantalla de éxito del pago. Se usa con
/// `Navigator.pushReplacement(context, RutaCelebracion<void>(builder: ...))`:
/// mismo destino y misma semántica que el MaterialPageRoute de antes.
class RutaCelebracion<T> extends PageRouteBuilder<T> {
  RutaCelebracion({
    required WidgetBuilder builder,
    Color fondo = Colors.white,
    super.settings,
  }) : super(
         transitionDuration: AppMovimiento.enfasis,
         reverseTransitionDuration: AppMovimiento.corta,
         pageBuilder: (context, _, _) => builder(context),
         transitionsBuilder: (context, animacion, _, hijo) => _florecer(
           context: context,
           animacion: animacion,
           fondo: fondo,
           pagina: hijo,
         ),
       );
}

// Fundido a través: hasta el 30 % la arena tapa lo anterior; desde ahí la
// página nueva aparece y se asienta de 0.96 a 1.
const double _corte = 0.3;

final Animatable<double> _fondoRaiz = CurveTween(
  curve: const Interval(0, _corte, curve: Curves.easeIn),
);

final Animatable<double> _opacidadRaiz = CurveTween(
  curve: const Interval(_corte, 1, curve: Curves.easeOut),
);

final Animatable<double> _escalaRaiz =
    Tween<double>(
      begin: 0.96,
      end: 1,
    ).chain(
      CurveTween(
        curve: const Interval(_corte, 1, curve: AppMovimiento.curvaEnfasis),
      ),
    );

final Animatable<double> _escalaCelebracion = Tween<double>(
  begin: 0.92,
  end: 1,
).chain(CurveTween(curve: AppMovimiento.curvaEnfasis));

// El blanco tapa un instante y luego deja florecer la página.
final Animatable<double> _veloCelebracion = Tween<double>(
  begin: 1,
  end: 0,
).chain(CurveTween(curve: const Interval(0.12, 0.6, curve: Curves.easeOut)));

/// Fundido a través de [fondo] para las páginas raíz: el fondo aparece sobre
/// la página anterior y luego la nueva se revela encima. Al reproducirse al
/// revés (pop) hace lo mismo hacia atrás. Mientras la página está en 0 no se
/// pinta y en 1 no crea capa: solo el tramo intermedio usa opacidad.
Widget _fundirAtraves({
  required BuildContext context,
  required Animation<double> animacion,
  required Color fondo,
  required Widget pagina,
}) {
  return Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: FadeTransition(
            opacity: animacion.drive(_fondoRaiz),
            child: ColoredBox(color: fondo),
          ),
        ),
      ),
      FadeTransition(
        opacity: animacion.drive(_opacidadRaiz),
        child: ScaleTransition(
          // Con movimiento reducido no hay escala: solo el fundido.
          scale: AppMovimiento.reducido(context)
              ? kAlwaysCompleteAnimation
              : animacion.drive(_escalaRaiz),
          child: pagina,
        ),
      ),
    ],
  );
}

/// Fondo opaco desde el primer cuadro (tapa el checkout ya vacío), la página
/// escalando hacia 1 y un velo del mismo color que se disuelve encima (un
/// solo rectángulo: más barato que desvanecer la página completa). Al
/// quitarse la ruta, todo se desvanece y deja ver la de abajo. El árbol es
/// siempre el mismo.
Widget _florecer({
  required BuildContext context,
  required Animation<double> animacion,
  required Color fondo,
  required Widget pagina,
}) {
  final saliendo = animacion.status == AnimationStatus.reverse;
  return FadeTransition(
    opacity: saliendo ? animacion : kAlwaysCompleteAnimation,
    child: ColoredBox(
      color: fondo,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ScaleTransition(
            // Con movimiento reducido no hay escala: solo el fundido.
            scale: AppMovimiento.reducido(context)
                ? kAlwaysCompleteAnimation
                : animacion.drive(_escalaCelebracion),
            child: pagina,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: animacion.drive(_veloCelebracion),
                child: ColoredBox(color: fondo),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
