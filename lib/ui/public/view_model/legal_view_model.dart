// lib/ui/public/view_model/legal_view_model.dart
//
// Estado de «Marco Legal» (MVVM, Fase 3). Cada pestaña arranca con las
// secciones por defecto de la app; si Dirección capturó ese texto en el panel
// se reemplaza por las tarjetas que salen de él. Si el backend falla se quedan
// las de la app (la pantalla nunca muestra error).
import 'package:flutter/foundation.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/domain/models/textos_legales.dart';

class LegalViewModel extends ChangeNotifier {
  LegalViewModel({required ConfiguracionRepository repo}) : _repo = repo;

  final ConfiguracionRepository _repo;
  bool _cerrado = false;

  static const List<SeccionLegal> _privacidadPorDefecto = [
    SeccionLegal(
      titulo: 'Responsable del Tratamiento',
      contenido:
          '${BusinessInfo.marca}, con domicilio en ${BusinessInfo.direccionCompleta}.\nEmail: ${BusinessInfo.email}',
    ),
    SeccionLegal(
      titulo: 'Datos que Recopilamos',
      contenido:
          '• Identificación: Nombre, teléfono, correo electrónico.\n• Acceso digital: Usuario y contraseñas.\n• Transaccionales: Historial de pedidos.\n\nImportante: No almacenamos datos financieros sensibles (tarjetas, CVV).',
    ),
    SeccionLegal(
      titulo: 'Finalidades',
      contenido:
          '• Primarias: Gestión de pedidos y atención a clientes.\n• Secundarias: Envío de promociones (solo con consentimiento).',
    ),
    SeccionLegal(
      titulo: 'Derechos ARCO',
      contenido:
          'Puede ejercer sus derechos de Acceso, Rectificación, Cancelación u Oposición enviando un correo a ${BusinessInfo.email}.\nTiempo de respuesta: Máximo 20 días hábiles.',
    ),
    SeccionLegal(
      titulo: 'Conservación',
      contenido:
          'La información se conservará por un periodo máximo de 5 años tras su última interacción.',
    ),
  ];

  static const List<SeccionLegal> _terminosPorDefecto = [
    SeccionLegal(
      titulo: 'Proceso de Compra',
      contenido:
          'Todos los precios incluyen impuestos. La transacción se confirma una vez procesado el pago.',
    ),
    SeccionLegal(
      titulo: 'Entregas y Envíos',
      contenido:
          'Puedes recoger tu pedido en la sucursal de ${BusinessInfo.ciudad} o solicitar envío a domicilio en las colonias con cobertura. El costo de envío se calcula según la colonia y se muestra antes de pagar.',
    ),
    SeccionLegal(
      titulo: 'Cancelaciones',
      contenido:
          'El cliente puede cancelar únicamente ANTES de que inicie la elaboración. Nos reservamos el derecho de cancelar por falta de insumos, sin cargo al cliente.',
    ),
    SeccionLegal(
      titulo: 'Marco Legal',
      contenido:
          'Para la interpretación de estos términos, las partes se someten a las leyes vigentes en México y a los tribunales de Huejutla de Reyes, Hidalgo.',
    ),
  ];

  static const List<SeccionLegal> _devolucionesPorDefecto = [
    SeccionLegal(
      titulo: 'Condiciones de Devolución',
      contenido:
          '• Aplica únicamente el MISMO DÍA de la compra.\n• Debe presentarse al menos el 50% del producto.\n• No aplica en productos manipulados incorrectamente por el cliente.',
    ),
    SeccionLegal(
      titulo: 'Reembolsos',
      contenido:
          'Se gestionan en un máximo de 3 horas hábiles posteriores a la aprobación. Si el error es nuestro, absorbemos el costo total.',
    ),
    SeccionLegal(
      titulo: 'Garantía',
      contenido:
          'La garantía de frescura es válida únicamente el día de la entrega o recolección.',
    ),
  ];

  List<SeccionLegal> _privacidad = _privacidadPorDefecto;
  List<SeccionLegal> _terminos = _terminosPorDefecto;
  List<SeccionLegal> _devoluciones = _devolucionesPorDefecto;

  List<SeccionLegal> get privacidad => _privacidad;
  List<SeccionLegal> get terminos => _terminos;

  /// Pestaña «Devoluciones» (clave `reembolsos` del panel).
  List<SeccionLegal> get devoluciones => _devoluciones;

  Future<void> cargar() async {
    try {
      final textos = await _repo.legales();
      if (_cerrado) return;
      _privacidad = _desde(textos.privacidad) ?? _privacidad;
      _terminos = _desde(textos.terminos) ?? _terminos;
      _devoluciones = _desde(textos.reembolsos) ?? _devoluciones;
      notifyListeners();
    } on ApiException {
      // Se quedan las secciones por defecto.
    }
  }

  static List<SeccionLegal>? _desde(String? texto) {
    if (texto == null) return null;
    final secciones = SeccionLegal.desdeTexto(texto);
    return secciones.isEmpty ? null : secciones;
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
