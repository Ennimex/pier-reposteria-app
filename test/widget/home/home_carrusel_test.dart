// test/widget/home/home_carrusel_test.dart — el carrusel del inicio pinta la
// foto de cada diapositiva desde donde viene (asset de la app o red) y su
// botón abre la pantalla de su enlace (#168).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/slide_hero.dart';
import 'package:pier_reposteria/ui/home/widgets/home_carrusel.dart';
import 'package:pier_reposteria/ui/public/widgets/about_us_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/contact_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/faq_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/legal_screen.dart';

import '../../helpers/pump_app.dart';

SlideHero _slide(String imagen, {RutaSlide ruta = RutaSlide.catalogo}) =>
    SlideHero(
      titulo: 'Rosca Cielito Lindo',
      subtitulo: 'Con glorias de Linares',
      cta: 'Ir',
      imagen: imagen,
      ruta: ruta,
    );

Future<void> _montar(WidgetTester tester, SlideHero slide) async {
  await tester.pumpApp(Scaffold(body: HomeCarrusel(slides: [slide])));
  await tester.pump();
}

/// Desmonta para cancelar el temporizador del carrusel.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('HomeCarrusel', () {
    testWidgets('una foto de la app se pinta desde sus assets', (tester) async {
      await _montar(tester, _slide('assets/images/sitio/producto2.webp'));

      expect(
          find.image(const AssetImage('assets/images/sitio/producto2.webp')),
          findsOneWidget);
      await _desmontar(tester);
    });

    testWidgets('una foto de Cloudinary se pide a la red', (tester) async {
      const url = 'https://res.cloudinary.com/pier/image/upload/v1/rosca.jpg';
      await _montar(tester, _slide(url));

      expect(find.image(const NetworkImage(url)), findsOneWidget);
      await _desmontar(tester);
    });

    const destinos = {
      RutaSlide.contacto: ContactScreen,
      RutaSlide.nosotros: AboutUsScreen,
      RutaSlide.faq: FAQScreen,
      RutaSlide.legales: LegalScreen,
    };
    for (final MapEntry(key: ruta, value: pantalla) in destinos.entries) {
      testWidgets('el botón de una diapositiva a ${ruta.name} abre $pantalla',
          (tester) async {
        await _montar(
            tester, _slide('assets/images/sitio/producto1.webp', ruta: ruta));

        await tester.tap(find.text('Ir'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(pantalla), findsOneWidget);
        await _desmontar(tester);
      });
    }
  });
}
