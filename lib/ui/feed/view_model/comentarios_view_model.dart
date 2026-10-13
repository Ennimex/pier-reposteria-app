// lib/ui/feed/view_model/comentarios_view_model.dart
//
// Estado de la hoja de comentarios de una publicación (#133): los
// comentarios visibles de 20 en 20, comentar (el backend permite 5 por
// minuto) y borrar los propios. Recuerda lo que se comentó y borró para que
// el inicio actualice su contador al cerrar la hoja. Lo crea
// ComentariosSheet.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/publicaciones_repository.dart';
import 'package:pier_pasteleria/domain/models/publicacion.dart';
import 'package:pier_pasteleria/utils/command.dart';

class ComentariosViewModel extends ChangeNotifier {
  ComentariosViewModel({
    required PublicacionesRepository repo,
    required this.publicacionId,
  }) : _repo = repo {
    publicar = Command1<ComentarioPublicacion, String>(_publicar);
    borrar = Command1<int, int>(_borrar);
  }

  final PublicacionesRepository _repo;
  final int publicacionId;

  /// Publica el texto (sin espacios de más); su resultado es el comentario.
  late final Command1<ComentarioPublicacion, String> publicar;

  /// Borra un comentario propio; su resultado es el id borrado.
  late final Command1<int, int> borrar;

  List<ComentarioPublicacion> _comentarios = [];
  bool _hayMas = false;
  bool _cargando = false;
  bool _cargandoMas = false;
  String? _error;
  bool _noDisponible = false;
  final List<ComentarioPublicacion> _nuevos = [];
  final Set<int> _borrados = {};
  bool _cerrado = false;

  List<ComentarioPublicacion> get comentarios => _comentarios;
  bool get hayMas => _hayMas;
  bool get cargando => _cargando;
  bool get cargandoMas => _cargandoMas;
  String? get error => _error;

  /// La repostería eliminó la publicación mientras se veía.
  bool get noDisponible => _noDisponible;

  /// Lo que se comentó en esta hoja (y sigue visible).
  List<ComentarioPublicacion> get nuevos => List.unmodifiable(_nuevos);

  /// Comentarios que ya estaban y se borraron en esta hoja.
  Set<int> get borrados => Set.unmodifiable(_borrados);

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _avisar();
    await _traer(() async {
      final pagina = await _repo.comentarios(publicacionId);
      _comentarios = pagina.comentarios;
      _hayMas = pagina.hayMas;
    });
    _cargando = false;
    _avisar();
  }

  /// Los 20 siguientes; nada si ya no hay más o si ya está cargando.
  Future<void> cargarMas() async {
    if (!_hayMas || _cargandoMas || _comentarios.isEmpty) return;
    _cargandoMas = true;
    _avisar();
    await _traer(() async {
      final pagina = await _repo.comentarios(
        publicacionId,
        despuesId: _comentarios.last.id,
      );
      final vistos = _comentarios.map((c) => c.id).toSet();
      _comentarios = [
        ..._comentarios,
        ...pagina.comentarios.where((c) => !vistos.contains(c.id)),
      ];
      _hayMas = pagina.hayMas;
    });
    _cargandoMas = false;
    _avisar();
  }

  Future<void> _traer(Future<void> Function() accion) async {
    try {
      await accion();
    } on PublicacionNoDisponibleException catch (e) {
      _noDisponible = true;
      _error = e.message;
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  Future<ComentarioPublicacion> _publicar(String texto) async {
    final comentario = await _vigilar(
      _repo.comentar(publicacionId, texto.trim()),
    );
    _comentarios = [..._comentarios, comentario];
    _nuevos.add(comentario);
    _avisar();
    return comentario;
  }

  Future<int> _borrar(int comentarioId) async {
    await _vigilar(_repo.borrarComentario(comentarioId));
    _comentarios = _comentarios.where((c) => c.id != comentarioId).toList();
    // Uno recién publicado aquí no se había sumado todavía al inicio
    final eraNuevo = _nuevos.any((c) => c.id == comentarioId);
    _nuevos.removeWhere((c) => c.id == comentarioId);
    if (!eraNuevo) _borrados.add(comentarioId);
    _avisar();
    return comentarioId;
  }

  /// Marca si la publicación ya no está y deja pasar el error al comando.
  Future<T> _vigilar<T>(Future<T> llamada) async {
    try {
      return await llamada;
    } on PublicacionNoDisponibleException {
      _noDisponible = true;
      _avisar();
      rethrow;
    }
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    publicar.dispose();
    borrar.dispose();
    super.dispose();
  }
}
