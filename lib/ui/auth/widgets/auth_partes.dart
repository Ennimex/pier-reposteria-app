// lib/ui/auth/widgets/auth_partes.dart
//
// Piezas que comparten las pantallas de auth (MVVM, Fase 5): aviso flotante,
// botón circular de regreso, campo de texto, ojito de contraseña, botón
// principal con indicador de carga y las 6 cajas del código de verificación.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

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
/// sombra desplazada; si no, 40 px. Sin [onTap], cierra la pantalla.
class BotonAtrasAuth extends StatelessWidget {
  const BotonAtrasAuth({super.key, this.grande = true, this.onTap});

  final bool grande;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tamano = grande ? 44.0 : 40.0;
    return Align(
      alignment: Alignment.centerLeft,
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
    );
  }
}

/// Candado verde en un círculo (olvidé y restablecer contraseña).
class IconoCandado extends StatelessWidget {
  const IconoCandado({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.pierVerde.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.lock, size: 44, color: AppColors.pierVerde),
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
      icon: Icon(
        visible ? LucideIcons.eye : LucideIcons.eyeOff,
        color: AppColors.textSecondary,
        size: 20,
      ),
      onPressed: onPressed,
    );
  }
}

/// Botón verde de la acción principal; mientras [cargando], se deshabilita y
/// muestra un indicador en lugar del texto.
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
        child: cargando
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(texto,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
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
class CampoCodigo extends StatelessWidget {
  const CampoCodigo({
    required this.controller,
    required this.ancho,
    required this.alto,
    required this.tamanoLetra,
    super.key,
    this.onChanged,
  });

  final CodigoController controller;
  final double ancho;
  final double alto;
  final double tamanoLetra;
  final ValueChanged<String>? onChanged;

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
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final enfocada = controller.focos[i].hasFocus;
          final conValor = controller.campos[i].text.isNotEmpty;
          return SizedBox(
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
          );
        }),
      ),
    );
  }
}
