import 'package:flutter/material.dart';
import '../../core/utils/logger.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      PierLog.nav('Cambiando a pestaña index: $index');
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void goToHome() => setSelectedIndex(0);
  void goCatalogo() => setSelectedIndex(1);
  void goCart() => setSelectedIndex(2);
  void goOrders() => setSelectedIndex(3);
  void goMore() => setSelectedIndex(4);
}
