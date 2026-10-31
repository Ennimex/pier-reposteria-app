// test/fakes/reproductor_falso.dart — reproductores de video sin plataforma
// para las pruebas de los videos del feed (#134).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pier_reposteria/ui/feed/widgets/video_publicacion.dart';

/// Carga al instante (o falla con [falla]) y lleva la cuenta de lo que se
/// le pidió.
class ReproductorFalso extends ChangeNotifier implements ReproductorVideo {
  ReproductorFalso({this.falla = false});

  final bool falla;
  bool _listo = false;
  bool _reproduciendo = false;
  double volumen = -1;
  int reproducciones = 0;
  bool liberado = false;

  @override
  Future<void> iniciar() async {
    if (falla) throw Exception('sin video');
    _listo = true;
    notifyListeners();
  }

  @override
  Future<void> reproducir() async {
    reproducciones++;
    _reproduciendo = true;
    notifyListeners();
  }

  @override
  Future<void> pausar() async {
    _reproduciendo = false;
    notifyListeners();
  }

  @override
  Future<void> ponerVolumen(double volumen) async => this.volumen = volumen;

  @override
  bool get listo => _listo;

  @override
  bool get reproduciendo => _reproduciendo;

  @override
  double get proporcion => 1.5;

  @override
  Widget vista() => const ColoredBox(
        key: Key('video-reproduciendo'),
        color: Colors.black,
      );

  @override
  Future<void> liberar() async => liberado = true;
}

/// Nunca termina de cargar: en las pruebas que no son de video se queda la
/// portada (no hay plataforma de video).
class ReproductorSinPlataforma extends ReproductorFalso {
  @override
  Future<void> iniciar() => Completer<void>().future;
}
