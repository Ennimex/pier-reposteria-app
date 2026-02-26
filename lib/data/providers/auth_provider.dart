// lib/data/providers/auth_provider.dart
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  // Simular Login
  Future<bool> login(String email, String password) async {
    // Aquí conectarías con tu API real
    await Future.delayed(const Duration(seconds: 2)); // Simular espera de red
    
    if (email.isNotEmpty && password.length >= 6) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Simular Registro
  Future<bool> register(String name, String email, String password) async {
    await Future.delayed(const Duration(seconds: 2));
    // Asumimos que el registro es exitoso y logueamos al usuario automáticamente
    _isAuthenticated = true; 
    notifyListeners();
    return true;
  }

  // Simular Logout
  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }
}