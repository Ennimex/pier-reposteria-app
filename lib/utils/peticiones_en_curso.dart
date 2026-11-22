// lib/utils/peticiones_en_curso.dart
//
// Comparte una petición que ya va en camino. Al abrir la app, varias
// pantallas se montan en el mismo cuadro y piden lo mismo (las promociones,
// las categorías, una sección de la configuración): con esto la segunda
// espera la respuesta de la primera en vez de mandar otra (#341).
//
// Solo para datos públicos, iguales para cualquier sesión: una petición con
// token compartida podría entregarse a quien inicie sesión con otra cuenta
// mientras va en camino.
import 'dart:async';

class PeticionesEnCurso<T> {
  final Map<String, Future<T>> _enCurso = {};

  /// La petición [clave] que ya va en camino o, si no hay ninguna, la que
  /// hace [pedir]. Cuando termina, bien o mal, la siguiente pide de nuevo.
  Future<T> compartir(String clave, Future<T> Function() pedir) =>
      _enCurso[clave] ??= pedir()
          // unawaited: remove devuelve esta misma petición y, si el aviso la
          // devolviera, whenComplete se quedaría esperándola.
          .whenComplete(() => unawaited(_enCurso.remove(clave)));
}
