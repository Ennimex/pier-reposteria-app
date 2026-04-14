// lib/presentation/screens/client/quejas/quejas_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/logger.dart';

// ── Tipos ─────────────────────────────────────────────────────────
enum TipoQueja { queja, sugerencia, comentario }
enum CategoriaQueja { producto, servicio, plataforma, otro }
enum EstadoQueja { pendiente, en_proceso, resuelto }

extension TipoQuejaExt on TipoQueja {
  String get label {
    switch (this) {
      case TipoQueja.queja: return 'Queja';
      case TipoQueja.sugerencia: return 'Sugerencia';
      case TipoQueja.comentario: return 'Comentario';
    }
  }
  String get value {
    switch (this) {
      case TipoQueja.queja: return 'queja';
      case TipoQueja.sugerencia: return 'sugerencia';
      case TipoQueja.comentario: return 'comentario';
    }
  }
}

extension CategoriaQuejaExt on CategoriaQueja {
  String get label {
    switch (this) {
      case CategoriaQueja.producto: return 'Producto';
      case CategoriaQueja.servicio: return 'Servicio';
      case CategoriaQueja.plataforma: return 'Plataforma';
      case CategoriaQueja.otro: return 'Otro';
    }
  }
  String get value {
    switch (this) {
      case CategoriaQueja.producto: return 'producto';
      case CategoriaQueja.servicio: return 'servicio';
      case CategoriaQueja.plataforma: return 'plataforma';
      case CategoriaQueja.otro: return 'otro';
    }
  }
}

extension EstadoQuejaExt on EstadoQueja {
  String get label {
    switch (this) {
      case EstadoQueja.pendiente: return 'Pendiente';
      case EstadoQueja.en_proceso: return 'En proceso';
      case EstadoQueja.resuelto: return 'Resuelto';
    }
  }
  Color get color {
    switch (this) {
      case EstadoQueja.pendiente: return Colors.orange.shade600;
      case EstadoQueja.en_proceso: return Colors.blue.shade600;
      case EstadoQueja.resuelto: return AppColors.pierVerde;
    }
  }
  Color get bgColor {
    switch (this) {
      case EstadoQueja.pendiente: return Colors.orange.shade50;
      case EstadoQueja.en_proceso: return Colors.blue.shade50;
      case EstadoQueja.resuelto: return const Color(0xFFE1F5EE);
    }
  }
  IconData get icon {
    switch (this) {
      case EstadoQueja.pendiente: return Icons.hourglass_empty_rounded;
      case EstadoQueja.en_proceso: return Icons.autorenew_rounded;
      case EstadoQueja.resuelto: return Icons.check_circle_rounded;
    }
  }
  static EstadoQueja fromString(String s) {
    switch (s) {
      case 'en_proceso': return EstadoQueja.en_proceso;
      case 'resuelto': return EstadoQueja.resuelto;
      default: return EstadoQueja.pendiente;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────
class QuejasScreen extends StatefulWidget {
  const QuejasScreen({super.key});

  @override
  State<QuejasScreen> createState() => _QuejasScreenState();
}

class _QuejasScreenState extends State<QuejasScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _quejas = [];
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;
  int? _expandida; // id de la queja expandida

  @override
  void initState() {
    super.initState();
    PierLog.nav('→ QuejasScreen');
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    await Future.wait([_cargarQuejas(), _cargarPedidos()]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarQuejas() async {
    PierLog.api('GET ${ApiConstants.misQuejas}');
    final result = await _api.getAuth(ApiConstants.misQuejas);
    if (!mounted) return;
    if (result['success'] == true) {
      final lista =
          List<Map<String, dynamic>>.from(result['quejas'] ?? []);
      setState(() => _quejas = lista);
      PierLog.info('✅ Quejas cargadas: ${lista.length}');
    } else {
      PierLog.error('Error al cargar quejas: ${result['message']}');
    }
  }

  Future<void> _cargarPedidos() async {
    PierLog.api('GET ${ApiConstants.misPedidos}');
    final result = await _api.getAuth(ApiConstants.misPedidos);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _pedidos =
          List<Map<String, dynamic>>.from(result['pedidos'] ?? []));
      PierLog.debug('Pedidos para dropdown: ${_pedidos.length}');
    }
  }

  void _abrirFormulario() {
    PierLog.nav('→ QuejasScreen BottomSheet formulario');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioQueja(
        pedidos: _pedidos,
        onEnviado: () {
          Navigator.pop(context);
          _cargarQuejas();
        },
      ),
    );
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return '';
    try {
      final dt = DateTime.parse(fechaStr).toLocal();
      const meses = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${dt.day} ${meses[dt.month - 1]}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pierArena,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.pierVerdeOscuro,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mis Quejas',
                                style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            Text('Quejas, sugerencias y comentarios',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      // Botón nueva queja
                      GestureDetector(
                        onTap: _abrirFormulario,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: AppColors.pierVerdeOscuro,
                                  size: 16),
                              SizedBox(width: 5),
                              Text('Nueva',
                                  style: TextStyle(
                                      color: AppColors.pierVerdeOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_cargando && _quejas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_quejas.length} registro${_quejas.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── CONTENIDO ─────────────────────────────────────────
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.pierVerde))
                  : _quejas.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _cargarDatos,
                          color: AppColors.pierVerde,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: _quejas.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildCard(_quejas[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> q) {
    final id = q['id'] as int? ?? 0;
    final ticket = q['ticket']?.toString() ?? '';
    final asunto = q['asunto']?.toString() ?? '';
    final descripcion = q['descripcion']?.toString() ?? '';
    final respuesta = q['respuesta']?.toString();
    final pedidoId = q['pedido_id'];
    final estado = EstadoQuejaExt.fromString(q['estado']?.toString() ?? '');
    final tipo = q['tipo']?.toString() ?? '';
    final categoria = q['categoria']?.toString() ?? '';
    final fecha = _formatearFecha(q['created_at']?.toString());
    final expandida = _expandida == id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── CABECERA ────────────────────────────────────────────
          GestureDetector(
            onTap: () =>
                setState(() => _expandida = expandida ? null : id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  // Icono
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.pierVerde.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.pierVerde, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ticket + badges
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            Text(ticket,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey[400])),
                            const SizedBox(width: 6),
                            _estadoBadge(estado),
                            const SizedBox(width: 6),
                            _miniChip(_tipoCapitalizado(tipo)),
                            const SizedBox(width: 6),
                            _miniChip(_categoriaCapitalizada(categoria)),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text(asunto,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(fecha,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  Icon(
                    expandida
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // ── DETALLE EXPANDIDO ────────────────────────────────────
          if (expandida) ...[
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  Text('Descripción',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: .3)),
                  const SizedBox(height: 6),
                  Text(descripcion,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5)),

                  // Pedido asociado
                  if (pedidoId != null) ...[
                    const SizedBox(height: 12),
                    Text('Pedido asociado',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: .3)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                              Icons.receipt_long_outlined,
                              size: 14,
                              color: AppColors.pierVerde),
                          const SizedBox(width: 6),
                          Text('Pedido #$pedidoId',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.pierVerde,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],

                  // Respuesta del equipo (solo si hay respuesta)
                  if (respuesta != null && respuesta.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.pierVerde.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.pierVerde
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 15, color: AppColors.pierVerde),
                            const SizedBox(width: 6),
                            const Text('Respuesta del equipo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.pierVerde)),
                          ]),
                          const SizedBox(height: 8),
                          Text(respuesta,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.pierVerdeOscuro,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estadoBadge(EstadoQueja estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(estado.icon, size: 11, color: estado.color),
        const SizedBox(width: 4),
        Text(estado.label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: estado.color)),
      ]),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    );
  }

  String _tipoCapitalizado(String t) {
    switch (t) {
      case 'queja': return 'Queja';
      case 'sugerencia': return 'Sugerencia';
      case 'comentario': return 'Comentario';
      default: return t;
    }
  }

  String _categoriaCapitalizada(String c) {
    switch (c) {
      case 'producto': return 'Producto';
      case 'servicio': return 'Servicio';
      case 'plataforma': return 'Plataforma';
      case 'otro': return 'Otro';
      default: return c;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.pierVerde.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 46,
                  color: AppColors.pierVerde.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            const Text('Sin quejas registradas',
                style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Si tienes alguna queja, sugerencia o\ncomentario, cuéntanoslo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _abrirFormulario,
              icon: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Crear primera queja',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pierVerde,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario (BottomSheet) ──────────────────────────────────────
class _FormularioQueja extends StatefulWidget {
  final List<Map<String, dynamic>> pedidos;
  final VoidCallback onEnviado;

  const _FormularioQueja({
    required this.pedidos,
    required this.onEnviado,
  });

  @override
  State<_FormularioQueja> createState() => _FormularioQuejaState();
}

class _FormularioQuejaState extends State<_FormularioQueja> {
  final ApiService _api = ApiService();
  final _asuntoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  TipoQueja _tipo = TipoQueja.queja;
  CategoriaQueja _categoria = CategoriaQueja.producto;
  String? _pedidoSeleccionado; // pedido_id como string
  bool _enviando = false;

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_asuntoCtrl.text.trim().isEmpty ||
        _descripcionCtrl.text.trim().isEmpty) {
      _showSnack('Completa todos los campos obligatorios');
      return;
    }

    setState(() => _enviando = true);
    PierLog.api('POST ${ApiConstants.crearQueja}');

    final body = <String, dynamic>{
      'tipo': _tipo.value,
      'categoria': _categoria.value,
      'asunto': _asuntoCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
    };
    if (_pedidoSeleccionado != null && _pedidoSeleccionado!.isNotEmpty) {
      body['pedido_id'] = int.tryParse(_pedidoSeleccionado!) ??
          _pedidoSeleccionado;
    }

    final result = await _api.postAuth(ApiConstants.crearQueja, body);

    if (!mounted) return;
    setState(() => _enviando = false);

    if (result['success'] == true) {
      final ticket =
          result['queja']?['ticket']?.toString() ?? '';
      PierLog.info('✅ Queja enviada — ticket: $ticket');
      widget.onEnviado();
      _showSnackSuccess('Queja enviada — ticket $ticket');
    } else {
      PierLog.error('Error al enviar queja: ${result['message']}');
      _showSnack(result['message']?.toString() ??
          'Error al enviar la queja');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSnackSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.pierVerde,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nueva queja o sugerencia',
                    style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tipo
            _label('Tipo'),
            _selector<TipoQueja>(
              value: _tipo,
              items: TipoQueja.values,
              labelOf: (t) => t.label,
              onChanged: (t) => setState(() => _tipo = t),
            ),
            const SizedBox(height: 14),

            // Categoría
            _label('Categoría'),
            _selector<CategoriaQueja>(
              value: _categoria,
              items: CategoriaQueja.values,
              labelOf: (c) => c.label,
              onChanged: (c) => setState(() => _categoria = c),
            ),
            const SizedBox(height: 14),

            // Pedido asociado (opcional)
            _label('Pedido asociado', opcional: true),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _pedidoSeleccionado,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: AppColors.pierVerde),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  hint: Text('Sin pedido asociado',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[400])),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin pedido asociado',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500])),
                    ),
                    ...widget.pedidos.map((p) {
                      final num = p['numero']?.toString() ?? '';
                      final total =
                          double.tryParse(p['total']?.toString() ?? '0')
                              ?.toStringAsFixed(0) ??
                              '0';
                      final estado = p['estado']?.toString() ?? '';
                      return DropdownMenuItem<String>(
                        value: p['id']?.toString(),
                        child: Text(
                          '#$num — \$$total ($estado)',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) =>
                      setState(() => _pedidoSeleccionado = v),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Asunto
            _label('Asunto'),
            TextField(
              controller: _asuntoCtrl,
              maxLength: 150,
              decoration: _inputDeco(
                  hint: 'Describe brevemente tu queja'),
            ),
            const SizedBox(height: 14),

            // Descripción
            _label('Descripción'),
            TextField(
              controller: _descripcionCtrl,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration:
                  _inputDeco(hint: 'Detalla tu queja o sugerencia...'),
            ),
            const SizedBox(height: 20),

            // Botón enviar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                label: Text(
                    _enviando ? 'Enviando...' : 'Enviar queja',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pierVerde,
                  disabledBackgroundColor:
                      AppColors.pierVerde.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool opcional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (opcional) ...[
            const SizedBox(width: 4),
            Text('(opcional)',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[400])),
          ],
        ],
      ),
    );
  }

  Widget _selector<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.pierVerde),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text(labelOf(i),
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      counterStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.grey.withValues(alpha: 0.25))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.pierVerde, width: 1.5)),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}