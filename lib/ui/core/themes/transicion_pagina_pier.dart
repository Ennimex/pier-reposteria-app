// lib/ui/core/themes/transicion_pagina_pier.dart
//
// Push de Pier: el mismo deslizamiento de Cupertino (sombra en el borde,
// parallax de la página de abajo y, en iOS, regresar deslizando desde el
// borde), pero en 400 ms en lugar de 500. AppTheme lo usa en Android e iOS,
// así que vale para todos los Navigator.push de la app, también en los
// Navigators de las pestañas.
import 'package:flutter/cupertino.dart';
import 'package:pier_pasteleria/ui/core/themes/app_movimiento.dart';

class TransicionPaginaPier extends PageTransitionsBuilder {
  const TransicionPaginaPier();

  // MaterialPageRoute toma su duración del builder del tema
  // (MaterialRouteTransitionMixin.transitionDuration).
  @override
  Duration get transitionDuration => AppMovimiento.empuje;

  // La ruta de abajo se desplaza con el parallax de Cupertino; también las
  // páginas raíz de go_router (paginaRaiz), que lo reciben como
  // delegatedTransition cuando se apila un MaterialPageRoute encima.
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => CupertinoRouteTransitionMixin.buildPageTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}
