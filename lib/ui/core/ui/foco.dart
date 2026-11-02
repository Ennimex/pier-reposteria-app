// lib/ui/core/ui/foco.dart
//
// Soltar el foco antes de abrir algo encima de una pantalla (una hoja, un
// selector, un menú u otra pantalla). Al cerrarse, Flutter le regresa el foco
// al último campo de texto que lo tuvo en la pantalla de abajo y, con el
// foco, se abre el teclado aunque la persona ya lo hubiera cerrado con
// «atrás» (#241, #280).
import 'package:flutter/widgets.dart';

/// Quita el foco del campo que lo tenga. Se suelta desde el campo y no con
/// `FocusScope.of(context).unfocus()`: así la pantalla olvida cuál campo lo
/// tenía y no se lo devuelve al volver.
void soltarFoco() => FocusManager.instance.primaryFocus?.unfocus();
