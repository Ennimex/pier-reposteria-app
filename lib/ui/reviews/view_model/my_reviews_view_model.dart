// lib/ui/reviews/view_model/my_reviews_view_model.dart
//
// Estado de «Mis Reseñas» (MVVM, Fase 3): la lista del cliente y la edición
// de una reseña. Si el backend falla al cargar se conserva la última lista
// (la pantalla no muestra error, como antes). La hoja de edición guarda su
// propio estado de formulario y le entrega aquí lo capturado.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';
import 'package:pier_pasteleria/domain/models/mi_resena.dart';

class MyReviewsViewModel extends ChangeNotifier {
  MyReviewsViewModel({required ResenasRepository repo}) : _repo = repo;

  final ResenasRepository _repo;
  bool _cerrado = false;

  List<MiResena> _resenas = const [];
  bool _cargando = true;

  List<MiResena> get resenas => _resenas;

  /// true durante la primera carga: la vista pinta el indicador.
  bool get cargando => _cargando;

  /// [silenciosa] recarga sin indicador (pull-to-refresh, tras editar).
  Future<void> cargar({bool silenciosa = false}) async {
    if (!silenciosa) {
      _cargando = true;
      notifyListeners();
    }
    try {
      _resenas = await _repo.listarMisResenas();
    } on ApiException {
      // Se conserva la última lista.
    }
    if (_cerrado) return;
    if (!silenciosa) _cargando = false;
    notifyListeners();
  }

  /// Guarda los cambios y devuelve el mensaje para el aviso (el del backend
  /// si falló). Si se guardó, recarga la lista en silencio (sin esperarla,
  /// para que el aviso salga de inmediato).
  Future<String> editar(
    MiResena resena, {
    required int rating,
    required String titulo,
    required String comentario,
  }) async {
    try {
      final mensaje = await _repo.editarResena(
        id: resena.id,
        rating: rating,
        titulo: titulo,
        comentario: comentario,
      );
      if (!_cerrado) unawaited(cargar(silenciosa: true));
      return mensaje;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
