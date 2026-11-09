// lib/ui/core/ui/avatar_usuario.dart
//
// Avatar redondo de la persona con sesión (#345): su foto de perfil o, sin
// foto, sus iniciales. Es un CircleAvatar con `foregroundImage`: las iniciales
// quedan debajo, así que se ven mientras baja la foto y si no carga.
import 'package:flutter/material.dart';

/// Iniciales de nombre y apellido de [usuario] («AG»), o vacío si no tiene.
String inicialesDe(Map<String, dynamic>? usuario) {
  final nombre = usuario?['nombre']?.toString().trim() ?? '';
  final apellido = usuario?['apellido']?.toString().trim() ?? '';
  return '${nombre.isNotEmpty ? nombre[0].toUpperCase() : ''}'
      '${apellido.isNotEmpty ? apellido[0].toUpperCase() : ''}';
}

/// La foto de perfil de [usuario], o null si no tiene.
String? fotoDePerfil(Map<String, dynamic>? usuario) {
  final url =
      usuario?['avatar_url']?.toString() ?? usuario?['foto_url']?.toString();
  return url == null || url.isEmpty ? null : url;
}

class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({
    required this.iniciales,
    required this.diametro,
    required this.fondo,
    required this.colorIniciales,
    super.key,
    this.fotoUrl,
  });

  /// Lo que se ve sin foto; vacío muestra «U».
  final String iniciales;
  final String? fotoUrl;
  final double diametro;
  final Color fondo;
  final Color colorIniciales;

  @override
  Widget build(BuildContext context) {
    final url = fotoUrl;
    final conFoto = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: diametro / 2,
      backgroundColor: fondo,
      foregroundImage: conFoto ? NetworkImage(url) : null,
      // Si la foto no llega se quedan las iniciales de abajo.
      onForegroundImageError: conFoto ? (_, _) {} : null,
      child: Text(
        iniciales.isNotEmpty ? iniciales : 'U',
        style: TextStyle(
          fontSize: diametro * 0.38,
          fontWeight: FontWeight.bold,
          color: colorIniciales,
        ),
      ),
    );
  }
}
