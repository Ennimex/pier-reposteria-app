// lib/data/services/certificados_api.dart
//
// Certificados fijados del API de producción (#219). La app solo acepta la
// conexión con pier-reposteria-backend.onrender.com si su cadena llega a uno
// de estos dos: aunque alguien instale otra autoridad en el teléfono, no
// puede hacerse pasar por el servidor.
//
// Cadena del API (revisada el 28-oct-2026):
//   onrender.com (hoja, se renueva cada ~90 días: no se fija)
//   └─ GTS WE1 (intermedio, vence el 20-feb-2029)  ← pin principal
//      └─ GTS Root R4 (raíz, vence el 22-jun-2036) ← respaldo
//
// Antes de que venza el intermedio, o si Render cambia de autoridad, hay que
// revisar estos certificados y publicar una versión nueva
// (docs/LIBERACION.md, «Certificado fijado del API»).

/// Un certificado fijado y la huella SHA-256 de su DER, para comprobar que el
/// texto no se alteró.
class CertificadoFijado {
  const CertificadoFijado({
    required this.nombre,
    required this.vence,
    required this.huellaSha256,
    required this.pem,
  });

  final String nombre;
  final String vence;

  /// SHA-256 del certificado (DER), en hexadecimal con «:».
  final String huellaSha256;
  final String pem;
}

abstract final class CertificadosApi {
  /// Host del API cuyo certificado se fija.
  static const hostFijado = 'pier-reposteria-backend.onrender.com';

  static const gtsWe1 = CertificadoFijado(
    nombre: 'GTS WE1',
    vence: '2029-02-20',
    huellaSha256: '1D:FC:16:05:FB:AD:35:8D:8B:C8:44:F7:6D:15:20:3F:'
        'AC:9C:A5:C1:A7:9F:D4:85:7F:FA:F2:86:4F:BE:BF:96',
    pem: '''
-----BEGIN CERTIFICATE-----
MIICnzCCAiWgAwIBAgIQf/MZd5csIkp2FV0TttaF4zAKBggqhkjOPQQDAzBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjQwHhcNMjMxMjEzMDkwMDAwWhcNMjkwMjIwMTQw
MDAwWjA7MQswCQYDVQQGEwJVUzEeMBwGA1UEChMVR29vZ2xlIFRydXN0IFNlcnZp
Y2VzMQwwCgYDVQQDEwNXRTEwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARvzTr+
Z1dHTCEDhUDCR127WEcPQMFcF4XGGTfn1XzthkubgdnXGhOlCgP4mMTG6J7/EFmP
LCaY9eYmJbsPAvpWo4H+MIH7MA4GA1UdDwEB/wQEAwIBhjAdBgNVHSUEFjAUBggr
BgEFBQcDAQYIKwYBBQUHAwIwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU
kHeSNWfE/6jMqeZ72YB5e8yT+TgwHwYDVR0jBBgwFoAUgEzW63T/STaj1dj8tT7F
avCUHYwwNAYIKwYBBQUHAQEEKDAmMCQGCCsGAQUFBzAChhhodHRwOi8vaS5wa2ku
Z29vZy9yNC5jcnQwKwYDVR0fBCQwIjAgoB6gHIYaaHR0cDovL2MucGtpLmdvb2cv
ci9yNC5jcmwwEwYDVR0gBAwwCjAIBgZngQwBAgEwCgYIKoZIzj0EAwMDaAAwZQIx
AOcCq1HW90OVznX+0RGU1cxAQXomvtgM8zItPZCuFQ8jSBJSjz5keROv9aYsAm5V
sQIwJonMaAFi54mrfhfoFNZEfuNMSQ6/bIBiNLiyoX46FohQvKeIoJ99cx7sUkFN
7uJW
-----END CERTIFICATE-----
''',
  );

  static const gtsRootR4 = CertificadoFijado(
    nombre: 'GTS Root R4',
    vence: '2036-06-22',
    huellaSha256: '34:9D:FA:40:58:C5:E2:63:12:3B:39:8A:E7:95:57:3C:'
        '4E:13:13:C8:3F:E6:8F:93:55:6C:D5:E8:03:1B:3C:7D',
    pem: '''
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
''',
  );

  /// Los certificados en los que confía el cliente del API, en orden.
  static const fijados = [gtsWe1, gtsRootR4];
}
