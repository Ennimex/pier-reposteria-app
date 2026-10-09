// lib/ui/public/view_model/about_us_view_model.dart
//
// Estado de la pantalla «Nosotros» (MVVM, Fase 3). Arranca con los textos por
// defecto de la app y los reemplaza campo por campo con lo que Dirección haya
// capturado en el panel. Si el backend falla se quedan los textos por defecto
// (la pantalla nunca muestra error).
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';

class AboutUsViewModel extends ChangeNotifier {
  /// [anioActual] solo se pasa en pruebas (años de experiencia).
  AboutUsViewModel({required ConfiguracionRepository repo, int? anioActual})
      : _repo = repo,
        _anioActual = anioActual ?? DateTime.now().year;

  final ConfiguracionRepository _repo;
  final int _anioActual;
  bool _cerrado = false;

  static const List<(String, String)> _statsPorDefecto = [
    ('100%', 'Artesanal'),
    ('+ 5 años', 'Experiencia'),
    ('❤️', 'Con amor'),
  ];

  String _historiaTitulo = 'Nuestra Historia';
  String _historia =
      'Pier Repostería nació en el corazón de Huejutla de Reyes como un pequeño sueño familiar. Lo que comenzó en una cocina casera, horneando con recetas de la abuela, hoy es un referente de sabor y tradición en la Huasteca Hidalguense.';
  String _mision =
      'Crear momentos inolvidables a través de sabores auténticos y una calidad artesanal inigualable.';
  String _vision =
      'Ser la pastelería líder en la región, reconocida por nuestra innovación constante sin perder la esencia tradicional.';
  List<String> _valores = const [
    'Calidad Artesanal',
    'Ingredientes Frescos',
    'Atención Personalizada',
    'Tradición e Innovación',
  ];
  bool _valoresDelPanel = false;
  List<(String, String)> _stats = _statsPorDefecto;

  String get historiaTitulo => _historiaTitulo;
  String get historia => _historia;
  String get mision => _mision;
  String get vision => _vision;
  List<String> get valores => _valores;

  /// true si los valores vienen del panel (la vista rota sus íconos);
  /// false si son los 4 de la app (cada uno con su ícono fijo).
  bool get valoresDelPanel => _valoresDelPanel;

  /// Pares (número, etiqueta); como máximo 4.
  List<(String, String)> get stats => _stats;

  Future<void> cargar() async {
    try {
      final info = await _repo.nosotros();
      if (_cerrado) return;

      _historiaTitulo = info.historiaTitulo ?? _historiaTitulo;
      _historia = info.historia ?? _historia;
      _mision = info.mision ?? _mision;
      _vision = info.vision ?? _vision;
      if (info.valores.isNotEmpty) {
        _valores = info.valores;
        _valoresDelPanel = true;
      }

      if (info.estadisticas.isNotEmpty) {
        _stats = info.estadisticas.take(4).toList();
      } else {
        // Sin estadísticas capturadas pero con año de fundación: los años de
        // experiencia se calculan (la web muestra "Desde <fundacion>").
        final anio = info.anioFundacion;
        if (anio != null && anio > 1900 && anio < _anioActual) {
          _stats = [
            _statsPorDefecto[0],
            ('+ ${_anioActual - anio} años', 'Experiencia'),
            _statsPorDefecto[2],
          ];
        }
      }
      notifyListeners();
    } on ApiException {
      // Se quedan los textos por defecto.
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
