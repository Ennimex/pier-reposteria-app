// test/widget/feed/tarjeta_publicacion_test.dart — el texto de una
// publicación (#369): hasta 5 renglones y, si no cabe, «Ver más» para verlo
// completo y «Ver menos» para recogerlo. La cuenta de renglones es la del
// texto que se ve, también con la letra del sistema agrandada.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/publicacion.dart';
import 'package:pier_reposteria/ui/feed/widgets/tarjeta_publicacion.dart';

import '../../fakes/publicaciones_json.dart';

/// 20 palabras de 4 letras. Con la fuente de pruebas (cada letra mide lo que
/// su tamaño) y la tarjeta de [_montar] son 5 renglones con la letra normal
/// y 8 con la letra al 150 %.
final String _texto = List.filled(20, 'abcd').join(' ');

/// La tarjeta de una publicación con [texto], sin fotos, en una pantalla de
/// 400 de ancho y con la letra del sistema a [letra].
Future<void> _montar(
  WidgetTester tester, {
  required String texto,
  double letra = 1,
}) async {
  tester.view
    ..physicalSize = const Size(400, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final publicacion = Publicacion.fromJson(
    publicacionJson(texto: texto, medios: []),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 3000),
          textScaler: TextScaler.linear(letra),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: TarjetaPublicacion(
              publicacion,
              alMeEncanta: () {},
              alComentar: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Si el texto que se ve quedó cortado con puntos suspensivos.
bool _cortado(WidgetTester tester, String texto) =>
    tester.renderObject<RenderParagraph>(find.text(texto)).didExceedMaxLines;

void main() {
  testWidgets('un texto que cabe en 5 renglones se ve completo, sin «Ver '
      'más»', (tester) async {
    await _montar(tester, texto: _texto);
    expect(_cortado(tester, _texto), isFalse);
    expect(find.text('Ver más'), findsNothing);
  });

  testWidgets('un texto más largo se corta y «Ver más» lo muestra completo', (
    tester,
  ) async {
    final largo = '$_texto $_texto';
    await _montar(tester, texto: largo);
    expect(_cortado(tester, largo), isTrue);

    await tester.tap(find.text('Ver más'));
    await tester.pump();
    expect(_cortado(tester, largo), isFalse);

    await tester.tap(find.text('Ver menos'));
    await tester.pump();
    expect(_cortado(tester, largo), isTrue);
  });

  // #369: la medida no usaba la letra del sistema. Con la letra grande el
  // texto se cortaba y «Ver más» no salía: el resto no se podía leer.
  testWidgets('con la letra del sistema al 150 %, el texto que ya no cabe '
      'ofrece «Ver más»', (tester) async {
    await _montar(tester, texto: _texto, letra: 1.5);
    expect(_cortado(tester, _texto), isTrue);
    expect(find.text('Ver más'), findsOneWidget);

    await tester.tap(find.text('Ver más'));
    await tester.pump();
    expect(_cortado(tester, _texto), isFalse);
    expect(find.text('Ver menos'), findsOneWidget);
  }, tags: 'regresion');
}
