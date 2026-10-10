// lib/ui/public/view_model/faq_view_model.dart
//
// Estado de «Preguntas Frecuentes» (MVVM, Fase 3). Arranca con las preguntas
// por defecto de la app; si Dirección capturó preguntas en el panel se
// reemplazan todas por esas. Si el backend falla se quedan las de la app (la
// pantalla nunca muestra error). También lleva el filtro por categoría.
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/domain/models/pregunta_frecuente.dart';

class FaqViewModel extends ChangeNotifier {
  FaqViewModel({required ConfiguracionRepository repo}) : _repo = repo;

  final ConfiguracionRepository _repo;
  bool _cerrado = false;

  static const String todas = 'Todas';

  // Las conocidas van en este orden; las que capture el panel, al final.
  static const List<String> _conocidas = [
    'Pedidos',
    'Pagos',
    'Devoluciones',
    'Seguridad',
    'Ubicación',
  ];

  static const List<PreguntaFrecuente> _porDefecto = [
    PreguntaFrecuente(
      categoria: 'Pedidos',
      pregunta: '¿Ofrecen servicio de entrega a domicilio?',
      respuesta:
          'Sí. Al finalizar tu pedido puedes elegir recoger en nuestra sucursal de ${BusinessInfo.ciudad} o envío a domicilio en las colonias con cobertura. El costo de envío se calcula automáticamente según tu colonia.',
    ),
    PreguntaFrecuente(
      categoria: 'Pedidos',
      pregunta: '¿Puedo cancelar mi pedido después de pagarlo?',
      respuesta:
          'Puedes solicitar cancelación únicamente ANTES de que el producto comience a elaborarse. Si el proceso ya inició, no es posible cancelar.',
    ),
    PreguntaFrecuente(
      categoria: 'Pedidos',
      pregunta: '¿Con cuánto tiempo de anticipación debo pedir?',
      respuesta:
          'Recomendamos un mínimo de 24 horas de anticipación. Nuestros productos son artesanales y elaborados el mismo día para garantizar su frescura.',
    ),
    PreguntaFrecuente(
      categoria: 'Devoluciones',
      pregunta: '¿Cuál es su política de devoluciones?',
      respuesta:
          'Las devoluciones aplican únicamente el MISMO DÍA de la compra. Es requisito presentar al menos el 50% del producto en buenas condiciones.',
    ),
    PreguntaFrecuente(
      categoria: 'Devoluciones',
      pregunta: '¿Cuánto tardan en realizar un reembolso?',
      respuesta:
          'Si tu devolución es aprobada, el reembolso se gestiona en un máximo de 3 horas hábiles posteriores a la validación.',
    ),
    PreguntaFrecuente(
      categoria: 'Devoluciones',
      pregunta: '¿Qué cubre la garantía del producto?',
      respuesta:
          'Garantizamos frescura y calidad el día de la compra. No cubre daños por mal manejo, falta de refrigeración o transporte del cliente.',
    ),
    PreguntaFrecuente(
      categoria: 'Seguridad',
      pregunta: '¿Es seguro ingresar mis datos en la app?',
      respuesta:
          'Sí. Implementamos cifrado TLS/SSL. Pier NO almacena datos financieros sensibles. Todas las transacciones se procesan mediante pasarelas seguras.',
    ),
    PreguntaFrecuente(
      categoria: 'Pagos',
      pregunta: '¿Qué métodos de pago aceptan?',
      respuesta:
          'Aceptamos pagos en efectivo (solo en sucursal) y pagos electrónicos en la app mediante tarjeta de crédito o débito.',
    ),
    PreguntaFrecuente(
      categoria: 'Ubicación',
      pregunta: '¿Dónde están ubicados?',
      respuesta:
          '${BusinessInfo.direccionCompleta}. Abierto ${BusinessInfo.horario}.',
    ),
  ];

  List<PreguntaFrecuente> _preguntas = _porDefecto;
  String _categoriaSeleccionada = todas;

  String get categoriaSeleccionada => _categoriaSeleccionada;

  /// 'Todas' + las categorías presentes en las preguntas.
  List<String> get categorias {
    final presentes = _preguntas.map((p) => p.categoria).toSet();
    return [
      todas,
      ..._conocidas.where(presentes.contains),
      ...presentes.where((c) => !_conocidas.contains(c)),
    ];
  }

  /// Preguntas de la categoría seleccionada (todas con 'Todas').
  List<PreguntaFrecuente> get filtradas => _categoriaSeleccionada == todas
      ? _preguntas
      : _preguntas.where((p) => p.categoria == _categoriaSeleccionada).toList();

  void seleccionarCategoria(String categoria) {
    if (categoria == _categoriaSeleccionada) return;
    _categoriaSeleccionada = categoria;
    notifyListeners();
  }

  Future<void> cargar() async {
    try {
      final lista = await _repo.faq();
      if (_cerrado || lista.isEmpty) return;
      _preguntas = lista;
      if (!categorias.contains(_categoriaSeleccionada)) {
        _categoriaSeleccionada = todas;
      }
      notifyListeners();
    } on ApiException {
      // Se quedan las preguntas por defecto.
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
