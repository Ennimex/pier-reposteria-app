// test/widget/home/testimonios_test.dart — #169: la sección de testimonios
// del Inicio usa el título y el subtítulo que capturó Dirección.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/config_testimonios.dart';
import 'package:pier_reposteria/ui/home/widgets/home_secciones.dart';

import '../../helpers/pump_app.dart';

const _resenas = [
  {
    'id': 1,
    'autor_nombre': 'Ana',
    'autor_apellido': 'López',
    'rating': 5,
    'comentario': 'Riquísimo',
  },
];

void main() {
  testWidgets('con la configuración de Dirección muestra su título y '
      'subtítulo', (tester) async {
    await tester.pumpApp(const SingleChildScrollView(
      child: HomeResenasDestacadas(
        resenas: _resenas,
        titulo: 'Clientes felices',
        subtitulo: 'Reseñas reales de quienes nos visitan',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Clientes felices'), findsOneWidget);
    expect(find.text('Reseñas reales de quienes nos visitan'), findsOneWidget);
    expect(find.text(ConfigTestimonios.tituloPorDefecto), findsNothing);
  });

  testWidgets('sin configuración usa el título de siempre y sin subtítulo',
      (tester) async {
    await tester.pumpApp(const SingleChildScrollView(
      child: HomeResenasDestacadas(resenas: _resenas),
    ));
    await tester.pumpAndSettle();

    expect(find.text(ConfigTestimonios.tituloPorDefecto), findsOneWidget);
  });
}
