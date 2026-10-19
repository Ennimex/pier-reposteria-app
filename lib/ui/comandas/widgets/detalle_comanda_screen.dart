// lib/ui/comandas/widgets/detalle_comanda_screen.dart
//
// Detalle de una comanda. Producción (#128): lo que hay que hacer (sin
// montos), las firmas de cada área y el botón «Enterado» del color de mi
// área, ligado a la versión que estoy viendo; si la comanda cambió mientras
// la leía, muestra exactamente qué cambió antes de volver a confirmar.
// Quien cobra (#129): además el cobro, «Entregar», «Cancelar comanda» (si
// puede) e «Imprimir», que abre la hoja de impresión de la web.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/domain/models/comanda.dart';
import 'package:pier_reposteria/ui/comandas/view_model/detalle_comanda_view_model.dart';
import 'package:pier_reposteria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_reposteria/ui/comandas/widgets/comandas_acciones.dart';
import 'package:pier_reposteria/ui/comandas/widgets/comandas_formato.dart';
import 'package:pier_reposteria/ui/comandas/widgets/detalle_comanda_partes.dart';
import 'package:pier_reposteria/ui/core/state/tema_provider.dart';
import 'package:pier_reposteria/ui/core/themes/app_colors.dart';
import 'package:pier_reposteria/utils/command.dart';
import 'package:pier_reposteria/utils/moneda.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _ambar = Color(0xFFB45309);

class DetalleComandaScreen extends StatefulWidget {
  /// [viewModel] solo se pasa en pruebas; en la app la pantalla crea el suyo.
  const DetalleComandaScreen({required this.id, super.key, this.viewModel});

  final int id;
  final DetalleComandaViewModel? viewModel;

  @override
  State<DetalleComandaScreen> createState() => _DetalleComandaScreenState();
}

class _DetalleComandaScreenState extends State<DetalleComandaScreen>
    with WidgetsBindingObserver {
  late final DetalleComandaViewModel _vm =
      widget.viewModel ??
      DetalleComandaViewModel(repo: context.read(), id: widget.id);
  bool _saliendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm.addListener(_revisarSesion);
    _vm.enterado.addListener(_alConfirmar);
    _vm.entregar.addListener(_alEntregar);
    _vm.cancelar.addListener(_alCancelar);
    unawaited(_vm.cargar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_vm.recargar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.enterado.removeListener(_alConfirmar);
    _vm.entregar.removeListener(_alEntregar);
    _vm.cancelar.removeListener(_alCancelar);
    _vm
      ..removeListener(_revisarSesion)
      ..dispose();
    super.dispose();
  }

  void _revisarSesion() {
    if (!_vm.sesionInvalida || _saliendo) return;
    _saliendo = true;
    unawaited(salirDeComandas(context, mensaje: _vm.error));
  }

  void _alConfirmar() =>
      _avisarResultado(_vm.enterado, (m) => (m, AppColors.pierVerde));

  /// Entregada; si producción no había confirmado, lo dice en ámbar.
  void _alEntregar() => _avisarResultado(
    _vm.entregar,
    (r) => (
      [r.mensaje, ...r.advertencias].join('\n'),
      r.advertencias.isEmpty ? AppColors.pierVerde : _ambar,
    ),
  );

  void _alCancelar() =>
      _avisarResultado(_vm.cancelar, (m) => (m, AppColors.pierVerde));

  /// Aviso al terminar [comando]: [exito] da el texto y el color; ámbar si
  /// la comanda cambió o ya la confirmaron, rojo si falló.
  void _avisarResultado<T>(
    Command<T> comando,
    (String, Color) Function(T resultado) exito,
  ) {
    if (comando.corriendo || _vm.sesionInvalida) return;
    final resultado = comando.resultado;
    final error = comando.error;
    if (resultado != null) {
      final (texto, color) = exito(resultado);
      avisoComandas(context, texto, color: color);
    } else if (error is ConflictoComandaException) {
      avisoComandas(context, error.message, color: _ambar);
    } else if (error is ApiException) {
      avisoComandas(context, error.message);
    } else {
      return;
    }
    comando.limpiar();
  }

  Future<void> _entregar(DetalleComanda d) async {
    final saldo = await pedirSaldoCobrado(context, d);
    if (saldo != null) unawaited(_vm.entregar.execute(saldo));
  }

  Future<void> _cancelar(DetalleComanda d) async {
    final motivo = await pedirMotivoCancelacion(context, d.folio);
    if (motivo != null) unawaited(_vm.cancelar.execute(motivo));
  }

  /// La hoja de impresión vive en la web (carta, blanco y negro).
  Future<void> _imprimir(DetalleComanda d) async {
    final url = '${BusinessInfo.sitioWeb}/comandas/${d.id}/imprimir';
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      avisoComandas(context, 'No se pudo abrir la hoja de impresión');
    }
  }

  Future<void> _tocarEnterado(DetalleComanda d) async {
    final si = await confirmarEnterado(
      context,
      folio: d.folio,
      version: d.version,
      cambios: _cambiosPorConfirmar(d) ?? const [],
    );
    if (si) unawaited(_vm.enterado.execute());
  }

  /// Si mi área ya había confirmado una versión anterior: los cambios desde
  /// entonces; si no, los vistos en vivo (o null si no hay caja de cambios).
  List<CambioCampo>? _cambiosPorConfirmar(DetalleComanda d) {
    final area = d.confirmar;
    if (area != null && d.firma(area).version != null) {
      return d.cambiosPendientes ?? const [];
    }
    return _vm.cambio?.cambios;
  }

  @override
  Widget build(BuildContext context) {
    // Observa el tema de temporada: repinta la pantalla si cambia la paleta
    context.watch<TemaProvider>();
    return ListenableBuilder(
      listenable: Listenable.merge([
        _vm,
        _vm.enterado,
        _vm.entregar,
        _vm.cancelar,
      ]),
      builder: (context, _) {
        final d = _vm.detalle;
        return Scaffold(
          backgroundColor: AppColors.pierArena,
          appBar: AppBar(
            backgroundColor: AppColors.pierVerde,
            foregroundColor: Colors.white,
            title: Text(d == null ? 'Comanda' : 'Comanda #${d.folio}'),
            actions: [
              if (d != null && d.puedeImprimir)
                IconButton(
                  tooltip: 'Imprimir',
                  icon: const Icon(LucideIcons.printer),
                  onPressed: () => unawaited(_imprimir(d)),
                ),
            ],
          ),
          body: _contenido(d),
          bottomNavigationBar: d == null ? null : _barra(d),
        );
      },
    );
  }

  /// Producción: «Enterado» si le toca. Quien cobra: entregar y cancelar.
  Widget? _barra(DetalleComanda d) {
    final area = d.confirmar;
    if (area != null) {
      return BarraEnterado(
        area: area,
        refirma: d.firma(area).version != null,
        corriendo: _vm.enterado.corriendo,
        alTocar: () => unawaited(_tocarEnterado(d)),
      );
    }
    if (!d.puedeEntregar && !d.puedeCancelar) return null;
    return BarraAcciones(
      corriendo: _vm.entregar.corriendo || _vm.cancelar.corriendo,
      alEntregar: d.puedeEntregar ? () => unawaited(_entregar(d)) : null,
      alCancelar: d.puedeCancelar ? () => unawaited(_cancelar(d)) : null,
    );
  }

  Widget _contenido(DetalleComanda? d) {
    if (_vm.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (d == null) {
      return SingleChildScrollView(
        child: EstadoAgenda(
          icono: LucideIcons.circleAlert,
          titulo: 'No pudimos abrir la comanda',
          detalle: _vm.error,
          accion: 'Reintentar',
          alAccion: () => unawaited(_vm.cargar()),
        ),
      );
    }
    final pasteles = d.pasteles;
    final productos = d.productos;
    return RefreshIndicator(
      onRefresh: _vm.recargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Cabecera(d),
          ..._cajaCambios(d),
          if (pasteles.isNotEmpty)
            SeccionDetalle(
              titulo: pasteles.length == 1
                  ? 'Pastel'
                  : 'Pasteles (${pasteles.length})',
              icono: LucideIcons.cakeSlice,
              children: [
                for (final (i, p) in pasteles.indexed) TarjetaPastel(p, i + 1),
              ],
            ),
          if (productos.isNotEmpty)
            SeccionDetalle(
              titulo: pasteles.isEmpty ? 'Productos' : 'Otros productos',
              icono: LucideIcons.package,
              children: [for (final p in productos) RenglonProducto(p)],
            ),
          if (d.coloresMesa.isNotEmpty)
            SeccionDetalle(
              titulo: 'Mesa de postres',
              icono: LucideIcons.palette,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    for (final MapEntry(key: etiqueta, value: color)
                        in d.coloresMesa.entries)
                      SizedBox(width: 130, child: DatoComanda(etiqueta, color)),
                  ],
                ),
              ],
            ),
          if (d.notas case final notas?)
            SeccionDetalle(
              titulo: 'Notas',
              icono: LucideIcons.stickyNote,
              children: [Text(notas)],
            ),
          if (d.imagenes.isNotEmpty)
            SeccionDetalle(
              titulo: 'Imágenes de referencia (${d.imagenes.length})',
              icono: LucideIcons.images,
              children: [GaleriaComanda(d.imagenes)],
            ),
          SeccionDetalle(
            titulo: 'Cliente',
            icono: LucideIcons.userRound,
            children: [
              Text(
                d.clienteNombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // El teléfono solo le sirve a quien cobra y atiende al cliente
              if (d.total != null && d.clienteTelefono.isNotEmpty)
                Text(d.clienteTelefono),
              const SizedBox(height: 4),
              Text(
                'Tomó la comanda: ${d.tomadoPorNombre}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (d.total != null) _Cobro(d),
          SeccionDetalle(
            titulo: 'Confirmación de producción',
            icono: LucideIcons.clipboardCheck,
            children: [
              for (final area in AreaProduccion.values)
                FirmaProduccion(area: area, firma: d.firma(area)),
            ],
          ),
        ],
      ),
    );
  }

  /// Volver a firmar: qué cambió desde mi última confirmación. Si no, lo
  /// que cambió mientras la veía.
  List<Widget> _cajaCambios(DetalleComanda d) {
    final area = d.confirmar;
    final versionFirmada = area == null ? null : d.firma(area).version;
    if (versionFirmada != null) {
      return [
        CajaCambios(
          titulo: 'Qué cambió desde tu última confirmación',
          texto:
              'Tu área confirmó la versión $versionFirmada; ahora va en la '
              'versión ${d.version}. Revisa los cambios antes de volver a '
              'confirmar.',
          cambios: d.cambiosPendientes ?? const [],
        ),
      ];
    }
    final cambio = _vm.cambio;
    if (cambio == null) return const [];
    return [
      CajaCambios(
        titulo: 'Esta comanda cambió mientras la veías',
        texto:
            'Pasó de la versión ${cambio.desde} a la ${cambio.hasta}. '
            'Estos son los cambios:',
        cambios: cambio.cambios,
        alCerrar: _vm.descartarCambio,
      ),
    ];
  }
}

/// Urgencia, día y hora de entrega, o el aviso de entregada / cancelada.
class _Cabecera extends StatelessWidget {
  const _Cabecera(this.detalle);

  final DetalleComanda detalle;

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    final semaforo = d.semaforo;
    final dia = etiquetaDia(d.fechaEntrega, d.diasRestantes);
    final hora = horaLegible(d.horaEntrega);
    final cerrada = switch (d.estado) {
      EstadoComanda.cancelada =>
        d.motivoCancelacion == null
            ? 'Comanda cancelada'
            : 'Comanda cancelada: ${d.motivoCancelacion}',
      EstadoComanda.entregada => 'Comanda entregada',
      EstadoComanda.activa => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (semaforo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: semaforo.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                semaforo.etiqueta,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: semaforo.color,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '$dia · $hora',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (cerrada == null)
            Text(
              '${textoDiasRestantes(d.diasRestantes)} · versión ${d.version}',
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                cerrada,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Montos (solo llegan a quien cobra). Entregada: lo que se cobró.
class _Cobro extends StatelessWidget {
  const _Cobro(this.detalle);

  final DetalleComanda detalle;

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    final montos = <(String, double?)>[
      ('Subtotal', d.subtotal),
      ('Descuento', d.descuento),
      ('Total', d.total),
      ('Anticipo', d.anticipo),
      if (d.estado == EstadoComanda.entregada)
        ('Saldo cobrado', d.saldoCobrado)
      else
        ('Saldo', d.saldo),
    ];
    return SeccionDetalle(
      titulo: 'Cobro',
      icono: LucideIcons.wallet,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final (etiqueta, monto) in montos)
              SizedBox(
                width: 130,
                child: DatoComanda(
                  etiqueta,
                  monto == null ? null : moneda(monto),
                ),
              ),
          ],
        ),
        if (d.entregadaPorNombre case final quien?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Entregó: $quien',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}
