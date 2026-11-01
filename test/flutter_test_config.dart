// test/flutter_test_config.dart — se aplica a todas las pruebas de test/.
//
// StorageService guarda el JWT con flutter_secure_storage (#25), que en
// pruebas no tiene plataforma nativa: cada prueba arranca con un
// almacenamiento seguro simulado y vacío (sin sesión), igual que hacen con
// SharedPreferences.setMockInitialValues({}).
//
// Los videos del feed (#134) tampoco tienen plataforma: sus reproductores no
// terminan de cargar (se ve la portada) y la visibilidad se avisa sin
// esperar, para no dejar timers pendientes.
//
// Las fotos de las tarjetas (#267) se guardan en el teléfono con
// cached_network_image, que usa disco y los plugins sqflite y path_provider:
// en pruebas se piden con NetworkImage, como antes de guardarlas.
import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/feed/widgets/video_publicacion.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'fakes/reproductor_falso.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    crearReproductor = (_) => ReproductorSinPlataforma();
    proveedorDeFoto = NetworkImage.new;
  });
  await testMain();
}
