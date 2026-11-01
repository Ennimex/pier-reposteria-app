// test/fakes/atencion_json.dart — respuestas del backend para «Atención a
// clientes» (#138): quejas, solicitudes de reembolso y reseñas de la
// sucursal en el orden en que las manda (de la más reciente a la más
// antigua) y con los textos escapados como los guarda su sanitizador.
import 'package:pier_reposteria/config/api_constants.dart';

import 'fake_api_client.dart';

Map<String, dynamic> quejaJson({
  required int id,
  String estado = 'pendiente',
  String tipo = 'queja',
  String prioridad = 'media',
  String asunto = 'Pastel aplastado',
  String? respuesta,
  String? pedido = 'PIER-12',
}) =>
    {
      'id': id,
      'ticket': 'TKT-00$id',
      'tipo': tipo,
      'categoria': 'producto',
      'asunto': asunto,
      'descripcion': 'Llegó con la cobertura corrida',
      'prioridad': prioridad,
      'estado': estado,
      'respuesta': respuesta,
      'created_at': '2026-10-30T18:00:00.000Z',
      'cliente_nombre': 'Ana',
      'cliente_apellido': 'Ruiz',
      'cliente_email': 'ana@correo.mx',
      'cliente_telefono': '7711234567',
      'pedido_numero': pedido,
    };

/// Una resuelta, una pendiente de prioridad alta (con el asunto escapado) y
/// una en proceso que ya tiene respuesta; más un renglón inválido.
Map<String, dynamic> get quejasJson => {
      'success': true,
      'quejas': [
        quejaJson(
          id: 3,
          estado: 'resuelto',
          tipo: 'comentario',
          asunto: 'Todo muy rico',
          respuesta: '¡Gracias por escribirnos!',
        ),
        quejaJson(
          id: 1,
          prioridad: 'alta',
          asunto: 'Pan &amp; café &quot;frío&quot;',
        ),
        quejaJson(
          id: 2,
          estado: 'en_proceso',
          tipo: 'sugerencia',
          prioridad: 'baja',
          asunto: 'Más sabores',
          respuesta: 'Lo vemos el 5&#x2F;11',
          pedido: null,
        ),
        'basura',
      ],
    };

Map<String, dynamic> reembolsoJson({
  required int id,
  String estado = 'pendiente',
  String monto = '150.00',
  String motivo = 'producto_danado',
  List<String>? fotos,
  String? respuesta,
  String? justificacion,
  bool automatico = false,
}) =>
    {
      'id': id,
      'pedido_id': 40 + id,
      'pedido_numero': 'PIER-${40 + id}',
      'monto': monto,
      'motivo': motivo,
      'descripcion': 'La caja llegó abierta &amp; el pan duro',
      'estado': estado,
      'fotos_evidencia': fotos,
      'justificacion_rechazo': justificacion,
      'respuesta_admin': respuesta,
      'fecha_resolucion': null,
      'created_at': '2026-10-30T18:00:00.000Z',
      'cliente_nombre': 'Luis',
      'cliente_apellido': 'Pérez',
      'cliente_telefono': '7719876543',
      'dias_desde_compra': 0,
      'mismo_dia_compra': true,
      'automatico': automatico,
    };

/// Una de cada estado (PIER-41 a PIER-46): la pendiente PIER-41 con dos
/// fotos, la PIER-42 en revisión, la PIER-43 aprobada, la PIER-44
/// rechazada, la PIER-45 devuelta y la PIER-46 automática por cancelación.
Map<String, dynamic> get reembolsosJson => {
      'success': true,
      'reembolsos': [
        reembolsoJson(
          id: 5,
          estado: 'procesado',
          respuesta: 'Devuelto a tu tarjeta',
        ),
        reembolsoJson(
          id: 1,
          fotos: [
            'https://res.cloudinary.com/pier/a.jpg',
            'https://res.cloudinary.com/pier/b.jpg',
          ],
        ),
        reembolsoJson(
          id: 2,
          estado: 'en_revision',
          respuesta: 'Recibimos tu solicitud; gerencia la revisará hoy.',
        ),
        reembolsoJson(
          id: 3,
          estado: 'aprobado',
          monto: '320.50',
          respuesta: 'Te lo devolvemos &amp; avisamos',
        ),
        reembolsoJson(
          id: 4,
          estado: 'rechazado',
          justificacion: 'La foto no muestra ningún daño en el pastel',
        ),
        reembolsoJson(id: 6, motivo: 'otro', automatico: true),
      ],
    };

Map<String, dynamic> resenaJson({
  required int id,
  String estado = 'pendiente',
  int rating = 2,
  String? titulo = 'Muy seco',
  String comentario = 'El pan estaba duro',
  String? respuesta,
  String? motivo,
  bool autoAprobada = false,
  bool verificada = true,
}) =>
    {
      'id': id,
      'producto_id': 7,
      'producto_nombre': 'Chocoflan',
      'rating': rating,
      'titulo': titulo,
      'comentario': comentario,
      'respuesta_negocio': respuesta,
      'motivo_rechazo': motivo,
      'auto_aprobada': autoAprobada,
      'verificada': verificada,
      'estado': estado,
      'created_at': '2026-10-30T18:00:00.000Z',
      'autor_nombre': 'Rosa',
      'autor_apellido': 'Díaz',
    };

/// Una aprobada sola sin respuesta (7), una rechazada (8), una pendiente de
/// 2 estrellas (9) y una aprobada con respuesta escapada (10).
Map<String, dynamic> get resenasJson => {
      'success': true,
      'resenas': [
        resenaJson(
          id: 7,
          estado: 'aprobada',
          rating: 5,
          titulo: 'Delicioso',
          comentario: 'El mejor flan',
          autoAprobada: true,
        ),
        resenaJson(
          id: 8,
          estado: 'rechazada',
          rating: 1,
          titulo: null,
          comentario: 'Horrible',
          motivo: 'Lenguaje inapropiado en el texto',
          verificada: false,
        ),
        resenaJson(id: 9),
        resenaJson(
          id: 10,
          estado: 'aprobada',
          rating: 4,
          titulo: 'Rico',
          comentario: 'Muy esponjoso',
          respuesta: 'Gracias &amp; vuelve pronto',
        ),
      ],
    };

/// Backend falso con las tres listas.
FakeApiClient backendAtencion() => FakeApiClient()
  ..responder(ApiConstants.quejasPersonal, quejasJson)
  ..responder(ApiConstants.reembolsosPersonal, reembolsosJson)
  ..responder(ApiConstants.resenasPersonal, resenasJson);

/// Cuántas veces se pidió la lista de [endpoint].
int cargasDe(FakeApiClient api, String endpoint) => api.llamadas
    .where((l) => l.endpoint == endpoint && l.metodo == 'GET-Auth')
    .length;
