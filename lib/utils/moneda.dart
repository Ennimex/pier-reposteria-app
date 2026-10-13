// lib/utils/moneda.dart
//
// Montos en pesos como los muestra la web ('$1,250.50'): comandas (#129) y
// precios de las publicaciones del inicio (#132).

/// '$1,250.50': con separador de miles y dos decimales.
String moneda(double valor) {
  final centavos = (valor * 100).round();
  final entero = (centavos.abs() ~/ 100).toString();
  final miles = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) miles.write(',');
    miles.write(entero[i]);
  }
  final signo = centavos < 0 ? '-' : '';
  return '$signo\$$miles.${(centavos.abs() % 100).toString().padLeft(2, '0')}';
}
