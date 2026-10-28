// lib/ui/core/ui/aviso_sesion_expirada.dart
//
// Avisa «Tu sesión expiró…» cuando AuthProvider cierra la sesión porque el
// servidor rechazó el token (#218). Va en el builder de MaterialApp: debajo
// del ScaffoldMessenger y encima de todas las rutas, así el aviso sale en la
// pantalla donde esté el cliente y sigue visible si el router lo manda a
// iniciar sesión.
import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:provider/provider.dart';

class AvisoSesionExpirada extends StatefulWidget {
  const AvisoSesionExpirada({super.key, required this.child});

  final Widget child;

  static const mensaje = 'Tu sesión expiró. Inicia sesión de nuevo.';

  @override
  State<AvisoSesionExpirada> createState() => _AvisoSesionExpiradaState();
}

class _AvisoSesionExpiradaState extends State<AvisoSesionExpirada> {
  AuthProvider? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_revisar);
    _auth = auth..addListener(_revisar);
  }

  void _revisar() {
    final auth = _auth;
    if (auth == null || !auth.sesionExpiro) return;
    auth.avisoDeSesionMostrado();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AvisoSesionExpirada.mensaje),
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_revisar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
