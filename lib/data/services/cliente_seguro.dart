// lib/data/services/cliente_seguro.dart
//
// Cliente HTTP con el certificado del API fijado (#219, certificate pinning).
// No confía en las autoridades instaladas en el teléfono, solo en los
// certificados de CertificadosApi: la conexión falla con cualquier otra
// cadena, aunque el teléfono la acepte.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pier_reposteria/data/services/certificados_api.dart';

/// ¿Se fija el certificado para este backend? Solo para el API de producción
/// por https: el entorno aislado (http://10.0.2.2, localhost) y cualquier
/// otro host quedan como antes.
bool debeFijarCertificado(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == CertificadosApi.hostFijado;
}

/// Cliente que solo confía en [certificados] (PEM; por omisión los de
/// [CertificadosApi.fijados]).
http.Client clienteConCertificadoFijo({List<String>? certificados}) {
  final contexto = SecurityContext(withTrustedRoots: false);
  final pems =
      certificados ?? [for (final c in CertificadosApi.fijados) c.pem];
  for (final pem in pems) {
    contexto.setTrustedCertificatesBytes(utf8.encode(pem));
  }
  return IOClient(HttpClient(context: contexto));
}

/// SHA-256 del certificado (DER) de un PEM, en hexadecimal con «:», igual que
/// `openssl x509 -noout -fingerprint -sha256`.
String huellaSha256(String pem) {
  final cuerpo = pem
      .split('\n')
      .map((linea) => linea.trim())
      .where((linea) => linea.isNotEmpty && !linea.startsWith('-----'))
      .join();
  return sha256
      .convert(base64Decode(cuerpo))
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
