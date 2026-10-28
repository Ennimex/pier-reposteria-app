// lib/data/services/ubicacion_service.dart
//
// Ubicación del teléfono para guardar una dirección de entrega (#227): el
// repartidor llega a las coordenadas exactas. El permiso se pide en tiempo de
// ejecución solo cuando el cliente toca «Usar mi ubicación», y la vista
// explica antes para qué (docs/PERMISOS.md). Sin permiso la dirección se
// guarda igual, escrita a mano.
import 'package:geolocator/geolocator.dart';

/// Cómo terminó el intento de leer la ubicación.
enum EstadoUbicacion {
  lista,
  servicioApagado,
  sinPermiso,
  sinPermisoParaSiempre,
  fallo,
}

class ResultadoUbicacion {
  const ResultadoUbicacion(this.estado, {this.lat, this.lng});

  final EstadoUbicacion estado;
  final double? lat;
  final double? lng;
}

abstract interface class Ubicador {
  /// Pide el permiso si hace falta y lee la ubicación actual.
  Future<ResultadoUbicacion> ubicacionActual();

  /// Abre los ajustes de la app (cuando el permiso se negó para siempre).
  Future<bool> abrirAjustes();
}

class UbicadorDelTelefono implements Ubicador {
  const UbicadorDelTelefono();

  /// Tiempo máximo para conseguir la posición.
  static const espera = Duration(seconds: 20);

  @override
  Future<ResultadoUbicacion> ubicacionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ResultadoUbicacion(EstadoUbicacion.servicioApagado);
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion(EstadoUbicacion.sinPermisoParaSiempre);
      }
      if (permiso != LocationPermission.whileInUse &&
          permiso != LocationPermission.always) {
        return const ResultadoUbicacion(EstadoUbicacion.sinPermiso);
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: espera,
        ),
      );
      return ResultadoUbicacion(
        EstadoUbicacion.lista,
        lat: posicion.latitude,
        lng: posicion.longitude,
      );
    } on Object {
      return const ResultadoUbicacion(EstadoUbicacion.fallo);
    }
  }

  @override
  Future<bool> abrirAjustes() => Geolocator.openAppSettings();
}
