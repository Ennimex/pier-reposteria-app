// test/unitarias/comun/ubicacion_service_test.dart — #227: la ubicación del
// teléfono para una dirección de entrega. Un GeolocatorPlatform falso hace
// de Android: servicio, permiso y posición.
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pier_reposteria/data/services/ubicacion_service.dart';

class _AndroidFalso extends GeolocatorPlatform {
  bool servicioEncendido = true;
  LocationPermission permiso = LocationPermission.whileInUse;
  LocationPermission respuesta = LocationPermission.whileInUse;
  Object? errorAlLeer;
  int solicitudes = 0;
  int ajustesAbiertos = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicioEncendido;

  @override
  Future<LocationPermission> checkPermission() async => permiso;

  @override
  Future<LocationPermission> requestPermission() async {
    solicitudes++;
    return respuesta;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final error = errorAlLeer;
    if (error != null) throw error;
    return Position(
      latitude: 21.1407,
      longitude: -98.4196,
      timestamp: DateTime.utc(2026, 10, 28),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openAppSettings() async {
    ajustesAbiertos++;
    return true;
  }
}

void main() {
  late _AndroidFalso android;
  const ubicador = UbicadorDelTelefono();

  setUp(() => GeolocatorPlatform.instance = android = _AndroidFalso());

  test('con permiso devuelve la posición sin volver a pedirlo', () async {
    final resultado = await ubicador.ubicacionActual();

    expect(resultado.estado, EstadoUbicacion.lista);
    expect(resultado.lat, 21.1407);
    expect(resultado.lng, -98.4196);
    expect(android.solicitudes, 0);
  });

  test('sin permiso todavía, lo pide y con el sí lee la posición', () async {
    android.permiso = LocationPermission.denied;

    final resultado = await ubicador.ubicacionActual();

    expect(android.solicitudes, 1);
    expect(resultado.estado, EstadoUbicacion.lista);
  });

  test('si el cliente lo niega, no lee la posición', () async {
    android
      ..permiso = LocationPermission.denied
      ..respuesta = LocationPermission.denied;

    final resultado = await ubicador.ubicacionActual();

    expect(resultado.estado, EstadoUbicacion.sinPermiso);
    expect(resultado.lat, isNull);
  });

  test('negado para siempre: lo dice y se pueden abrir los Ajustes', () async {
    android.permiso = LocationPermission.deniedForever;

    final resultado = await ubicador.ubicacionActual();
    await ubicador.abrirAjustes();

    expect(resultado.estado, EstadoUbicacion.sinPermisoParaSiempre);
    expect(android.solicitudes, 0);
    expect(android.ajustesAbiertos, 1);
  });

  test('con la ubicación del teléfono apagada no pide el permiso', () async {
    android.servicioEncendido = false;

    final resultado = await ubicador.ubicacionActual();

    expect(resultado.estado, EstadoUbicacion.servicioApagado);
    expect(android.solicitudes, 0);
  });

  test('si no se puede leer la posición (tiempo agotado) es un fallo', () async {
    android.errorAlLeer = Exception('tiempo agotado');

    final resultado = await ubicador.ubicacionActual();

    expect(resultado.estado, EstadoUbicacion.fallo);
  });
}
