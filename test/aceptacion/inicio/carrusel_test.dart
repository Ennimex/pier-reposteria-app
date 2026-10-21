// test/aceptacion/inicio/carrusel_test.dart — escenarios Gherkin del carrusel
// de Inicio con las diapositivas que edita Dirección en el sitio (historia
// #168), sin red: la pantalla real de Inicio, su ViewModel y el repositorio
// de configuración sobre FakeApiClient, que responde GET /contenido como el
// backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/home/widgets/home_screen.dart';
import 'package:pier_reposteria/ui/public/widgets/contact_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Una diapositiva de `inicio.carrusel` tal como la guarda el editor.
Map<String, dynamic> _diapositiva(String imagen, String titulo,
        String subtitulo, String boton, String enlace) =>
    {
      'imagen': imagen,
      'titulo': titulo,
      'subtitulo': subtitulo,
      'boton_texto': boton,
      'boton_enlace': enlace,
    };

/// GET /contenido con el carrusel guardado (o sin él).
FakeApiClient _backend({List<Map<String, dynamic>>? carrusel}) =>
    FakeApiClient(respuestas: {
      ApiConstants.contenido: {
        'success': true,
        'contenido': {'inicio.carrusel': ?carrusel},
        'actualizado': <String, dynamic>{},
      },
    });

/// Cuando abro Inicio.
Future<void> _abrirInicio(WidgetTester tester, FakeApiClient api) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const HomeScreen(), api: api);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// El carrusel avanza solo cada 5 s.
Future<void> _siguienteDiapositiva(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 1));
}

/// Desmonta para cancelar el carrusel y el sondeo de notificaciones.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Título de la primera diapositiva de respaldo de la app.
const String _respaldo = 'Tradición en cada\nRebanada';

void main() {
  group('#168 Carrusel de Inicio con las diapositivas que edita Dirección',
      () {
    // Escenario: carrusel publicado por Dirección
    //   Dado que Dirección guardó un carrusel de 3 diapositivas
    //   Cuando abro Inicio
    //   Entonces veo esas 3 diapositivas en el mismo orden, con su título,
    //   subtítulo y botón
    testWidgets('Escenario: carrusel publicado por Dirección', (tester) async {
      // Dado que Dirección guardó un carrusel de 3 diapositivas
      final api = _backend(carrusel: [
        _diapositiva('local:producto1.webp', 'Endulza tus momentos',
            'Repostería artesanal desde 2009', 'Ver catálogo', '/productos'),
        _diapositiva('local:producto2.webp', 'Rosca Cielito Lindo',
            'Con glorias de Linares', 'Pedir la mía', '/productos'),
        _diapositiva('local:producto3.webp', 'Mostachón de maracuyá',
            'Explosión tropical', 'Escríbenos', '/contacto'),
      ]);

      // Cuando abro Inicio
      await _abrirInicio(tester, api);

      // Entonces veo esas 3 diapositivas en el mismo orden, con su título,
      // subtítulo y botón
      for (final (titulo, subtitulo, boton) in [
        ('Endulza tus momentos', 'Repostería artesanal desde 2009',
            'Ver catálogo'),
        ('Rosca Cielito Lindo', 'Con glorias de Linares', 'Pedir la mía'),
        ('Mostachón de maracuyá', 'Explosión tropical', 'Escríbenos'),
      ]) {
        expect(find.text(titulo), findsOneWidget);
        expect(find.text(subtitulo), findsOneWidget);
        expect(find.text(boton), findsOneWidget);
        await _siguienteDiapositiva(tester);
      }
      expect(find.text(_respaldo), findsNothing);
      await _desmontar(tester);
    });

    // Escenario: sin carrusel guardado
    //   Dado que el contenido no trae "inicio.carrusel"
    //   Cuando abro Inicio
    //   Entonces veo el carrusel que la app muestra hoy
    testWidgets('Escenario: sin carrusel guardado', (tester) async {
      // Dado que el contenido no trae "inicio.carrusel"
      final api = _backend();

      // Cuando abro Inicio
      await _abrirInicio(tester, api);

      // Entonces veo el carrusel que la app muestra hoy
      expect(find.text(_respaldo), findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: imagen incluida en la web
    //   Dado una diapositiva con imagen "local:producto3.webp"
    //   Cuando se muestra
    //   Entonces la app usa su foto equivalente o la imagen de respaldo de esa
    //   posición
    testWidgets('Escenario: imagen incluida en la web', (tester) async {
      // Dado una diapositiva con imagen "local:producto3.webp"
      final api = _backend(carrusel: [
        _diapositiva('local:producto3.webp', 'Mostachón de maracuyá',
            'Explosión tropical', 'Ver catálogo', '/productos'),
      ]);

      // Cuando se muestra
      await _abrirInicio(tester, api);

      // Entonces la app usa su foto equivalente
      expect(
          find.image(const AssetImage('assets/images/sitio/producto3.webp')),
          findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: botón de la diapositiva
    //   Dado una diapositiva con enlace "/contacto"
    //   Cuando toco su botón
    //   Entonces se abre la pantalla de Contacto
    testWidgets('Escenario: botón de la diapositiva', (tester) async {
      // Dado una diapositiva con enlace "/contacto"
      final api = _backend(carrusel: [
        _diapositiva('local:producto4.webp', 'Pasteles de autor',
            'Para tu momento especial', 'Escríbenos', '/contacto'),
      ]);
      await _abrirInicio(tester, api);

      // Cuando toco su botón
      await tester.tap(find.text('Escríbenos'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Entonces se abre la pantalla de Contacto
      expect(find.byType(ContactScreen), findsOneWidget);
      await _desmontar(tester);
    });

    // Escenario: sin conexión
    //   Dado que no se pudo cargar el contenido
    //   Cuando abro Inicio
    //   Entonces veo el carrusel de respaldo sin mensaje de error
    testWidgets('Escenario: sin conexión', (tester) async {
      // Dado que no se pudo cargar el contenido
      final api = _backend()..fallar(ApiConstants.contenido, 'Servidor caído');

      // Cuando abro Inicio
      await _abrirInicio(tester, api);

      // Entonces veo el carrusel de respaldo sin mensaje de error
      expect(find.text(_respaldo), findsOneWidget);
      expect(find.textContaining('Servidor caído'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await _desmontar(tester);
    });
  });
}
