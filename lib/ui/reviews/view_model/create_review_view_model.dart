// lib/ui/reviews/view_model/create_review_view_model.dart
//
// Estado de «Escribir reseña» (MVVM, Fase 3): calificación, largo del
// comentario, validación y envío. Los TextEditingController, la revisión de
// sesión (lleva a login) y el diálogo de éxito se quedan en la vista.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/resenas_repository.dart';

class CreateReviewViewModel extends ChangeNotifier {
  CreateReviewViewModel({
    required ResenasRepository repo,
    required String productoId,
  })  : _repo = repo,
        _productoId = productoId;

  final ResenasRepository _repo;
  final String _productoId;
  bool _cerrado = false;

  /// Mínimo de caracteres del comentario (sin espacios de los extremos).
  static const int minimoComentario = 10;

  int _rating = 0;
  String _comentario = '';
  bool _enviando = false;
  String? _error;

  /// 0 = sin calificar; 1 a 5 estrellas.
  int get rating => _rating;
  bool get enviando => _enviando;

  /// Mensaje del último intento fallido (validación o backend).
  String? get error => _error;

  int get largoComentario => _comentario.trim().length;
  bool get comentarioValido => largoComentario >= minimoComentario;

  void calificar(int estrellas) {
    if (estrellas == _rating) return;
    _rating = estrellas;
    notifyListeners();
  }

  /// La vista lo llama en cada cambio del campo (para el contador).
  void editarComentario(String texto) {
    _comentario = texto;
    notifyListeners();
  }

  /// Valida y envía. Devuelve true si quedó publicada, false si quedó en
  /// revisión, o null si no se envió (el motivo queda en [error]).
  Future<bool?> enviar({required String titulo}) async {
    if (_enviando) return null;
    if (_rating == 0) return _fallar('Selecciona una calificación');
    if (!comentarioValido) {
      return _fallar(
        'El comentario debe tener al menos $minimoComentario caracteres',
      );
    }

    _enviando = true;
    _error = null;
    notifyListeners();
    bool? publicada;
    try {
      publicada = await _repo.crearResena(
        productoId: _productoId,
        rating: _rating,
        titulo: titulo.trim(),
        comentario: _comentario.trim(),
      );
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (_cerrado) return null;
    _enviando = false;
    notifyListeners();
    return publicada;
  }

  bool? _fallar(String mensaje) {
    _error = mensaje;
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
