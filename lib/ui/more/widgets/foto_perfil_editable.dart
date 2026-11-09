// lib/ui/more/widgets/foto_perfil_editable.dart
//
// Avatar de «Mi perfil» con la insignia de cámara (#345). Al tocarlo sale una
// hoja para tomar la foto, elegirla de la galería o quitarla (solo si ya hay
// una). La foto se reduce en el teléfono antes de subirla (como la de un
// reembolso), y lo que guarda el backend se mezcla en la sesión, así que «Más»
// la muestra en cuanto termina.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/data/repositories/cuenta_repository.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/ui/core/ui/avatar_usuario.dart';
import 'package:pier_reposteria/ui/core/ui/explicacion_permiso.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:pier_reposteria/ui/more/view_model/foto_perfil_view_model.dart';
import 'package:provider/provider.dart';

/// De dónde sale la foto: la ruta del archivo elegido, o null si se canceló.
typedef ElegirFoto = Future<String?> Function(ImageSource fuente);

/// Lo que se eligió en la hoja de opciones.
enum _OpcionFoto { camara, galeria, quitar }

class FotoPerfilEditable extends StatefulWidget {
  /// [viewModel] y [elegirFoto] solo se pasan en pruebas; en la app el
  /// ViewModel usa el CuentaRepository y la foto sale de image_picker.
  const FotoPerfilEditable({
    super.key,
    this.diametro = 72,
    this.viewModel,
    this.elegirFoto,
  });

  final double diametro;
  final FotoPerfilViewModel? viewModel;
  final ElegirFoto? elegirFoto;

  @override
  State<FotoPerfilEditable> createState() => _FotoPerfilEditableState();
}

class _FotoPerfilEditableState extends State<FotoPerfilEditable> {
  // Lado máximo y calidad de la foto: muy por debajo de los 5 MB que acepta
  // el servidor, que de todos modos la guarda a 800 px.
  static const double _ladoMaximo = 1024;
  static const int _calidad = 80;

  late final FotoPerfilViewModel _vm = widget.viewModel ??
      FotoPerfilViewModel(repo: context.read<CuentaRepository>());
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<String?> _elegir(ImageSource fuente) async {
    final elegir = widget.elegirFoto;
    if (elegir != null) return elegir(fuente);
    final foto = await _picker.pickImage(
      source: fuente,
      maxWidth: _ladoMaximo,
      maxHeight: _ladoMaximo,
      imageQuality: _calidad,
    );
    return foto?.path;
  }

  Future<void> _abrirOpciones({required bool tieneFoto}) async {
    if (_vm.ocupado) return;
    final opcion = await showModalBottomSheet<_OpcionFoto>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Foto de perfil',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            _opcion(contexto, LucideIcons.camera, 'Tomar foto',
                _OpcionFoto.camara),
            _opcion(contexto, LucideIcons.image, 'Elegir de la galería',
                _OpcionFoto.galeria),
            if (tieneFoto)
              _opcion(contexto, LucideIcons.trash2, 'Quitar foto',
                  _OpcionFoto.quitar,
                  color: AppColors.error),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    switch (opcion) {
      case _OpcionFoto.camara:
        await _cambiar(ImageSource.camera);
      case _OpcionFoto.galeria:
        await _cambiar(ImageSource.gallery);
      case _OpcionFoto.quitar:
        await _aplicar(_vm.quitar(), 'Quitamos tu foto de perfil');
    }
  }

  Widget _opcion(
    BuildContext contexto,
    IconData icono,
    String texto,
    _OpcionFoto opcion, {
    Color? color,
  }) =>
      ListTile(
        leading: Icon(icono, color: color ?? AppColors.pierVerde),
        title: Text(texto,
            style: TextStyle(color: color ?? AppColors.textPrimary)),
        onTap: () => Navigator.pop(contexto, opcion),
      );

  Future<void> _cambiar(ImageSource fuente) async {
    if (fuente == ImageSource.camera &&
        !await explicarPermiso(context, ExplicacionDePermiso.camaraPerfil)) {
      return;
    }
    final String? ruta;
    try {
      ruta = await _elegir(fuente);
    } on Exception {
      if (mounted) _snack('No se pudo acceder a la imagen', error: true);
      return;
    }
    if (ruta == null || !mounted) return;
    await _aplicar(_vm.cambiar(ruta), 'Tu foto de perfil se actualizó');
  }

  /// Espera [trabajo] y, si el backend guardó la foto, la pone en la sesión.
  Future<void> _aplicar(
    Future<Map<String, dynamic>?> trabajo,
    String exito,
  ) async {
    final auth = context.read<AuthProvider>();
    final usuario = await trabajo;
    if (!mounted) return;
    if (usuario != null) {
      auth.updateCurrentUser(usuario);
      _snack(exito);
    } else if (_vm.error != null) {
      _snack(_vm.error!, error: true);
    }
  }

  void _snack(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? AppColors.error : AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: el avatar usa los colores de la paleta.
    context.watch<TemaProvider>();
    final usuario = context.watch<AuthProvider>().currentUser;
    final fotoUrl = fotoDePerfil(usuario);
    final diametro = widget.diametro;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final ocupado = _vm.ocupado;
        return MergeSemantics(
          child: Semantics(
            button: true,
            label: ocupado ? 'Guardando tu foto de perfil' : 'Cambiar foto de perfil',
            child: PresionEscala(
              escala: AppMovimiento.escalaPresionChica,
              child: GestureDetector(
                onTap: ocupado
                    ? null
                    : () => _abrirOpciones(tieneFoto: fotoUrl != null),
                child: SizedBox(
                  width: diametro,
                  height: diametro,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarUsuario(
                        diametro: diametro,
                        iniciales: inicialesDe(usuario),
                        fotoUrl: fotoUrl,
                        fondo: AppColors.pierVerde,
                        colorIniciales: Colors.white,
                      ),
                      if (ocupado)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.pierVerde,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(LucideIcons.camera,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
