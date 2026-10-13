// lib/ui/core/themes/app_movimiento.dart
//
// Ritmo de movimiento de Pier: duraciones, curvas, distancias y la regla de
// «reducir movimiento». Estático como AppDimensions (no ThemeExtension): las
// pruebas sueltas no montan AppTheme y un cambio de paleta de temporada no
// debe interpolar tokens.
import 'package:flutter/material.dart';

/// Tokens de movimiento de Pier. Ninguna pantalla define sus propias
/// duraciones, curvas o reglas de accesibilidad: todo sale de aquí.
class AppMovimiento {
  AppMovimiento._();

  // ── Duraciones: crecen con la superficie que se mueve ────────────────

  /// Hundir una tarjeta o un botón al tocarlo.
  static const Duration presion = Duration(milliseconds: 100);

  /// Íconos, puntos y salidas rápidas.
  static const Duration rapida = Duration(milliseconds: 150);

  /// Cambios de estado en sitio: CambioAnimado, Aparicion, diálogos.
  static const Duration corta = Duration(milliseconds: 220);

  /// Pestañas y secciones (las pruebas del repartidor revisan a los 400 ms).
  static const Duration media = Duration(milliseconds: 300);

  /// Aparición de un bloque (EntradaSuave).
  static const Duration entrada = Duration(milliseconds: 350);

  /// Cambio de contexto con context.go (las pruebas revisan tras 1 s).
  static const Duration raiz = Duration(milliseconds: 360);

  /// Montos que cuentan hacia su nuevo valor (MontoAnimado).
  static const Duration conteo = Duration(milliseconds: 380);

  /// Push de una página (TransicionPaginaPier).
  static const Duration empuje = Duration(milliseconds: 400);

  /// Pops de íconos e insignias, sacudidas y la ruta de celebración.
  static const Duration enfasis = Duration(milliseconds: 450);

  /// Vuelo de la miniatura al carrito.
  static const Duration vuelo = Duration(milliseconds: 560);

  /// Barras y líneas que se llenan (ProgresoAnimado, BarraRelleno).
  static const Duration relleno = Duration(milliseconds: 600);

  /// Chispas de celebración: lo más largo permitido, nunca en bucle.
  static const Duration celebracion = Duration(milliseconds: 1600);

  // ── Cascadas ─────────────────────────────────────────────────────────

  /// Separación entre escalones de una cascada.
  static const Duration paso = Duration(milliseconds: 50);

  /// Escalones como máximo: del séptimo en adelante entran con el sexto.
  static const int pasosMaximos = 6;

  /// Espera del contenido de una página recién empujada: primero llega la
  /// página y después su contenido.
  static const Duration trasEmpuje = Duration(milliseconds: 150);

  /// Espera del contenido de una pestaña que se abre por primera vez: la
  /// pestaña que entra es transparente hasta el 30 % de [media] (90 ms).
  static const Duration trasPestana = Duration(milliseconds: 90);

  /// Espera del contenido de una página a la que se llega con context.go:
  /// paginaRaiz la deja transparente hasta el 30 % de [raiz] (108 ms).
  static const Duration trasRaiz = Duration(milliseconds: 110);

  // ── Distancias en dp (se ven igual en cualquier ancho) ───────────────

  static const double distanciaCorta = 8;
  static const double distancia = 16;
  static const double distanciaLarga = 24;

  // ── Escalas ──────────────────────────────────────────────────────────

  /// Tarjetas al presionarlas.
  static const double escalaPresion = 0.97;

  /// Controles redondos y chips al presionarlos.
  static const double escalaPresionChica = 0.92;

  // ── Curvas ───────────────────────────────────────────────────────────

  /// Lo que entra: desacelera (la curva de la casa).
  static const Curve curvaEntrada = Curves.easeOutCubic;

  /// Lo que sale: acelera.
  static const Curve curvaSalida = Curves.easeInCubic;

  /// Superficies que llegan (páginas, hojas, pestañas).
  static const Curve curvaEnfasis = Easing.emphasizedDecelerate;

  /// Superficies que se van, lista para usarse como reverseCurve: ya va
  /// volteada, así que al reproducirse hacia atrás arranca lento y termina
  /// rápido (acelera al salir, como pide Material 3).
  static const Curve curvaEnfasisSalida = FlippedCurve(
    Easing.emphasizedAccelerate,
  );

  /// Algo que se mueve de A a B dentro de la pantalla.
  static const Curve curvaEstandar = Easing.standard;

  /// Pops de íconos y chips: se pasa un poco y regresa.
  static const Curve curvaRebote = Curves.easeOutBack;

  /// La misma curva del push de Cupertino: foto y página llegan juntas.
  static const Curve curvaPagina = Curves.fastEaseInToSlowEaseOut;

  /// Hundir, rebotar y asentar para los botones «agregar»: 1 → 0.88 → 1.12
  /// → 1. Siempre termina en 1 (un Tween con elasticOut se queda agrandado).
  static final Animatable<double> pulso = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.88,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 33,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.12,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
    ],
  );

  // ── Accesibilidad ────────────────────────────────────────────────────

  /// Verdadero si el usuario pidió menos movimiento: «Quitar animaciones»
  /// de Android (llega a MediaQuery) o «Reducir movimiento» de iOS (solo
  /// vive en accessibilityFeatures). Con movimiento reducido no hay
  /// desplazamientos ni escalas: a lo más un cambio instantáneo o un fundido
  /// corto. Se lee en build o en didChangeDependencies, nunca en initState.
  static bool reducido(BuildContext context) {
    final funciones = View.maybeOf(
      context,
    )?.platformDispatcher.accessibilityFeatures;
    final sinAnimaciones =
        MediaQuery.maybeDisableAnimationsOf(context) ??
        funciones?.disableAnimations ??
        false;
    return sinAnimaciones || (funciones?.reduceMotion ?? false);
  }

  /// [valor], o cero si el movimiento está reducido.
  static Duration duracion(BuildContext context, Duration valor) =>
      reducido(context) ? Duration.zero : valor;

  /// Retraso del escalón [orden] de una cascada, acotado a [pasosMaximos].
  static Duration retrasoCascada(int orden) =>
      paso * orden.clamp(0, pasosMaximos);

  // ── Estilos para diálogos, hojas y desplegables ──────────────────────

  /// Para `showDialog(animationStyle: ...)`: fundido corto (EntradaDialogo le
  /// suma la escala). Con movimiento reducido queda solo un fundido breve.
  static AnimationStyle estiloDialogo(BuildContext context) =>
      reducido(context) ? _dialogoReducido : _dialogo;

  /// Para `showModalBottomSheet(sheetAnimationStyle: ...)`: la hoja sube con
  /// la curva enfática. Con movimiento reducido aparece sin deslizarse.
  static AnimationStyle estiloHoja(BuildContext context) =>
      reducido(context) ? AnimationStyle.noAnimation : _hoja;

  /// Para `ExpansionTile(expansionAnimationStyle: ...)`.
  static AnimationStyle estiloExpansion(BuildContext context) =>
      reducido(context) ? AnimationStyle.noAnimation : _expansion;

  static const AnimationStyle _dialogo = AnimationStyle(
    duration: corta,
    reverseDuration: rapida,
    curve: curvaEnfasis,
    reverseCurve: curvaEnfasisSalida,
  );

  static const AnimationStyle _dialogoReducido = AnimationStyle(
    duration: rapida,
    reverseDuration: rapida,
  );

  static const AnimationStyle _hoja = AnimationStyle(
    duration: Duration(milliseconds: 320),
    reverseDuration: corta,
    curve: curvaEnfasis,
    reverseCurve: curvaEnfasisSalida,
  );

  static const AnimationStyle _expansion = AnimationStyle(
    duration: Duration(milliseconds: 280),
    reverseDuration: corta,
    curve: curvaEnfasis,
    reverseCurve: curvaEnfasisSalida,
  );
}
