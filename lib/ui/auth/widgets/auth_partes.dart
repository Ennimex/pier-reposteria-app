// lib/ui/auth/widgets/auth_partes.dart
//
// Piezas que comparten las pantallas de auth (MVVM, Fase 5): aviso flotante,
// botón circular de regreso, logo y candado (Heroes que vuelan entre
// pantallas), campo de texto, ojito de contraseña, botón principal con
// indicador de carga y las 6 cajas del código de verificación.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';

/// Espera de la cascada de una pantalla de auth según cómo llegó. Con
/// context.go es una página raíz de go_router (sus RouteSettings son la
/// Page) que aparece con un fundido: AppMovimiento.trasRaiz. Con
/// Navigator.push llega deslizándose: AppMovimiento.trasEmpuje.
Duration retrasoEntradaAuth(BuildContext context) =>
    ModalRoute.settingsOf(context) is Page<Object?>
        ? AppMovimiento.trasRaiz
        : AppMovimiento.trasEmpuje;

/// SnackBar flotante de las pantallas de auth (rojo de error por defecto).
void mostrarAvisoAuth(
  BuildContext context,
  String mensaje, {
  Color color = AppColors.error,
}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mensaje),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

/// Botón circular de regreso, alineado a la izquierda. [grande]: 44 px con
/// sombra desplazada; si no, 40 px. Sin [onTap], cierra la pantalla. Se
/// hunde un poco al tocarlo (sigue siendo un GestureDetector, no un
/// IconButton).
class BotonAtrasAuth extends StatelessWidget {
  const BotonAtrasAuth({super.key, this.grande = true, this.onTap});

  final bool grande;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tamano = grande ? 44.0 : 40.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: PresionEscala(
        escala: AppMovimiento.escalaPresionChica,
        child: GestureDetector(
          onTap: onTap ?? () => Navigator.pop(context),
          child: Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: grande ? const Offset(0, 2) : Offset.zero,
                ),
              ],
            ),
            child: const Icon(LucideIcons.chevronLeft,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Candado verde en un círculo (olvidé y restablecer contraseña). Es un
/// Hero: al pasar de «¿Olvidaste tu contraseña?» a «Nueva contraseña» el
/// candado se queda en su sitio mientras las páginas se deslizan alrededor.
class IconoCandado extends StatelessWidget {
  const IconoCandado({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HeroMode(
        enabled: !AppMovimiento.reducido(context),
        child: Hero(
          tag: 'auth-candado',
          transitionOnUserGestures: true,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.pierVerde.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(LucideIcons.lock, size: 44, color: AppColors.pierVerde),
          ),
        ),
      ),
    );
  }
}

/// Logo de Pier en un círculo blanco con sombra verde (login y registro).
/// Es el mismo Hero en las dos pantallas: al ir de una a otra (y al
/// regresar, también con el gesto de iOS) el círculo vuela y cambia de
/// tamaño, de margen y de sombra sin saltos.
class LogoAuth extends StatelessWidget {
  const LogoAuth({
    required this.tamano,
    required this.margen,
    required this.alfaSombra,
    required this.desenfoque,
    required this.caida,
    required this.tamanoRespaldo,
    super.key,
  });

  /// Diámetro del círculo.
  final double tamano;

  /// Espacio entre el borde del círculo y el logo.
  final double margen;

  /// Sombra verde: opacidad, desenfoque y desplazamiento hacia abajo.
  final double alfaSombra;
  final double desenfoque;
  final double caida;

  /// Tamaño del pastel que sustituye al logo si la imagen falla.
  final double tamanoRespaldo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HeroMode(
        enabled: !AppMovimiento.reducido(context),
        child: Hero(
          tag: 'pier-logo-auth',
          transitionOnUserGestures: true,
          flightShuttleBuilder: _vuelo,
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: _CirculoLogo(
              fraccionMargen: margen / tamano,
              alfaSombra: alfaSombra,
              desenfoque: desenfoque,
              caida: caida,
              tamanoRespaldo: tamanoRespaldo,
            ),
          ),
        ),
      ),
    );
  }

  // En push y en pop la animación vale 0 en la ruta de abajo (login) y 1 en
  // la de arriba (registro): el círculo en vuelo mezcla los dos estilos.
  static Widget _vuelo(
    BuildContext contextoVuelo,
    Animation<double> animacion,
    HeroFlightDirection direccion,
    BuildContext desde,
    BuildContext hacia,
  ) {
    final empuje = direccion == HeroFlightDirection.push;
    final abajo =
        (empuje ? desde : hacia).findAncestorWidgetOfExactType<LogoAuth>();
    final arriba =
        (empuje ? hacia : desde).findAncestorWidgetOfExactType<LogoAuth>();
    final a = abajo ?? arriba;
    final b = arriba ?? abajo;
    if (a == null || b == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final t = animacion.value;
        double mezcla(double x, double y) => lerpDouble(x, y, t)!;
        return _CirculoLogo(
          fraccionMargen: mezcla(a.margen / a.tamano, b.margen / b.tamano),
          alfaSombra: mezcla(a.alfaSombra, b.alfaSombra),
          desenfoque: mezcla(a.desenfoque, b.desenfoque),
          caida: mezcla(a.caida, b.caida),
          tamanoRespaldo: mezcla(a.tamanoRespaldo, b.tamanoRespaldo),
        );
      },
    );
  }
}

/// El círculo del logo; llena el espacio que le dan (en reposo, el tamaño
/// del logo; en vuelo, el rectángulo del Hero).
class _CirculoLogo extends StatelessWidget {
  const _CirculoLogo({
    required this.fraccionMargen,
    required this.alfaSombra,
    required this.desenfoque,
    required this.caida,
    required this.tamanoRespaldo,
  });

  final double fraccionMargen;
  final double alfaSombra;
  final double desenfoque;
  final double caida;
  final double tamanoRespaldo;

  @override
  Widget build(BuildContext context) {
    final lado = 1 - 2 * fraccionMargen;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.pierVerde.withValues(alpha: alfaSombra),
            blurRadius: desenfoque,
            offset: Offset(0, caida),
          ),
        ],
      ),
      child: ClipOval(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: lado,
            heightFactor: lado,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(LucideIcons.cake,
                  size: tamanoRespaldo, color: AppColors.pierVerde),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto blanco con ícono verde. [sinBordeBase] quita el borde de
/// respaldo (el del inicio de sesión), que solo se ve con error y enfocado.
class CampoAuth extends StatelessWidget {
  const CampoAuth({
    required this.controller,
    required this.label,
    required this.icon,
    super.key,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.helperText,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.sinBordeBase = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool sinBordeBase;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: AppColors.pierVerde, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: sinBordeBase
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none)
            : null,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.textSecondary.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.pierVerde, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.all(14),
      ),
      validator: validator,
    );
  }
}

/// Ícono de «mostrar u ocultar contraseña» para el final de un [CampoAuth].
/// El ojo cambia con un pop dentro del mismo IconButton.
class OjoPassword extends StatelessWidget {
  const OjoPassword({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CambioAnimado(
        tipo: TipoCambio.escalar,
        duracion: AppMovimiento.rapida,
        alineacion: Alignment.center,
        child: Icon(
          visible ? LucideIcons.eye : LucideIcons.eyeOff,
          key: ValueKey<bool>(visible),
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

/// Botón verde de la acción principal; mientras [cargando], se deshabilita y
/// muestra un indicador en lugar del texto. El texto y el indicador se
/// cambian con un pop dentro del mismo ElevatedButton.
class BotonPrincipalAuth extends StatelessWidget {
  const BotonPrincipalAuth({
    required this.texto,
    required this.cargando,
    required this.onPressed,
    super.key,
  });

  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pierVerde,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: CambioAnimado(
          tipo: TipoCambio.escalar,
          alineacion: Alignment.center,
          child: cargando
              ? const SizedBox(
                  key: ValueKey<String>('cargando'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(texto,
                  key: const ValueKey<String>('texto'),
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// Los 6 campos y focos del código de verificación. Lo crea y lo libera la
/// pantalla que muestra el [CampoCodigo].
class CodigoController {
  final List<TextEditingController> campos =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focos = List.generate(6, (_) => FocusNode());

  /// Avisa cuando cambia un dígito o el foco (para repintar las cajas).
  late final Listenable cambios = Listenable.merge([...campos, ...focos]);

  String get codigo => campos.map((c) => c.text).join();

  /// Borra los 6 dígitos y regresa el foco a la primera caja.
  void limpiar() {
    for (final c in campos) {
      c.clear();
    }
    focos[0].requestFocus();
  }

  void dispose() {
    for (final c in campos) {
      c.dispose();
    }
    for (final f in focos) {
      f.dispose();
    }
  }
}

/// Fila de 6 cajas de un dígito: el foco avanza al escribir y retrocede al
/// borrar. [onChanged] recibe el código completo tras cada cambio.
///
/// Movimiento (solo pinta: Verificar usa IntrinsicHeight): con [entrada]
/// las cajas aparecen una tras otra a partir de esa espera; cada caja da un
/// pop cuando cae su dígito y, al completarse el código, una ola recorre
/// las seis. Los 6 campos nunca se recrean.
class CampoCodigo extends StatelessWidget {
  const CampoCodigo({
    required this.controller,
    required this.ancho,
    required this.alto,
    required this.tamanoLetra,
    super.key,
    this.onChanged,
    this.entrada,
  });

  final CodigoController controller;
  final double ancho;
  final double alto;
  final double tamanoLetra;
  final ValueChanged<String>? onChanged;

  /// Espera antes de que entre la primera caja; null: sin entrada.
  final Duration? entrada;

  void _alCambiar(String valor, int i) {
    final focos = controller.focos;
    if (valor.length == 1 && i < 5) {
      focos[i + 1].requestFocus();
    } else if (valor.isEmpty && i > 0) {
      focos[i - 1].requestFocus();
    }
    onChanged?.call(controller.codigo);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.cambios,
      builder: (context, _) {
        final completo = controller.codigo.length == 6;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _caja(i, completo: completo)),
        );
      },
    );
  }

  Widget _caja(int i, {required bool completo}) {
    final espera = entrada;
    final enfocada = controller.focos[i].hasFocus;
    final conValor = controller.campos[i].text.isNotEmpty;
    return EntradaSuave(
      retraso: (espera ?? Duration.zero) + AppMovimiento.paso * i,
      escalaInicial: 0.85,
      desplazamiento: const Offset(0, AppMovimiento.distanciaCorta),
      animar: espera != null,
      child: _CajaCodigo(
        indice: i,
        lleno: conValor,
        completo: completo,
        child: SizedBox(
          width: ancho,
          height: alto,
          child: TextFormField(
            controller: controller.campos[i],
            focusNode: controller.focos[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                fontSize: tamanoLetra,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: enfocada || conValor
                  ? Colors.white
                  : AppColors.textSecondary.withValues(alpha: 0.15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: conValor
                        ? AppColors.pierVerde.withValues(alpha: 0.4)
                        : Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.pierVerde, width: 2),
              ),
            ),
            onChanged: (v) => _alCambiar(v, i),
          ),
        ),
      ),
    );
  }
}

/// Una caja del código: da un pop cuando cae su dígito y, cuando se
/// completan los seis, sube y baja con su escalón de la ola. Todo es de
/// pintura (escala y traslado): el campo de adentro no se toca.
class _CajaCodigo extends StatefulWidget {
  const _CajaCodigo({
    required this.indice,
    required this.lleno,
    required this.completo,
    required this.child,
  });

  final int indice;
  final bool lleno;
  final bool completo;
  final Widget child;

  @override
  State<_CajaCodigo> createState() => _CajaCodigoState();
}

class _CajaCodigoState extends State<_CajaCodigo>
    with TickerProviderStateMixin {
  // Cada caja sube y regresa en este tiempo (un cambio en sitio); la ola
  // completa dura lo que tarda en llegar a la sexta.
  static const Duration _subida = AppMovimiento.corta;
  static const double _alturaOla = 6;

  static final Animatable<double> _escalaPop = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.12, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ],
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppMovimiento.corta,
  );
  late final AnimationController _ola = AnimationController(
    vsync: this,
    duration: AppMovimiento.paso * 5 + _subida,
  );
  late final Animation<double> _escala = _pop.drive(_escalaPop);
  late final Animation<double> _tramoOla = _ola.drive(
    CurveTween(curve: _tramo(widget.indice)),
  );

  // El tramo de la ola que le toca a la caja [indice] (0 a 5). Cada extremo
  // es una sola división: el de la sexta vale 1 exacto (Interval no admite
  // pasarse de 1).
  static Curve _tramo(int indice) {
    final total = (AppMovimiento.paso * 5 + _subida).inMicroseconds;
    final inicio = AppMovimiento.paso * indice;
    return Interval(
      inicio.inMicroseconds / total,
      (inicio + _subida).inMicroseconds / total,
    );
  }

  @override
  void didUpdateWidget(_CajaCodigo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (AppMovimiento.reducido(context)) return;
    if (widget.lleno && !oldWidget.lleno) _pop.forward(from: 0).ignore();
    if (widget.completo && !oldWidget.completo) {
      _ola.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _ola.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _escala,
      child: _Elevar(
        avance: _tramoOla,
        altura: _alturaOla,
        child: widget.child,
      ),
    );
  }
}

/// Sube al hijo [altura] dp y lo regresa (medio seno) según el avance.
class _Elevar extends AnimatedWidget {
  const _Elevar({
    required Animation<double> avance,
    required this.altura,
    required this.child,
  }) : super(listenable: avance);

  final double altura;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Transform.translate(
      offset: Offset(0, -altura * math.sin(math.pi * t)),
      child: child,
    );
  }
}
