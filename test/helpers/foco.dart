// test/helpers/foco.dart — el teclado no se vuelve a abrir solo (#241,
// #280). Al cerrarse lo que se abrió encima de una pantalla (una hoja, un
// selector, un menú u otra pantalla), Flutter le regresa el foco al último
// campo que lo tuvo y, con el foco, se abre el teclado aunque la persona ya
// lo hubiera cerrado con «atrás».
//
//   await tester.enfocarSinTeclado(find.byType(TextField));
//   await tester.abrirYCerrarSinTeclado(find.byTooltip('Ordenar'));
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

extension Foco on WidgetTester {
  /// Si algún campo de texto tiene el foco (el teclado estaría abierto).
  bool get algunCampoConFoco => widgetList<EditableText>(
        find.byType(EditableText),
      ).any((campo) => campo.focusNode.hasFocus);

  /// Toca [campo] y cierra el teclado con «atrás», como en el teléfono: el
  /// campo se queda con el foco aunque ya no se vea el teclado.
  Future<void> enfocarSinTeclado(Finder campo) async {
    await tap(campo);
    await pump();
    expect(algunCampoConFoco, isTrue, reason: 'el campo tomó el foco');
    expect(testTextInput.isVisible, isTrue, reason: 'se abrió el teclado');
    testTextInput.hide();
  }

  /// Toca [boton], cierra lo que abrió encima con «atrás» del sistema y
  /// comprueba que ningún campo recuperó el foco ni se volvió a abrir el
  /// teclado.
  Future<void> abrirYCerrarSinTeclado(Finder boton) async {
    final pantalla = ModalRoute.of(element(boton))!;
    await tap(boton);
    await pumpAndSettle();
    expect(pantalla.isCurrent, isFalse, reason: 'se abrió algo encima');
    await binding.handlePopRoute();
    await pumpAndSettle();
    expect(pantalla.isCurrent, isTrue, reason: 'se cerró');
    expect(algunCampoConFoco, isFalse, reason: 'el foco no regresó');
    expect(testTextInput.isVisible, isFalse, reason: 'el teclado no se abrió');
  }
}
