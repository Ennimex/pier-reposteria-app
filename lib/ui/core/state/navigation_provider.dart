import 'package:flutter/material.dart';
import 'package:pier_pasteleria/utils/logger.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  // Categoría que el catálogo debe preseleccionar al abrirse (la pestaña es
  // persistente en el IndexedStack, no se le puede pasar por constructor).
  String? _categoriaPendiente;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      PierLog.nav('Cambiando a pestaña index: $index');
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void goToHome() => setSelectedIndex(0);

  void goCatalogo({String? categoria}) {
    if (categoria != null && categoria.isNotEmpty) {
      _categoriaPendiente = categoria;
      PierLog.nav('Catálogo con categoría preseleccionada: $categoria');
      // Ya en el catálogo setSelectedIndex no notificaría (mismo índice)
      if (_selectedIndex == 1) notifyListeners();
    }
    setSelectedIndex(1);
  }

  void goCart() => setSelectedIndex(2);
  void goOrders() => setSelectedIndex(3);
  void goMore() => setSelectedIndex(4);

  /// El catálogo la consume una sola vez: devuelve y limpia (sin notificar).
  String? consumirCategoriaPendiente() {
    final c = _categoriaPendiente;
    _categoriaPendiente = null;
    return c;
  }
}
