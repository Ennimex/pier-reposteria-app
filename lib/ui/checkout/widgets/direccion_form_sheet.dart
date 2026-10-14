// lib/ui/checkout/widgets/direccion_form_sheet.dart
//
// Hoja para agregar o editar una dirección de entrega. La colonia se elige
// de la lista con cobertura (GET /zonas-envio/colonias) para garantizar
// tarifa. Con [editar] precarga los campos y actualiza. Devuelve la
// DireccionCliente guardada por Navigator.pop.
//
// Movimiento: la hoja sube con la curva enfática de Pier y sus campos llegan
// en cascada; el indicador de la colonia se funde con la lista sin saltos,
// la fila del envío abre su espacio al elegir colonia y, si no se pudo
// guardar, los campos se sacuden junto con el aviso.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/direccion_model.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/direccion_form_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/tamano_animado.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';

/// Abre la hoja y devuelve la dirección guardada (null si se cerró).
Future<DireccionCliente?> mostrarFormularioDireccion(
  BuildContext context, {
  DireccionCliente? editar,
}) {
  return showModalBottomSheet<DireccionCliente>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    sheetAnimationStyle: AppMovimiento.estiloHoja(context),
    builder: (_) => DireccionFormSheet(editar: editar),
  );
}

class DireccionFormSheet extends StatefulWidget {
  const DireccionFormSheet({this.editar, this.viewModel, super.key});

  final DireccionCliente? editar;

  /// Para pruebas; si es null la hoja crea el suyo.
  final DireccionFormViewModel? viewModel;

  @override
  State<DireccionFormSheet> createState() => _DireccionFormSheetState();
}

class _DireccionFormSheetState extends State<DireccionFormSheet> {
  late final DireccionFormViewModel _vm = widget.viewModel ??
      DireccionFormViewModel(repo: context.read(), editar: widget.editar);
  final _aliasCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  // Cada intento de guardar que falla sacude los campos una vez.
  int _errores = 0;

  // La fila del envío conserva su monto mientras se cierra.
  double _ultimaTarifa = 0;

  @override
  void initState() {
    super.initState();
    final e = _vm.editar;
    if (e != null) {
      _aliasCtrl.text = e.alias;
      _calleCtrl.text = e.calleNumero;
      _refCtrl.text = e.referencias ?? '';
      _telCtrl.text = e.telefonoContacto ?? '';
    }
    unawaited(_vm.cargarColonias());
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    _calleCtrl.dispose();
    _refCtrl.dispose();
    _telCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final (guardada, error) = await _vm.guardar(
      alias: _aliasCtrl.text,
      calle: _calleCtrl.text,
      referencias: _refCtrl.text,
      telefono: _telCtrl.text,
    );
    if (!mounted) return;
    if (guardada != null) {
      Navigator.pop(context, guardada);
      return;
    }
    setState(() => _errores++);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'No se pudo guardar la dirección'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Un renglón de la cascada: llega cuando la hoja ya casi terminó de
  /// subir, cada uno un paso después del anterior.
  Widget _paso(int orden, Widget hijo) => EntradaSuave(
        orden: orden,
        retraso: AppMovimiento.trasEmpuje,
        desplazamiento: const Offset(0, AppMovimiento.distanciaCorta),
        child: hijo,
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final vm = _vm;
        final tarifa = vm.tarifa;
        if (tarifa != null) _ultimaTarifa = tarifa;
        final envio = 'Envío: \$${_ultimaTarifa.toStringAsFixed(0)} MXN';
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _paso(
                  0,
                  Text(vm.esEdicion ? 'Editar dirección' : 'Nueva dirección',
                      style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(height: 18),
                // Los datos obligatorios: se sacuden si no se pudo guardar.
                Sacudida(
                  disparo: _errores,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _paso(1, _Campo(_aliasCtrl, 'Alias (Casa, Trabajo…)', LucideIcons.bookmark)),
                      const SizedBox(height: 12),
                      _paso(2, _Campo(_calleCtrl, 'Calle y número, interior', LucideIcons.house)),
                      const SizedBox(height: 12),
                      // Colonia (solo las que tienen cobertura): el indicador
                      // se funde con la lista (o con el aviso) sin saltar.
                      _paso(
                        3,
                        TamanoAnimado(
                          child: CambioAnimado(
                            tipo: TipoCambio.atravesar,
                            alineacion: AlignmentDirectional.topStart,
                            child: _colonia(vm),
                          ),
                        ),
                      ),
                      // El envío abre su espacio al elegir colonia.
                      Aparicion(
                        visible: tarifa != null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            Icon(LucideIcons.truck,
                                size: 16, color: AppColors.pierVerde),
                            const SizedBox(width: 6),
                            CambioAnimado(
                              tipo: TipoCambio.subir,
                              child: Text(envio,
                                  key: ValueKey(envio),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.pierVerde,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _paso(4, _Campo(_refCtrl, 'Referencias (opcional)', LucideIcons.info)),
                const SizedBox(height: 12),
                _paso(
                  5,
                  _Campo(_telCtrl, 'Teléfono de contacto (opcional)', LucideIcons.phone,
                      teclado: TextInputType.phone),
                ),
                const SizedBox(height: 22),
                _paso(
                  6,
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: vm.guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pierVerde),
                      // Texto ↔ indicador dentro del mismo botón.
                      child: CambioAnimado(
                        tipo: TipoCambio.escalar,
                        alineacion: Alignment.center,
                        child: vm.guardando
                            ? const SizedBox(
                                key: ValueKey('guardando'),
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(vm.esEdicion ? 'Guardar cambios' : 'Guardar dirección',
                                key: const ValueKey('guardar'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// La colonia según el estado: cargando, sin cobertura o la lista.
  Widget _colonia(DireccionFormViewModel vm) {
    if (vm.cargandoColonias) {
      return KeyedSubtree(
        key: const ValueKey('cargando'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.pierVerde, strokeWidth: 2)),
        ),
      );
    }
    if (vm.colonias.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('sin-cobertura'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
              'Aún no hay colonias con cobertura de envío. Recoge en sucursal.',
              style: TextStyle(fontSize: 13, color: AppColors.error)),
        ),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('colonias'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Row(children: [
              Icon(LucideIcons.building2,
                  size: 20, color: AppColors.pierVerde),
              const SizedBox(width: 10),
              const Text('Colonia'),
            ]),
            value: vm.colonia,
            icon: Icon(LucideIcons.chevronDown, color: AppColors.pierVerde),
            items: vm.colonias
                .map((c) => DropdownMenuItem(
                      value: c.colonia,
                      child: Text('${c.colonia}  ·  \$${c.tarifaTexto} envío',
                          style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: vm.elegirColonia,
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo(this.controlador, this.pista, this.icono,
      {this.teclado = TextInputType.text});

  final TextEditingController controlador;
  final String pista;
  final IconData icono;
  final TextInputType teclado;

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.2)),
    );
    return TextField(
      controller: controlador,
      keyboardType: teclado,
      textCapitalization: teclado == TextInputType.phone
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: pista,
        prefixIcon: Icon(icono, color: AppColors.pierVerde, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: borde,
        enabledBorder: borde,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.pierVerde, width: 1.5),
        ),
      ),
    );
  }
}
